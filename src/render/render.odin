package render

import "core:fmt"
import rl "vendor:raylib"
import "../entities"
import "../structs"

// -----------------------------------------------------------------------------
// Rendering & HUD Overlay
// -----------------------------------------------------------------------------

render_game :: proc(state: ^structs.Game_State, camera: rl.Camera2D) {
	rl.BeginDrawing()
	defer rl.EndDrawing()

	rl.ClearBackground({16, 16, 22, 255})

	rl.BeginMode2D(camera)
	{
		render_world_grid(state.player.pos)
		render_enemies(state)
		render_projectiles(state)
		render_player(&state.player)
	}
	rl.EndMode2D()

	render_hud(state)
}

render_world_grid :: proc(player_pos: [2]f32) {
	// Draw subtle world reference grid around player
	grid_step :: 128
	start_x := (i32(player_pos.x) / grid_step - 8) * grid_step
	start_y := (i32(player_pos.y) / grid_step - 6) * grid_step
	for x := start_x; x <= start_x + 16 * grid_step; x += grid_step {
		rl.DrawLine(x, start_y, x, start_y + 12 * grid_step, {28, 28, 38, 255})
	}
	for y := start_y; y <= start_y + 12 * grid_step; y += grid_step {
		rl.DrawLine(start_x, y, start_x + 16 * grid_step, y, {28, 28, 38, 255})
	}
}

render_enemies :: proc(state: ^structs.Game_State) {
	for i in 0 ..< state.enemy_count {
		pos := state.enemies[i].pos
		rad := state.enemies[i].radius
		flags := state.enemies[i].status_flags

		color := rl.Color{215, 65, 65, 255}
		if .Slow in flags do color = {90, 185, 255, 255}
		if .Burn in flags do color = {255, 145, 40, 255}

		rl.DrawRectangleV({pos.x - rad, pos.y - rad}, {rad * 2, rad * 2}, color)
	}
}

render_projectiles :: proc(state: ^structs.Game_State) {
	for i in 0 ..< state.projectile_count {
		pos := state.projectiles[i].pos
		rad := state.projectiles[i].radius
		rl.DrawCircleV({pos.x, pos.y}, rad, rl.RAYWHITE)
	}
}

render_player :: proc(player: ^structs.Player) {
	p_pos := player.pos
	p_rad := player.radius
	rl.DrawCircleV({p_pos.x, p_pos.y}, p_rad, {80, 235, 145, 255})
}

render_hud :: proc(state: ^structs.Game_State) {
	// HUD Overlay (uses context.temp_allocator via fmt.ctprintf)
	ability0 := state.player.abilities[0]
	rl.DrawText(
		fmt.ctprintf(
			"FPS: %d | Enemies: %d / %d | Kills: %d / %d",
			rl.GetFPS(),
			state.enemy_count,
			structs.MAX_ENEMIES,
			state.kill_count,
			state.kill_quota,
		),
		16,
		16,
		20,
		rl.RAYWHITE,
	)
	rl.DrawText(
		fmt.ctprintf(
			"Primary Ability Lv.%d (XP: %.0f / %.0f) | Spec: %v (Tier %d)",
			ability0.level,
			ability0.xp,
			entities.xp_for_next_level(ability0.level),
			ability0.spec_type,
			ability0.spec_tier,
		),
		16,
		44,
		18,
		{180, 220, 255, 255},
	)
	rl.DrawText(
		"Controls: WASD = Move | Mouse = Aim | Hold SPACE = Spawn 100 Enemies/Frame",
		16,
		structs.WINDOW_HEIGHT - 32,
		18,
		{150, 150, 165, 255},
	)
}
