package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Physical Ability: Reflect (Brief Damage-Reflecting Parry Window)
// -----------------------------------------------------------------------------

REFLECT_DEF :: structs.Ability_Def {
	id              = .Reflect,
	name            = "Reflect",
	short_desc      = "Parry window that reflects incoming damage back.",
	category        = .Physical,
	cooldown_time   = 1.80,
	default_focus   = .Duration,
	allowed_focuses = {.Damage, .Duration},
}

REFLECT_BASE_DURATION :: 0.22
REFLECT_DURATION_STEP :: 0.04
REFLECT_DAMAGE_MULT   :: 2.0
REFLECT_DAMAGE_STEP   :: 0.15
REFLECT_KNOCKBACK     :: 36.0
REFLECT_PARRY_XP      :: 1.5

cast_reflect :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = aim_dir
	_ = move_input
	ability := state.player.abilities[slot]
	duration := f32(REFLECT_BASE_DURATION) + f32(REFLECT_DURATION_STEP) * f32(ability.focus_ranks[.Duration])

	state.player.reflect_timer = duration
	state.player.reflect_slot = slot
}

// Invoked when an enemy attempts to damage the player while reflect_timer > 0.
// Reflects scaled damage back to the attacker, grants parry XP, and pushes enemy away.
on_player_reflect_hit :: proc(state: ^structs.Game_State, enemy_idx: int, incoming_damage: f32) {
	slot := state.player.reflect_slot
	if slot < 0 || slot >= state.player.ability_count do return

	ability := &state.player.abilities[slot]
	dmg_mult := 1.0 + f32(REFLECT_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	reflected_damage := incoming_damage * f32(REFLECT_DAMAGE_MULT) * dmg_mult

	apply_ability_hit(state, slot, enemy_idx, reflected_damage)
	grant_ability_xp(ability, REFLECT_PARRY_XP)

	// Push attacker away strongly on parry
	diff := state.enemies[enemy_idx].pos - state.player.pos
	d2 := linalg.length2(diff)
	if d2 > 0.0001 {
		state.enemies[enemy_idx].pos += (diff / math.sqrt(d2)) * REFLECT_KNOCKBACK
	}

	// Brief post-parry i-frames so multi-enemy contact on the same frame doesn't chip the player
	state.player.invuln_timer = max(state.player.invuln_timer, 0.20)
}
