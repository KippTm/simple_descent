package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Physical Ability: Knife Throw (Returning Piercing Knife)
// -----------------------------------------------------------------------------

KNIFE_THROW_DEF :: structs.Ability_Def {
	id              = .Knife_Throw,
	name            = "Knife Throw",
	short_desc      = "Throws a piercing knife that returns to you.",
	category        = .Physical,
	cooldown_time   = 0.75,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range, .Projectiles},
}

KNIFE_BASE_DAMAGE  :: 12.0
KNIFE_DAMAGE_STEP  :: 0.15
KNIFE_SPEED        :: 480.0
KNIFE_RETURN_SPEED :: 560.0
KNIFE_RADIUS       :: 6.0
KNIFE_OUT_TIME     :: 0.38
KNIFE_RANGE_STEP   :: 0.15
KNIFE_SPREAD_STEP  :: 0.14

cast_knife_throw :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(KNIFE_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(KNIFE_RANGE_STEP) * f32(ability.focus_ranks[.Range])

	damage := f32(KNIFE_BASE_DAMAGE) * dmg_mult
	out_time := f32(KNIFE_OUT_TIME) * range_mult
	count := 1 + ability.focus_ranks[.Projectiles]

	dir := aim_dir
	if linalg.length2(dir) > 0.0001 {
		dir = linalg.normalize(dir)
	} else {
		dir = {1, 0}
	}

	base_angle := math.atan2(dir.y, dir.x)
	half_spread := f32(count - 1) * f32(KNIFE_SPREAD_STEP) * 0.5

	for i in 0 ..< count {
		if state.projectile_count >= structs.MAX_PROJECTILES do break

		angle := base_angle - half_spread + f32(i) * f32(KNIFE_SPREAD_STEP)
		throw_dir := [2]f32{math.cos(angle), math.sin(angle)}

		idx := state.projectile_count
		state.projectile_count += 1
		state.projectiles[idx] = structs.Projectile {
			kind           = .Returning_Knife,
			pos            = state.player.pos,
			vel            = throw_dir * KNIFE_SPEED,
			radius         = KNIFE_RADIUS,
			damage         = damage,
			lifetime       = out_time * 3.0 + 1.5, // Safety cap if player sprints away
			ability_slot   = slot,
			returning      = false,
			out_timer      = out_time,
			return_speed   = KNIFE_RETURN_SPEED,
			last_hit_enemy = -1,
		}
	}
}
