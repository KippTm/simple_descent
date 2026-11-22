package structs

import "core:math"

// -----------------------------------------------------------------------------
// Spatial Hash Grid (Zero-Allocation Intrusive Linked List)
// -----------------------------------------------------------------------------
// Instead of allocating dynamic arrays per cell, each bucket stores the index
// of the first enemy in that bucket (`cell_head`), and `next_in_cell[enemy_idx]`
// stores the next enemy index in the same bucket (-1 for end of list).
Spatial_Grid :: struct {
	cell_head:    [GRID_BUCKETS]i32,
	next_in_cell: [MAX_ENEMIES]i32,
}

hash_cell :: #force_inline proc(cx, cy: i32) -> u32 {
	// Large primes for spatial hashing of 2D integer cell coordinates
	h := u32(cx) * 73856093 ~ u32(cy) * 19349663
	return h & (GRID_BUCKETS - 1)
}

world_to_cell :: #force_inline proc(pos: [2]f32) -> (i32, i32) {
	return i32(math.floor(pos.x / GRID_CELL_SIZE)), i32(math.floor(pos.y / GRID_CELL_SIZE))
}

// Root Game State allocated on the heap so stack size stays tiny.
Game_State :: struct {
	current_state:          State_Kind,
	menu_selection:         int,
	pause_selection:        int,
	selected_loadout:       [STARTING_ABILITY_COUNT]Ability_Id,
	selected_loadout_count: int,
	loadout_cursor:         int,
	upgrade_select_slot:    int,
	upgrade_select_cursor:  int,
	should_quit:            bool,

	player:                 Player,

	// Structure of Arrays (#soa) for cache-friendly iteration over hot loops
	enemies:                #soa[MAX_ENEMIES]Enemy,
	enemy_count:            int,

	projectiles:            #soa[MAX_PROJECTILES]Projectile,
	projectile_count:       int,

	grid:                   Spatial_Grid,

	// Loop & Teleporter progression
	run_timer:              f32,
	stage:                  int,
	wave:                   int,
	kill_count:             int,
	kill_quota:             int,
	spawn_timer:            f32,
}
