package abilities

import "../structs"

// -----------------------------------------------------------------------------
// Ability Registry & Concrete Cast Proc Dispatch Table
// -----------------------------------------------------------------------------

Ability_Cast_Proc :: #type proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32)

ABILITY_DEFS := [structs.Ability_Id]structs.Ability_Def {
	.None        = {},
	.Sweep       = SWEEP_DEF,
	.Stab        = STAB_DEF,
	.Reflect     = REFLECT_DEF,
	.Knife_Throw = KNIFE_THROW_DEF,
	.Lunge       = LUNGE_DEF,
	.Mana_Bolt   = MANA_BOLT_DEF,
	.Mana_Shield = MANA_SHIELD_DEF,
	.Mana_Nova   = MANA_NOVA_DEF,
	.Mana_Orb    = MANA_ORB_DEF,
	.Dash        = DASH_DEF,
	.Haste       = HASTE_DEF,
	.Mend        = MEND_DEF,
}

ABILITY_CAST_PROCS := [structs.Ability_Id]Ability_Cast_Proc {
	.None        = nil,
	.Sweep       = cast_sweep,
	.Stab        = cast_stab,
	.Reflect     = cast_reflect,
	.Knife_Throw = cast_knife_throw,
	.Lunge       = cast_lunge,
	.Mana_Bolt   = cast_mana_bolt,
	.Mana_Shield = cast_mana_shield,
	.Mana_Nova   = cast_mana_nova,
	.Mana_Orb    = cast_mana_orb,
	.Dash        = cast_dash,
	.Haste       = cast_haste,
	.Mend        = cast_mend,
}

SELECTABLE_ABILITIES := [?]structs.Ability_Id {
	.Sweep,
	.Stab,
	.Reflect,
	.Knife_Throw,
	.Lunge,
	.Mana_Bolt,
	.Mana_Shield,
	.Mana_Nova,
	.Mana_Orb,
	.Dash,
	.Haste,
	.Mend,
}

DEFAULT_LOADOUT := [structs.STARTING_ABILITY_COUNT]structs.Ability_Id {
	.Sweep,
	.Mana_Bolt,
	.Dash,
}

// All abilities start unspecialized at level 1 with their default upgrade focus.
make_ability :: proc(id: structs.Ability_Id) -> structs.Ability {
	def := ABILITY_DEFS[id]
	return structs.Ability {
		id                   = id,
		level                = 1,
		xp                   = 0,
		spec_type            = .None,
		spec_tier            = 0,
		cooldown             = 0,
		cooldown_time        = def.cooldown_time,
		upgrade_focus        = def.default_focus,
		focus_ranks          = {},
		pending_focus_choice = false,
	}
}

trigger_ability :: proc(state: ^structs.Game_State, slot: int, aim_dir, move_input: [2]f32) {
	if slot < 0 || slot >= state.player.ability_count do return

	ability := &state.player.abilities[slot]
	if ability.cooldown > 0 || ability.id == .None do return

	cast_proc := ABILITY_CAST_PROCS[ability.id]
	if cast_proc == nil do return

	ability.cooldown = ability.cooldown_time
	cast_proc(state, slot, aim_dir, move_input)
}
