package main

import "core:fmt"
import "core:io"
import "core:os"
import "core:thread"
import "core:time"

Build :: struct {
	name:         string,
	pipe_read:    ^os.File,
	process:      os.Process,
	output:       [dynamic]byte,
	drain_thread: ^thread.Thread,
	drain_err:    os.Error,
	wait_err:     os.Error,
	exit_code:    int,
}

drain_pipe :: proc(build: ^Build) {
	defer os.close(build.pipe_read)

	pipe_buf: [1024]byte
	for {
		n, err := os.read(build.pipe_read, pipe_buf[:])
		if n > 0 {
			_, append_err := append(&build.output, ..pipe_buf[:n])
			if append_err != nil {
				build.drain_err = append_err
				return
			}
		}
		if err == nil {
			continue
		}

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
		return
	}
}

start_build :: proc(build: ^Build, dir: os.File_Info, out_dir: string) -> bool {
	build.name = dir.name

	output, output_err := make([dynamic]byte, 0, 4096, context.allocator)
	if output_err != nil {
		fmt.eprintfln("Failed to allocate output buffer for %v: %v", dir.name, output_err)
		return false
	}
	build.output = output

	pipe_read, pipe_write, pipe_err := os.pipe()
	if pipe_err != nil {
		fmt.eprintfln("Failed to create output pipe for %v: %v", dir.name, pipe_err)
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

	process, process_err := os.process_start(desc)
	os.close(pipe_write)
	if process_err != nil {
		os.close(pipe_read)
		fmt.eprintfln("Failed to start build %v: %v", dir.name, process_err)
		return false
	}

	build.pipe_read = pipe_read
	build.process = process
	build.drain_thread = thread.create_and_start_with_poly_data(build, drain_pipe)
	if build.drain_thread == nil {
		drain_pipe(build)
	}
	return true
}

run :: proc() -> bool {
	if len(os.args) < 3 {
		fmt.eprintln("Not enough arguments")
		return false
	}

	in_dir, out_dir := os.args[1], os.args[2]
	dirs, dirs_err := os.read_all_directory_by_path(in_dir, context.temp_allocator)
	if dirs_err != nil {
		fmt.eprintfln("Failed to read directory %v: %v", in_dir, dirs_err)
		return false
	}

	job_count := max(os.get_processor_core_count(), 1)
	target_count := len(dirs)
	batch_count := (target_count + job_count - 1) / job_count
	fmt.printfln(
		"Building %v targets with up to %v parallel jobs in %v batches.",
		target_count,
		min(job_count, target_count),
		batch_count,
	)

	builds := make([]Build, target_count, context.temp_allocator)
	defer {
		for i in 0 ..< len(builds) {
			delete(builds[i].output)
		}
	}

	start_time := time.now()
	batch_index := 0
	for batch_start := 0; batch_start < target_count; batch_start += job_count {
		batch_end := min(batch_start + job_count, target_count)
		batch_index += 1
		fmt.printfln(
			"[%v/%v] Starting %v builds...",
			batch_index,
			batch_count,
			batch_end - batch_start,
		)

		launched_end := batch_start
		for i in batch_start ..< batch_end {
			if !start_build(&builds[i], dirs[i], out_dir) {
				break
			}
			launched_end = i + 1
		}

		for i in batch_start ..< launched_end {
			build := &builds[i]
			state, wait_err := os.process_wait(build.process)
			build.wait_err = wait_err
			if build.drain_thread != nil {
				thread.destroy(build.drain_thread)
			}
			if build.wait_err == nil {
				build.exit_code = state.exit_code
			}
		}
		if launched_end != batch_end {
			return false
		}
	}
	build_time := time.since(start_time)

	failed_count: int
	fmt.println()
	for i in 0 ..< target_count {
		build := &builds[i]
		build_failed := build.wait_err != nil || build.exit_code != 0 || build.drain_err != nil
		has_output := len(build.output) > 0

		if build_failed {
			failed_count += 1
		} else if !has_output {
			continue
		}

		status := "FAILED" if build_failed else "OUTPUT"
		fmt.printfln("--- %v: %v ---", status, build.name)
		if build.wait_err != nil {
			fmt.println("Failed to wait for process: ", build.wait_err)
		}
		if build.drain_err != nil {
			fmt.println("Failed to drain output: ", build.drain_err)
		}
		if build.exit_code != 0 && !has_output {
			fmt.printfln("Process exited with code %v.", build.exit_code)
		}

		if has_output {
			os.write(os.stdout, build.output[:])
			if build.output[len(build.output) - 1] != '\n' {
				fmt.println()
			}
		}
		fmt.println()
	}

	fmt.printfln(
		"Build complete in %.2fs: %v succeeded, %v failed.",
		time.duration_seconds(build_time),
		target_count - failed_count,
		failed_count,
	)
	return failed_count == 0
}

main :: proc() {
	if !run() {
		os.exit(1)
	}
}
