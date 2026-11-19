package structs

// -----------------------------------------------------------------------------
// Entities (Structure of Arrays Ready)
// -----------------------------------------------------------------------------

Enemy_Kind :: enum u8 {
	Basic_Chaser,
	Ranged_Shooter,
	Boss,
}

Enemy :: struct {
	pos:          [2]f32,
	vel:          [2]f32,
	hp:           f32,
	max_hp:       f32,
	speed:        f32,
	radius:       f32,
	kind:         Enemy_Kind,
	status_flags: Status_Flags,
	burn_timer:   f32,
	slow_timer:   f32,
}

Projectile :: struct {
	pos:          [2]f32,
	vel:          [2]f32,
	radius:       f32,
	damage:       f32,
	lifetime:     f32,
	ability_slot: int,
}

Player :: struct {
	pos:               [2]f32,
	vel:               [2]f32,
	hp:                f32,
	max_hp:            f32,
	speed:             f32,
	radius:            f32,
	invuln_timer:      f32,
	melee_swing_timer: f32,
	melee_swing_dir:   [2]f32,
	dash_timer:        f32,
	dash_dir:          [2]f32,
	abilities:         [MAX_ABILITIES]Ability,
	ability_count:     int,
}
