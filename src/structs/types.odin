package structs

// -----------------------------------------------------------------------------
// Constants & Configuration
// -----------------------------------------------------------------------------

WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720

MAX_ENEMIES     :: 16384
MAX_PROJECTILES :: 4096
MAX_ABILITIES   :: 6

// Melee Sweep & Dash Configuration
MELEE_RANGE            :: 68.0
MELEE_HALF_ANGLE       :: 0.85 // ~48 degrees half-angle (~97 degree total swing arc)
MELEE_SWING_VISUAL_DUR :: 0.16
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
	Playing,
	Paused,
}

// -----------------------------------------------------------------------------
// Data-Driven Combat & Specialization Types
// -----------------------------------------------------------------------------

Ability_Kind :: enum u8 {
	None,
	Melee_Sweep,
	Targeted_Projectile,
	Defensive_Dash,
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
	kind:          Ability_Kind,
	level:         int,
	xp:            f32,
	spec_type:     Spec_Type,
	spec_tier:     int,
	cooldown:      f32,
	cooldown_time: f32,
}
