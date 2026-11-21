package abilities

import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Magical Ability: Mana Bolt (Simple Unaspected Bolt)
// -----------------------------------------------------------------------------

MANA_BOLT_DEF :: structs.Ability_Def {
	id            = .Mana_Bolt,
	name          = "Mana Bolt",
	short_desc    = "Fires a fast, unaspected bolt toward your cursor.",
	category      = .Magical,
	cooldown_time = 0.65,
}

MANA_BOLT_BASE_DAMAGE :: 15.0
MANA_BOLT_LEVEL_SCALE :: 0.12
MANA_BOLT_SPEED       :: 520.0
MANA_BOLT_RADIUS      :: 4.0
MANA_BOLT_LIFETIME    :: 1.75

cast_mana_bolt :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	level_mult := 1.0 + f32(MANA_BOLT_LEVEL_SCALE) * f32(ability.level - 1)
	damage := f32(MANA_BOLT_BASE_DAMAGE) * level_mult

	dir := aim_dir
	if linalg.length2(dir) > 0.0001 {
		dir = linalg.normalize(dir)
	} else {
		dir = {1, 0}
	}

	spawn_bolt_projectile(
		state,
		state.player.pos,
		dir,
		MANA_BOLT_SPEED,
		MANA_BOLT_RADIUS,
		damage,
		MANA_BOLT_LIFETIME,
		slot,
	)
}
