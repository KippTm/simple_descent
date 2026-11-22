package abilities

import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Utility Ability: Dash (Quick Directional Burst + I-Frames)
// -----------------------------------------------------------------------------

DASH_DEF :: structs.Ability_Def {
	id              = .Dash,
	name            = "Dash",
	short_desc      = "Quick burst of movement with brief invulnerability.",
	category        = .Utility,
	cooldown_time   = 2.0,
	default_focus   = .Range,
	allowed_focuses = {.Range, .Duration},
}

DASH_RANGE_STEP    :: 0.10
DASH_DURATION_STEP :: 0.03
DASH_UTILITY_XP    :: 1.5 // Utility abilities gain XP on every cast, at a slower pace

cast_dash :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	ability := &state.player.abilities[slot]
	dash_dir := move_input if linalg.length2(move_input) > 0.001 else aim_dir
	if linalg.length2(dash_dir) > 0.0001 {
		dash_dir = linalg.normalize(dash_dir)
	} else {
		dash_dir = {1, 0}
	}

	dash_mult := 1.0 + f32(DASH_RANGE_STEP) * f32(ability.focus_ranks[.Range])
	iframe_dur := f32(structs.DASH_DURATION) + 0.15 + f32(DASH_DURATION_STEP) * f32(ability.focus_ranks[.Duration])
	state.player.dash_dir = dash_dir
	state.player.dash_speed = structs.DASH_SPEED * dash_mult
	state.player.dash_timer = structs.DASH_DURATION
	state.player.invuln_timer = max(state.player.invuln_timer, iframe_dur)

	grant_ability_xp(ability, DASH_UTILITY_XP)
}
