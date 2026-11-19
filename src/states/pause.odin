package states

import rl "vendor:raylib"
import "../structs"

// -----------------------------------------------------------------------------
// Pause Menu State
// -----------------------------------------------------------------------------

PAUSE_OPTION_COUNT :: 3

update_pause :: proc(state: ^structs.Game_State) {
	if rl.IsKeyPressed(.ESCAPE) || rl.IsKeyPressed(.P) {
		change_state(state, .Playing)
		return
	}

	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		state.pause_selection = (state.pause_selection - 1 + PAUSE_OPTION_COUNT) % PAUSE_OPTION_COUNT
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		state.pause_selection = (state.pause_selection + 1) % PAUSE_OPTION_COUNT
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		switch state.pause_selection {
		case 0: // Resume
			change_state(state, .Playing)
		case 1: // Restart Run
			reset_run(state)
			change_state(state, .Playing)
		case 2: // Main Menu
			change_state(state, .Menu)
		}
	}
}
