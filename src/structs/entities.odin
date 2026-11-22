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
	pos:                   [2]f32,
	vel:                   [2]f32,
	hp:                    f32,
	max_hp:                f32,
	speed:                 f32,
	radius:                f32,
	kind:                  Enemy_Kind,
	status_flags:          Status_Flags,
	burn_timer:            f32,
	slow_timer:            f32,
	last_hit_ability_slot: int,
	last_query_stamp:      u32,
}

Projectile_Kind :: enum u8 {
	Bolt,
	Returning_Knife,
	Mana_Orb,
}

Projectile :: struct {
	kind:           Projectile_Kind,
	pos:            [2]f32,
	vel:            [2]f32,
	radius:         f32,
	damage:         f32,
	lifetime:       f32,
	ability_slot:   int,
	// Returning knife state
	returning:      bool,
	out_timer:      f32,
	return_speed:   f32,
	last_hit_enemy: i32,
	// Mana orb pulsing aura state
	aura_radius:    f32,
	pulse_timer:    f32,
	pulse_interval: f32,
}

Player :: struct {
	pos:                    [2]f32,
	vel:                    [2]f32,
	hp:                     f32,
	max_hp:                 f32,
	speed:                  f32,
	radius:                 f32,
	invuln_timer:           f32,
	melee_swing_timer:      f32,
	melee_swing_dir:        [2]f32,
	melee_swing_range:      f32,
	melee_swing_half_angle: f32,
	stab_visual_timer:      f32,
	stab_dir:               [2]f32,
	stab_range:             f32,
	reflect_timer:          f32,
	reflect_slot:           int,
	lunge_timer:            f32,
	lunge_dir:              [2]f32,
	lunge_speed:            f32,
	lunge_damage:           f32,
	lunge_range:            f32,
	lunge_slot:             int,
	lunge_hit_timer:        f32,
	nova_visual_timer:      f32,
	nova_visual_pos:        [2]f32,
	nova_visual_radius:     f32,
	shield_hp:              f32,
	shield_max_hp:          f32,
	shield_timer:           f32,
	shield_slot:            int,
	dash_timer:             f32,
	dash_dir:               [2]f32,
	dash_speed:             f32,
	haste_timer:            f32,
	haste_mult:             f32,
	mend_timer:             f32,
	mend_hps:               f32,
	abilities:              [MAX_ABILITIES]Ability,
	ability_count:          int,
}
