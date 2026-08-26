package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"

Build :: struct {
	desc:      os.Process_Desc,
	pipe_read: ^os.File,
	process:   os.Process,
}

make_command_str :: proc(command: []string) -> string {
	sb := strings.builder_make()
	for str in command {
		strings.write_string(&sb, str)
		strings.write_string(&sb, " ")
	}
	return strings.to_string(sb)
}

main :: proc() {

	args := os.args

	if len(args) < 3 {
		fmt.eprintln("Not enough arguments")
		os.exit(1)
	}

	in_dir := args[1]
	out_dir := args[2]

	dirs_file, open_err := os.open(in_dir)
	if open_err != nil {
		fmt.eprintfln("Failed to open directory %v:", open_err)
		return
	}

	dirs, dirs_err := os.read_all_directory(dirs_file, context.temp_allocator)
	if dirs_err != nil {
		fmt.eprintln("Failed to read directory: ", dirs_err)
		return
	}

	core_count := os.get_processor_core_count()
	num_dirs := len(dirs)

	fmt.printfln("Core count is %v, which will be the builds batch size.", core_count)
	fmt.printfln("Number of directories is %v", num_dirs)


	builds := make([]Build, num_dirs, context.temp_allocator)

	start_batch: int
	end_batch: int

	for start_batch < num_dirs {

		end_batch = clamp(end_batch, core_count, num_dirs)
		batch_size := end_batch - start_batch

		fmt.printfln(
			"Running batch from %v, to %v: batch size %v",
			start_batch,
			end_batch,
			batch_size,
		)
		for i in start_batch ..< end_batch {
			dir := dirs[i]

			pipe_read, pipe_write, pipe_err := os.pipe()
			if pipe_err != nil {
				fmt.eprintln("Failed to open pipe for dir: ", dir.fullpath)
				return
			}

			desc := os.Process_Desc {
				command = {
					"odin",
					"build",
					dir.fullpath,
					"-vet",
					"-strict-style",
					"-vet-tabs",
					"-warnings-as-errors",
					"-debug",
					fmt.tprintf("-out:%v/%v.exe", out_dir, dir.name),
				},
				stdout  = pipe_write,
				stderr  = pipe_write,
			}

			command_str := make_command_str(desc.command)
			fmt.println("Starting process: ", command_str)
			p, p_err := os.process_start(desc)
			if p_err != nil {
				fmt.println("Failed to start process: ", command_str)
			}

			// The writing side of the pipe needs to be closed by the parent
			// before the parent tries to read any data from it.
			os.close(pipe_write)

			builds[i] = Build{desc, pipe_read, p}
		}

		batch_builds := builds[start_batch:end_batch]

		// TODO(Thomas): Drain the pipe here concurrently to avoid potential slowdown
		// of one of the processes fills it up?
		// Can't write directly to stdout then probably?
		for build in batch_builds {
			pipe_buf: [1024]byte
			for {
				n, err := os.read(build.pipe_read, pipe_buf[:])
				if n > 0 {
					os.write(os.stdout, pipe_buf[:n])
				}
				if err != nil {
					done := false
					#partial switch e in err {
					case io.Error:
						done = e == .EOF
					case os.General_Error:
						done = e == .Broken_Pipe
					}

					if !done {
						fmt.eprintln("Error when reading stdout: ", err)
					}
					break
				}
			}

			os.close(build.pipe_read)
		}

		for build in batch_builds {
			// TODO(Thomas): Report failures etc
			_, p_err := os.process_wait(build.process)
			assert(p_err == nil)
		}

		start_batch += core_count
		end_batch += core_count
	}
}
