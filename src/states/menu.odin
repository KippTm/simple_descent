package states

import rl "vendor:raylib"
import "../structs"

// -----------------------------------------------------------------------------
// Main Menu State
// -----------------------------------------------------------------------------

MENU_OPTION_COUNT :: 2

update_menu :: proc(state: ^structs.Game_State) {
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		state.menu_selection = (state.menu_selection - 1 + MENU_OPTION_COUNT) % MENU_OPTION_COUNT
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		state.menu_selection = (state.menu_selection + 1) % MENU_OPTION_COUNT
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		switch state.menu_selection {
		case 0: // Start Run -> Loadout Selection (no default loadout)
			clear_loadout(state)
			change_state(state, .Loadout_Select)
		case 1: // Quit
			state.should_quit = true
		}
	}
}
