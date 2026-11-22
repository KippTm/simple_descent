package states

import rl "vendor:raylib"
import "../abilities"
import "../structs"

// -----------------------------------------------------------------------------
// Loadout Selection State (3 Category Columns: Physical | Magical | Utility)
// -----------------------------------------------------------------------------

LOADOUT_COLS     :: 3
LOADOUT_COL_W    :: 360
LOADOUT_COL_GAP  :: 28
LOADOUT_HEADER_Y :: 174
LOADOUT_HEADER_H :: 30
LOADOUT_LIST_Y   :: 214
LOADOUT_CARD_H   :: 62
LOADOUT_CARD_GAP :: 10

LOADOUT_START_BTN_W :: 260
LOADOUT_START_BTN_H :: 46
LOADOUT_START_BTN_Y :: 592

LOADOUT_COL_CATEGORIES := [LOADOUT_COLS]structs.Ability_Category {
	.Physical,
	.Magical,
	.Utility,
}

clear_loadout :: proc(state: ^structs.Game_State) {
	state.selected_loadout = {}
	state.selected_loadout_count = 0
	state.loadout_cursor = 0
}

loadout_col_items :: proc(col: int) -> ([16]int, int) {
	cat := LOADOUT_COL_CATEGORIES[col]
	items: [16]int
	count := 0
	for i in 0 ..< len(abilities.SELECTABLE_ABILITIES) {
		id := abilities.SELECTABLE_ABILITIES[i]
		if abilities.ABILITY_DEFS[id].category == cat {
			items[count] = i
			count += 1
		}
	}
	return items, count
}

loadout_cursor_col_row :: proc(cursor: int) -> (int, int) {
	for col in 0 ..< LOADOUT_COLS {
		items, count := loadout_col_items(col)
		for row in 0 ..< count {
			if items[row] == cursor {
				return col, row
			}
		}
	}
	return 0, 0
}

loadout_col_x :: proc(col: int) -> i32 {
	total_w := LOADOUT_COLS * LOADOUT_COL_W + (LOADOUT_COLS - 1) * LOADOUT_COL_GAP
	start_x := (structs.WINDOW_WIDTH - total_w) / 2
	return i32(start_x + col * (LOADOUT_COL_W + LOADOUT_COL_GAP))
}

loadout_col_header_rect :: proc(col: int) -> rl.Rectangle {
	return rl.Rectangle{f32(loadout_col_x(col)), f32(LOADOUT_HEADER_Y), f32(LOADOUT_COL_W), f32(LOADOUT_HEADER_H)}
}

loadout_card_rect_for_col_row :: proc(col, row: int) -> rl.Rectangle {
	x := loadout_col_x(col)
	y := LOADOUT_LIST_Y + row * (LOADOUT_CARD_H + LOADOUT_CARD_GAP)
	return rl.Rectangle{f32(x), f32(y), f32(LOADOUT_COL_W), f32(LOADOUT_CARD_H)}
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

	col, row := loadout_cursor_col_row(state.loadout_cursor)

	// Move between the 3 category columns (A/D or Left/Right)
	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) {
		next_col := (col - 1 + LOADOUT_COLS) % LOADOUT_COLS
		items, count := loadout_col_items(next_col)
		if count > 0 {
			state.loadout_cursor = items[min(row, count - 1)]
		}
	}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) {
		next_col := (col + 1) % LOADOUT_COLS
		items, count := loadout_col_items(next_col)
		if count > 0 {
			state.loadout_cursor = items[min(row, count - 1)]
		}
	}

	// Move up/down within the current column (W/S or Up/Down)
	if rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		items, count := loadout_col_items(col)
		if count > 0 {
			next_row := (row - 1 + count) % count
			state.loadout_cursor = items[next_row]
		}
	}
	if rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		items, count := loadout_col_items(col)
		if count > 0 {
			next_row := (row + 1) % count
			state.loadout_cursor = items[next_row]
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

	// Mouse hover & click support across all 3 columns
	mouse_pos := rl.GetMousePosition()
	mouse_hit := false
	for c in 0 ..< LOADOUT_COLS {
		items, count := loadout_col_items(c)
		for r in 0 ..< count {
			rect := loadout_card_rect_for_col_row(c, r)
			if rl.CheckCollisionPointRec(mouse_pos, rect) {
				state.loadout_cursor = items[r]
				if rl.IsMouseButtonPressed(.LEFT) {
					toggle_loadout_ability(state, abilities.SELECTABLE_ABILITIES[items[r]])
				}
				mouse_hit = true
				break
			}
		}
		if mouse_hit do break
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
