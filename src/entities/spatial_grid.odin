package entities

import "../structs"

// -----------------------------------------------------------------------------
// Spatial Hash Grid Rebuild
// -----------------------------------------------------------------------------

grid_rebuild :: proc(state: ^structs.Game_State) {
	// Reset all bucket heads to -1 (empty)
	for i in 0 ..< structs.GRID_BUCKETS {
		state.grid.cell_head[i] = -1
	}

	// Insert all active enemies in O(N)
	for i in 0 ..< state.enemy_count {
		cx, cy := structs.world_to_cell(state.enemies[i].pos)
		bucket := structs.hash_cell(cx, cy)
		state.grid.next_in_cell[i] = state.grid.cell_head[bucket]
		state.grid.cell_head[bucket] = i32(i)
	}
}
