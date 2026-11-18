package entities

import "core:math"
import "../structs"

// -----------------------------------------------------------------------------
// Spatial Hash Implementation
// -----------------------------------------------------------------------------

hash_cell :: #force_inline proc(cx, cy: i32) -> u32 {
	// Large primes for spatial hashing of 2D integer cell coordinates
	h := u32(cx) * 73856093 ~ u32(cy) * 19349663
	return h & (structs.GRID_BUCKETS - 1)
}

world_to_cell :: #force_inline proc(pos: [2]f32) -> (i32, i32) {
	return i32(math.floor(pos.x / structs.GRID_CELL_SIZE)), i32(math.floor(pos.y / structs.GRID_CELL_SIZE))
}

grid_rebuild :: proc(state: ^structs.Game_State) {
	// Reset all bucket heads to -1 (empty)
	for i in 0 ..< structs.GRID_BUCKETS {
		state.grid.cell_head[i] = -1
	}

	// Insert all active enemies in O(N)
	for i in 0 ..< state.enemy_count {
		cx, cy := world_to_cell(state.enemies[i].pos)
		bucket := hash_cell(cx, cy)
		state.grid.next_in_cell[i] = state.grid.cell_head[bucket]
		state.grid.cell_head[bucket] = i32(i)
	}
}
