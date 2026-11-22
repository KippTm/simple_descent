package abilities

import "core:math"
import "core:math/linalg"
import "../structs"

// -----------------------------------------------------------------------------
// Magical Ability: Mana Orb (Slowly Moving Pulsing Damage Orbs)
// -----------------------------------------------------------------------------

MANA_ORB_DEF :: structs.Ability_Def {
	id              = .Mana_Orb,
	name            = "Mana Orb",
	short_desc      = "Spawns 3 slow orbs that damage enemies within range.",
	category        = .Magical,
	cooldown_time   = 4.00,
	default_focus   = .Damage,
	allowed_focuses = {.Damage, .Range, .Projectiles},
}

MANA_ORB_BASE_COUNT    :: 3
MANA_ORB_BASE_DAMAGE   :: 7.0
MANA_ORB_DAMAGE_STEP   :: 0.15
MANA_ORB_BASE_RANGE    :: 44.0 // Aura damage radius (z)
MANA_ORB_RANGE_STEP    :: 0.15
MANA_ORB_SPEED         :: 115.0
MANA_ORB_CORE_RADIUS   :: 7.0
MANA_ORB_LIFETIME      :: 3.50
MANA_ORB_PULSE_INTERVAL :: 0.40
MANA_ORB_FAN_STEP      :: 0.45 // Radians between orbs

cast_mana_orb :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	_ = move_input
	ability := state.player.abilities[slot]
	dmg_mult := 1.0 + f32(MANA_ORB_DAMAGE_STEP) * f32(ability.focus_ranks[.Damage])
	range_mult := 1.0 + f32(MANA_ORB_RANGE_STEP) * f32(ability.focus_ranks[.Range])

	damage := f32(MANA_ORB_BASE_DAMAGE) * dmg_mult
	aura_radius := f32(MANA_ORB_BASE_RANGE) * range_mult
	count := MANA_ORB_BASE_COUNT + ability.focus_ranks[.Projectiles]

	dir := aim_dir
	if linalg.length2(dir) > 0.0001 {
		dir = linalg.normalize(dir)
	} else {
		dir = {1, 0}
	}

	base_angle := math.atan2(dir.y, dir.x)
	half_spread := f32(count - 1) * f32(MANA_ORB_FAN_STEP) * 0.5

	for i in 0 ..< count {
		if state.projectile_count >= structs.MAX_PROJECTILES do break

		angle := base_angle - half_spread + f32(i) * f32(MANA_ORB_FAN_STEP)
		orb_dir := [2]f32{math.cos(angle), math.sin(angle)}

		idx := state.projectile_count
		state.projectile_count += 1
		state.projectiles[idx] = structs.Projectile {
			kind           = .Mana_Orb,
			pos            = state.player.pos + orb_dir * 16.0,
			vel            = orb_dir * MANA_ORB_SPEED,
			radius         = MANA_ORB_CORE_RADIUS,
			damage         = damage,
			lifetime       = MANA_ORB_LIFETIME,
			ability_slot   = slot,
			last_hit_enemy = -1,
			aura_radius    = aura_radius,
			pulse_timer    = 0.05, // First pulse fires almost immediately
			pulse_interval = MANA_ORB_PULSE_INTERVAL,
		}
	}
}
