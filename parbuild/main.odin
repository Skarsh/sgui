package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:strings"
import "core:thread"

Build :: struct {
	desc:         os.Process_Desc,
	pipe_read:    ^os.File,
	process:      os.Process,
	output:       [dynamic]byte,
	drain_thread: ^thread.Thread,
	drain_err:    os.Error,
}

make_command_str :: proc(command: []string) -> string {
	sb := strings.builder_make()
	for str in command {
		strings.write_string(&sb, str)
		strings.write_string(&sb, " ")
	}
	return strings.to_string(sb)
}

drain_pipe :: proc(build: ^Build) {
	pipe_buf: [1024]byte
	for {
		n, err := os.read(build.pipe_read, pipe_buf[:])
		if n > 0 {
			_, append_err := append(&build.output, ..pipe_buf[:n])
			if append_err != nil {
				build.drain_err = append_err
				break
			}
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
				build.drain_err = err
			}
			break
		}
	}

	os.close(build.pipe_read)
}

run :: proc() -> bool {
	args := os.args

	if len(args) < 3 {
		fmt.eprintln("Not enough arguments")
		return false
	}

	in_dir := args[1]
	out_dir := args[2]

	dirs_file, open_err := os.open(in_dir)
	defer os.close(dirs_file)
	if open_err != nil {
		fmt.eprintfln("Failed to open directory %v:", open_err)
		return false
	}

	dirs, dirs_err := os.read_all_directory(dirs_file, context.temp_allocator)
	if dirs_err != nil {
		fmt.eprintln("Failed to read directory: ", dirs_err)
		return false
	}

	core_count := os.get_processor_core_count()
	num_dirs := len(dirs)

	fmt.printfln("Core count is %v, which will be the builds batch size.", core_count)
	fmt.printfln("Number of directories is %v", num_dirs)

	builds := make([]Build, num_dirs)

	ok := true

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
				return false
			}

			output, output_err := make([dynamic]byte, 0, 4096, context.allocator)
			if output_err != nil {
				os.close(pipe_read)
				os.close(pipe_write)
				fmt.eprintln("Failed to allocate output buffer")
				return false
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

				os.close(pipe_read)
				os.close(pipe_write)
				delete(output)
				return false
			}

			// The writing side of the pipe needs to be closed by the parent
			// before the parent tries to read any data from it.
			os.close(pipe_write)

			builds[i] = Build {
				desc      = desc,
				pipe_read = pipe_read,
				process   = p,
				output    = output,
			}

			build := &builds[i]
			build.drain_thread = thread.create_and_start_with_poly_data(build, drain_pipe)

			// Fallback if the thread creation and start failed, so do it sequentially
			if build.drain_thread == nil {
				drain_pipe(build)
			}
		}

		for i in start_batch ..< end_batch {
			build := &builds[i]

			state, wait_err := os.process_wait(build.process)
			if wait_err != nil {
				fmt.eprintln("Failed to wait for process: ", wait_err)
				ok = false
			} else if state.exit_code != 0 {
				ok = false
			}

			if build.drain_thread != nil {
				thread.destroy(build.drain_thread)
			}

			if build.drain_err != nil {
				fmt.eprintln("Failed to drain output: ", build.drain_err)
				ok = false
			}

			os.write(os.stdout, build.output[:])
			delete(build.output)
		}

		start_batch += core_count
		end_batch += core_count
	}
	return ok
}

main :: proc() {
	if !run() {
		os.exit(1)
	}
}
