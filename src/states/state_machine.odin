package states

import rl "vendor:raylib"
import "../structs"

// -----------------------------------------------------------------------------
// State Machine Dispatcher
// -----------------------------------------------------------------------------

change_state :: proc(state: ^structs.Game_State, next: structs.State_Kind) {
	#partial switch next {
	case .Menu:
		state.menu_selection = 0
	case .Loadout_Select:
		state.loadout_cursor = 0
	case .Paused:
		state.pause_selection = 0
	}
	state.current_state = next
}

update_state_machine :: proc(state: ^structs.Game_State, dt: f32, camera: rl.Camera2D) {
	switch state.current_state {
	case .Menu:
		update_menu(state)
	case .Loadout_Select:
		update_loadout_select(state)
	case .Playing:
		update_playing(state, dt, camera)
	case .Paused:
		update_pause(state)
	}
}
