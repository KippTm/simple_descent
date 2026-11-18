package structs

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

// Root Game State allocated on the heap so stack size stays tiny.
Game_State :: struct {
	player:           Player,

	// Structure of Arrays (#soa) for cache-friendly iteration over hot loops
	enemies:          #soa[MAX_ENEMIES]Enemy,
	enemy_count:      int,

	projectiles:      #soa[MAX_PROJECTILES]Projectile,
	projectile_count: int,

	grid:             Spatial_Grid,

	// Loop & Teleporter progression
	run_timer:        f32,
	stage:            int,
	kill_count:       int,
	kill_quota:       int,
	spawn_timer:      f32,
}
