package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Magical Ability: Mana Bolt (Simple Unaspected Bolt)
// -----------------------------------------------------------------------------

MANA_BOLT_DEF :: structs.Ability_Def {
	id              = .Mana_Bolt,
	name            = "Mana Bolt",
	short_desc      = "Fires a fast, unaspected bolt toward your cursor.",
	category        = .Magical,
	cooldown_time   = 0.65,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range, .Projectiles},
}

MANA_BOLT_BASE_DAMAGE :: 15.0
MANA_BOLT_DAMAGE_STEP :: 0.12
MANA_BOLT_SPEED       :: 520.0
MANA_BOLT_SPEED_STEP  :: 0.08
MANA_BOLT_RADIUS      :: 4.0
MANA_BOLT_LIFETIME    :: 1.75
MANA_BOLT_RANGE_STEP  :: 0.15
MANA_BOLT_SPREAD_STEP :: 0.12 // Radians between bolts when Projectile focus adds extra bolts

cast_mana_bolt :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(MANA_BOLT_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	speed_mult := 1.0 + f32(MANA_BOLT_SPEED_STEP) * f32(ability.focus_ranks[.Range])
	life_mult := 1.0 + f32(MANA_BOLT_RANGE_STEP) * f32(ability.focus_ranks[.Range])

	damage := f32(MANA_BOLT_BASE_DAMAGE) * dmg_mult
	speed := f32(MANA_BOLT_SPEED) * speed_mult
	lifetime := f32(MANA_BOLT_LIFETIME) * life_mult
	count := 1 + ability.focus_ranks[.Projectiles]

	dir := aim_dir
	if linalg.length2(dir) > 0.0001 {
		dir = linalg.normalize(dir)
	} else {
		dir = {1, 0}
	}

	base_angle := math.atan2(dir.y, dir.x)
	half_spread := f32(count - 1) * f32(MANA_BOLT_SPREAD_STEP) * 0.5

	for i in 0 ..< count {
		angle := base_angle - half_spread + f32(i) * f32(MANA_BOLT_SPREAD_STEP)
		bolt_dir := [2]f32{math.cos(angle), math.sin(angle)}
		spawn_bolt_projectile(
			state,
			state.player.pos,
			bolt_dir,
			speed,
			MANA_BOLT_RADIUS,
			damage,
			lifetime,
			slot,
		)
	}
}
