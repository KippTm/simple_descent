package states

import rl "vendor:raylib"
import "../abilities"
import "../structs"

// -----------------------------------------------------------------------------
// Loadout Selection State (Choose Starting 3 Abilities)
// -----------------------------------------------------------------------------

LOADOUT_CARD_W   :: 270
LOADOUT_CARD_H   :: 128
LOADOUT_CARD_GAP :: 20
LOADOUT_GRID_Y   :: 248
LOADOUT_COLS     :: 4

LOADOUT_START_BTN_W :: 260
LOADOUT_START_BTN_H :: 48
LOADOUT_START_BTN_Y :: 576

init_default_loadout :: proc(state: ^structs.Game_State) {
	state.selected_loadout = abilities.DEFAULT_LOADOUT
	state.selected_loadout_count = structs.STARTING_ABILITY_COUNT
	state.loadout_cursor = 0
}

loadout_card_rect :: proc(idx: int) -> rl.Rectangle {
	row := idx / LOADOUT_COLS
	col := idx % LOADOUT_COLS
	total_count := len(abilities.SELECTABLE_ABILITIES)
	items_in_row := LOADOUT_COLS if row == 0 else (total_count - LOADOUT_COLS)
	row_w := items_in_row * LOADOUT_CARD_W + (items_in_row - 1) * LOADOUT_CARD_GAP
	start_x := (structs.WINDOW_WIDTH - row_w) / 2
	x := start_x + col * (LOADOUT_CARD_W + LOADOUT_CARD_GAP)
	y := LOADOUT_GRID_Y + row * (LOADOUT_CARD_H + LOADOUT_CARD_GAP)
	return rl.Rectangle{f32(x), f32(y), f32(LOADOUT_CARD_W), f32(LOADOUT_CARD_H)}
}

loadout_start_btn_rect :: proc() -> rl.Rectangle {
	x := (structs.WINDOW_WIDTH - LOADOUT_START_BTN_W) / 2
	return rl.Rectangle{f32(x), f32(LOADOUT_START_BTN_Y), f32(LOADOUT_START_BTN_W), f32(LOADOUT_START_BTN_H)}
}

toggle_loadout_ability :: proc(state: ^structs.Game_State, id: structs.Ability_Id) {
	// If already selected, remove it and shift remaining slots left
	for i in 0 ..< state.selected_loadout_count {
		if state.selected_loadout[i] == id {
			for j := i; j < state.selected_loadout_count - 1; j += 1 {
				state.selected_loadout[j] = state.selected_loadout[j + 1]
			}
			state.selected_loadout_count -= 1
			state.selected_loadout[state.selected_loadout_count] = .None
			return
		}
	}

	// Otherwise append if there is an open slot
	if state.selected_loadout_count < structs.STARTING_ABILITY_COUNT {
		state.selected_loadout[state.selected_loadout_count] = id
		state.selected_loadout_count += 1
	}
}

update_loadout_select :: proc(state: ^structs.Game_State) {
	total := len(abilities.SELECTABLE_ABILITIES)
	if total == 0 do return

	if rl.IsKeyPressed(.ESCAPE) {
		change_state(state, .Menu)
		return
	}

	// Keyboard grid navigation
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		state.loadout_cursor = (state.loadout_cursor - 1 + total) % total
	}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		state.loadout_cursor = (state.loadout_cursor + 1) % total
	}
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		if state.loadout_cursor >= LOADOUT_COLS {
			state.loadout_cursor -= LOADOUT_COLS
		} else {
			next := state.loadout_cursor + LOADOUT_COLS
			state.loadout_cursor = min(next, total - 1)
		}
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		if state.loadout_cursor < LOADOUT_COLS {
			next := state.loadout_cursor + LOADOUT_COLS
			state.loadout_cursor = min(next, total - 1)
		} else {
			state.loadout_cursor -= LOADOUT_COLS
		}
	}

	// Remove last selected slot with Backspace
	if rl.IsKeyPressed(.BACKSPACE) && state.selected_loadout_count > 0 {
		state.selected_loadout_count -= 1
		state.selected_loadout[state.selected_loadout_count] = .None
	}

	// Toggle highlighted ability with Space
	if rl.IsKeyPressed(.SPACE) {
		toggle_loadout_ability(state, abilities.SELECTABLE_ABILITIES[state.loadout_cursor])
	}

	// Enter starts run when 3 abilities are chosen; otherwise toggles current ability
	if rl.IsKeyPressed(.ENTER) {
		if state.selected_loadout_count == structs.STARTING_ABILITY_COUNT {
			reset_run(state)
			change_state(state, .Playing)
			return
		} else {
			toggle_loadout_ability(state, abilities.SELECTABLE_ABILITIES[state.loadout_cursor])
		}
	}

	// Mouse hover & click support
	mouse_pos := rl.GetMousePosition()
	for i in 0 ..< total {
		rect := loadout_card_rect(i)
		if rl.CheckCollisionPointRec(mouse_pos, rect) {
			state.loadout_cursor = i
			if rl.IsMouseButtonPressed(.LEFT) {
				toggle_loadout_ability(state, abilities.SELECTABLE_ABILITIES[i])
			}
			break
		}
	}

	start_rect := loadout_start_btn_rect()
	if state.selected_loadout_count == structs.STARTING_ABILITY_COUNT &&
	   rl.CheckCollisionPointRec(mouse_pos, start_rect) &&
	   rl.IsMouseButtonPressed(.LEFT) {
		reset_run(state)
		change_state(state, .Playing)
		return
	}
}
