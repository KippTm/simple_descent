package structs

// -----------------------------------------------------------------------------
// Constants & Configuration
// -----------------------------------------------------------------------------

WINDOW_WIDTH  :: 1280
WINDOW_HEIGHT :: 720

MAX_ENEMIES     :: 16384
MAX_PROJECTILES :: 4096
MAX_ABILITIES   :: 6

// Spatial Hash Grid Configuration
// Using a power-of-two bucket count allows fast bitwise modulo (& (GRID_BUCKETS - 1))
GRID_CELL_SIZE :: 32.0
GRID_BUCKETS   :: 4096

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
