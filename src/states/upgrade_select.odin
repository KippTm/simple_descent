package states

import rl "vendor:raylib"
import "../abilities"
import "../structs"

// -----------------------------------------------------------------------------
// Upgrade Focus Selection Overlay (Every 3rd Ability Level)
// -----------------------------------------------------------------------------

UPGRADE_CARD_W   :: 210
UPGRADE_CARD_H   :: 132
UPGRADE_CARD_GAP :: 20
UPGRADE_CARD_Y   :: 310

get_ability_focus_options :: proc(id: structs.Ability_Id) -> ([4]structs.Upgrade_Focus, int) {
	allowed := abilities.ABILITY_DEFS[id].allowed_focuses
	options: [4]structs.Upgrade_Focus
	count := 0
	for f in structs.Upgrade_Focus {
		if f in allowed {
			options[count] = f
			count += 1
		}
	}
	return options, count
}

upgrade_option_rect :: proc(idx, count: int) -> rl.Rectangle {
	total_w := count * UPGRADE_CARD_W + (count - 1) * UPGRADE_CARD_GAP
	start_x := (structs.WINDOW_WIDTH - total_w) / 2
	x := start_x + idx * (UPGRADE_CARD_W + UPGRADE_CARD_GAP)
	return rl.Rectangle{f32(x), f32(UPGRADE_CARD_Y), f32(UPGRADE_CARD_W), f32(UPGRADE_CARD_H)}
}

check_pending_upgrade_focus :: proc(state: ^structs.Game_State) -> bool {
	for i in 0 ..< state.player.ability_count {
		if state.player.abilities[i].pending_focus_choice {
			state.upgrade_select_slot = i
			state.upgrade_select_cursor = 0
			// Pre-highlight the ability's current focus
			options, count := get_ability_focus_options(state.player.abilities[i].id)
			for j in 0 ..< count {
				if options[j] == state.player.abilities[i].upgrade_focus {
					state.upgrade_select_cursor = j
					break
				}
			}
			change_state(state, .Upgrade_Select)
			return true
		}
	}
	return false
}

apply_upgrade_focus_choice :: proc(state: ^structs.Game_State, chosen: structs.Upgrade_Focus) {
	slot := state.upgrade_select_slot
	if slot >= 0 && slot < state.player.ability_count {
		state.player.abilities[slot].upgrade_focus = chosen
		state.player.abilities[slot].pending_focus_choice = false
	}

	// If another ability also hit a milestone on the same frame, prompt it next
	if !check_pending_upgrade_focus(state) {
		change_state(state, .Playing)
	}
}

update_upgrade_select :: proc(state: ^structs.Game_State) {
	slot := state.upgrade_select_slot
	if slot < 0 || slot >= state.player.ability_count {
		change_state(state, .Playing)
		return
	}

	ability := &state.player.abilities[slot]
	options, count := get_ability_focus_options(ability.id)
	if count <= 0 {
		ability.pending_focus_choice = false
		change_state(state, .Playing)
		return
	}

	if rl.IsKeyPressed(.A) || rl.IsKeyPressed(.LEFT) || rl.IsKeyPressed(.W) || rl.IsKeyPressed(.UP) {
		state.upgrade_select_cursor = (state.upgrade_select_cursor - 1 + count) % count
	}
	if rl.IsKeyPressed(.D) || rl.IsKeyPressed(.RIGHT) || rl.IsKeyPressed(.S) || rl.IsKeyPressed(.DOWN) {
		state.upgrade_select_cursor = (state.upgrade_select_cursor + 1) % count
	}

	// Direct number key selection (1..4)
	if count >= 1 && (rl.IsKeyPressed(.ONE) || rl.IsKeyPressed(.KP_1)) {
		apply_upgrade_focus_choice(state, options[0])
		return
	}
	if count >= 2 && (rl.IsKeyPressed(.TWO) || rl.IsKeyPressed(.KP_2)) {
		apply_upgrade_focus_choice(state, options[1])
		return
	}
	if count >= 3 && (rl.IsKeyPressed(.THREE) || rl.IsKeyPressed(.KP_3)) {
		apply_upgrade_focus_choice(state, options[2])
		return
	}
	if count >= 4 && (rl.IsKeyPressed(.FOUR) || rl.IsKeyPressed(.KP_4)) {
		apply_upgrade_focus_choice(state, options[3])
		return
	}

	if rl.IsKeyPressed(.ENTER) || rl.IsKeyPressed(.SPACE) {
		apply_upgrade_focus_choice(state, options[state.upgrade_select_cursor])
		return
	}

	// Mouse hover & click support
	mouse_pos := rl.GetMousePosition()
	for i in 0 ..< count {
		rect := upgrade_option_rect(i, count)
		if rl.CheckCollisionPointRec(mouse_pos, rect) {
			state.upgrade_select_cursor = i
			if rl.IsMouseButtonPressed(.LEFT) {
				apply_upgrade_focus_choice(state, options[i])
				return
			}
			break
		}
	}
}
