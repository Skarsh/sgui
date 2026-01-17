package diagnostics

import "core:fmt"
import "core:log"
import "core:mem"

Diagnostics_Context :: struct {
	tracking_allocator: mem.Tracking_Allocator,
	logger:             log.Logger,
	base_allocator:     mem.Allocator,
}

// Initialize diagnostics (tracking allocator + logger)
init :: proc(log_level := log.Level.Info) -> Diagnostics_Context {
	diag := Diagnostics_Context{}

	// Store the base allocator
	diag.base_allocator = context.allocator

	// Setup tracking allocator
	mem.tracking_allocator_init(&diag.tracking_allocator, diag.base_allocator)
	context.allocator = mem.tracking_allocator(&diag.tracking_allocator)

	// Setup logger
	diag.logger = log.create_console_logger(log_level)
	context.logger = diag.logger

	return diag
}

// Cleanup and report diagnostics
deinit :: proc(diag: ^Diagnostics_Context) {
	// Cleanup logger first (before checking for leaks)
	// Use the tracking allocator to ensure the free is tracked
	log.destroy_console_logger(diag.logger, mem.tracking_allocator(&diag.tracking_allocator))

	// Report tracking allocator results
	if len(diag.tracking_allocator.allocation_map) > 0 {
		fmt.eprintf(
			"=== %v allocations not freed: ===\n",
			len(diag.tracking_allocator.allocation_map),
		)
		for _, entry in diag.tracking_allocator.allocation_map {
			fmt.eprintf("- %v bytes @ %v\n", entry.size, entry.location)
		}
	}
	if len(diag.tracking_allocator.bad_free_array) > 0 {
		fmt.eprintf("=== %v incorrect frees: ===\n", len(diag.tracking_allocator.bad_free_array))
		for entry in diag.tracking_allocator.bad_free_array {
			fmt.eprintf("- %p @ %v\n", entry.memory, entry.location)
		}
	}

	// Destroy tracking allocator
	mem.tracking_allocator_destroy(&diag.tracking_allocator)
}
