package structs

// -----------------------------------------------------------------------------
// Constants & Configuration
// -----------------------------------------------------------------------------

WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720

MAX_ENEMIES            :: 16384
MAX_PROJECTILES        :: 4096
MAX_ABILITIES          :: 6
STARTING_ABILITY_COUNT :: 3
UPGRADE_FOCUS_INTERVAL :: 3 // Choose/change upgrade focus every 3rd level (3, 6, 9, ...)

// Melee Sweep, Stab & Dash Configuration
MELEE_RANGE            :: 68.0
MELEE_HALF_ANGLE       :: 0.85 // ~48 degrees half-angle (~97 degree total swing arc)
MELEE_SWING_VISUAL_DUR :: 0.16
STAB_VISUAL_DUR        :: 0.14
NOVA_VISUAL_DUR        :: 0.24
PLAYER_IFRAME_DURATION :: 0.55
DASH_DURATION          :: 0.15
DASH_SPEED             :: 760.0

// Spatial Hash Grid Configuration
// Using a power-of-two bucket count allows fast bitwise modulo (& (GRID_BUCKETS - 1))
GRID_CELL_SIZE :: 32.0
GRID_BUCKETS   :: 4096

// -----------------------------------------------------------------------------
// State Machine Types
// -----------------------------------------------------------------------------

State_Kind :: enum u8 {
	Menu,
	Loadout_Select,
	Playing,
	Paused,
	Upgrade_Select,
}

// -----------------------------------------------------------------------------
// Data-Driven Combat & Specialization Types
// -----------------------------------------------------------------------------

Ability_Category :: enum u8 {
	None,
	Physical,
	Magical,
	Utility,
}

Upgrade_Focus :: enum u8 {
	Damage,
	Range,
	Duration,
	Projectiles,
}

Upgrade_Focus_Set :: distinct bit_set[Upgrade_Focus; u8]

Ability_Id :: enum u8 {
	None,
	Sweep,
	Stab,
	Reflect,
	Knife_Throw,
	Lunge,
	Mana_Bolt,
	Mana_Shield,
	Mana_Nova,
	Mana_Orb,
	Dash,
	Haste,
	Mend,
}

Ability_Def :: struct {
	id:              Ability_Id,
	name:            cstring,
	short_desc:      cstring,
	category:        Ability_Category,
	cooldown_time:   f32,
	default_focus:   Upgrade_Focus,
	allowed_focuses: Upgrade_Focus_Set,
}

Spec_Type :: enum u8 {
	None,
	Blood, // Lifesteal / bleed
	Ice,   // Slow on hit
	Fire,  // Burn DoT
	Storm, // Chain lightning / shock
}

Status_Effect :: enum u8 {
	Burn,
	Slow,
	Bleed,
	Shock,
}

Status_Flags :: distinct bit_set[Status_Effect; u8]

Ability :: struct {
	id:                   Ability_Id,
	level:                int,
	xp:                   f32,
	spec_type:            Spec_Type,
	spec_tier:            int,
	cooldown:             f32,
	cooldown_time:        f32,
	upgrade_focus:        Upgrade_Focus,
	focus_ranks:          [Upgrade_Focus]int,
	pending_focus_choice: bool,
}
