package render

import "core:fmt"
import "core:math"
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

	switch state.current_state {
	case .Menu:
		render_menu(state)
	case .Playing:
		render_world(state, camera)
		render_hud(state)
	case .Paused:
		render_world(state, camera)
		render_hud(state)
		render_pause(state)
	}
}

render_world :: proc(state: ^structs.Game_State, camera: rl.Camera2D) {
	rl.BeginMode2D(camera)
	{
		render_world_grid(state.player.pos)
		render_enemies(state)
		render_projectiles(state)
		render_player(&state.player)
	}
	rl.EndMode2D()
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
		hp := state.enemies[i].hp
		max_hp := state.enemies[i].max_hp
		flags := state.enemies[i].status_flags

		color := rl.Color{215, 65, 65, 255}
		if .Slow in flags do color = {90, 185, 255, 255}
		if .Burn in flags do color = {255, 145, 40, 255}

		rl.DrawRectangleV({pos.x - rad, pos.y - rad}, {rad * 2, rad * 2}, color)

		// Small health bar above each enemy
		bar_w: f32 = 22.0
		bar_h: f32 = 4.0
		bar_x := pos.x - bar_w * 0.5
		bar_y := pos.y - rad - 8.0
		hp_ratio := clamp(hp / max(max_hp, 1.0), 0.0, 1.0)

		rl.DrawRectangleRec({bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2}, {10, 10, 14, 220})
		rl.DrawRectangleRec({bar_x, bar_y, bar_w, bar_h}, {60, 25, 25, 255})
		rl.DrawRectangleRec({bar_x, bar_y, bar_w * hp_ratio, bar_h}, {235, 75, 75, 255})
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

	// Render Terraria-style broadsword arc & blade during melee swing
	if player.melee_swing_timer > 0 {
		progress := 1.0 - (player.melee_swing_timer / structs.MELEE_SWING_VISUAL_DUR)
		center_deg := math.atan2(player.melee_swing_dir.y, player.melee_swing_dir.x) * (180.0 / math.PI)
		half_deg := f32(structs.MELEE_HALF_ANGLE) * (180.0 / math.PI)
		start_deg := center_deg - half_deg
		end_deg := center_deg + half_deg

		// Translucent slash sector
		rl.DrawCircleSector(
			{p_pos.x, p_pos.y},
			structs.MELEE_RANGE,
			start_deg,
			end_deg,
			16,
			{255, 200, 110, 75},
		)
		rl.DrawCircleSectorLines(
			{p_pos.x, p_pos.y},
			structs.MELEE_RANGE,
			start_deg,
			end_deg,
			16,
			{255, 225, 150, 180},
		)

		// Sweeping sword blade line
		blade_deg := start_deg + (end_deg - start_deg) * progress
		blade_rad := blade_deg * (math.PI / 180.0)
		tip := [2]f32{
			p_pos.x + math.cos(blade_rad) * structs.MELEE_RANGE,
			p_pos.y + math.sin(blade_rad) * structs.MELEE_RANGE,
		}
		hilt := [2]f32{
			p_pos.x + math.cos(blade_rad) * (p_rad + 2.0),
			p_pos.y + math.sin(blade_rad) * (p_rad + 2.0),
		}
		rl.DrawLineEx({hilt.x, hilt.y}, {tip.x, tip.y}, 4.0, {245, 245, 255, 255})
	}

	// Flash player slightly during invulnerability frames
	body_color := rl.Color{80, 235, 145, 255}
	if player.invuln_timer > 0 {
		if int(player.invuln_timer * 20.0) % 2 == 0 {
			body_color = {255, 255, 255, 255}
		} else {
			body_color = {255, 110, 110, 255}
		}
	}
	rl.DrawCircleV({p_pos.x, p_pos.y}, p_rad, body_color)

	// World-space health bar above player
	bar_w: f32 = 34.0
	bar_h: f32 = 5.0
	bar_x := p_pos.x - bar_w * 0.5
	bar_y := p_pos.y - p_rad - 11.0
	hp_ratio := clamp(player.hp / max(player.max_hp, 1.0), 0.0, 1.0)

	rl.DrawRectangleRec({bar_x - 1, bar_y - 1, bar_w + 2, bar_h + 2}, {10, 10, 14, 230})
	rl.DrawRectangleRec({bar_x, bar_y, bar_w, bar_h}, {30, 55, 35, 255})
	rl.DrawRectangleRec({bar_x, bar_y, bar_w * hp_ratio, bar_h}, {80, 235, 145, 255})
}

render_hud :: proc(state: ^structs.Game_State) {
	// Top-Left Stats & Player HUD Health Bar
	rl.DrawText(
		fmt.ctprintf(
			"Wave: %d | Enemies: %d | Kills: %d / %d | FPS: %d",
			state.wave,
			state.enemy_count,
			state.kill_count,
			state.kill_quota,
			rl.GetFPS(),
		),
		16,
		16,
		20,
		rl.RAYWHITE,
	)

	// Prominent HUD Player Health Bar
	hp_bar_x: i32 = 16
	hp_bar_y: i32 = 46
	hp_bar_w: i32 = 220
	hp_bar_h: i32 = 20
	hp_ratio := clamp(state.player.hp / max(state.player.max_hp, 1.0), 0.0, 1.0)

	rl.DrawRectangle(hp_bar_x - 2, hp_bar_y - 2, hp_bar_w + 4, hp_bar_h + 4, {12, 12, 18, 240})
	rl.DrawRectangle(hp_bar_x, hp_bar_y, hp_bar_w, hp_bar_h, {45, 22, 26, 255})
	rl.DrawRectangle(hp_bar_x, hp_bar_y, i32(f32(hp_bar_w) * hp_ratio), hp_bar_h, {75, 225, 135, 255})
	rl.DrawRectangleLines(hp_bar_x - 2, hp_bar_y - 2, hp_bar_w + 4, hp_bar_h + 4, {110, 130, 145, 255})

	hp_text := fmt.ctprintf("HP: %.0f / %.0f", state.player.hp, state.player.max_hp)
	hp_text_w := rl.MeasureText(hp_text, 14)
	rl.DrawText(hp_text, hp_bar_x + (hp_bar_w - hp_text_w) / 2, hp_bar_y + 3, 14, rl.RAYWHITE)

	// Bottom Skill Bar Menu (Icons + Level + XP progress + Spec badge)
	render_skill_bar(&state.player)
}

spec_accent_color :: proc(spec: structs.Spec_Type) -> rl.Color {
	switch spec {
	case .None:
		return {130, 135, 155, 255}
	case .Blood:
		return {225, 55, 75, 255}
	case .Ice:
		return {85, 195, 255, 255}
	case .Fire:
		return {255, 140, 45, 255}
	case .Storm:
		return {195, 120, 255, 255}
	}
	return {130, 135, 155, 255}
}

draw_ability_icon :: proc(kind: structs.Ability_Kind, cx, cy: i32, accent: rl.Color) {
	switch kind {
	case .None:
	case .Melee_Sweep:
		// Diagonal Broadsword icon
		rl.DrawLineEx({f32(cx - 10), f32(cy + 10)}, {f32(cx + 11), f32(cy - 11)}, 4.0, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 11), f32(cy + 3)}, {f32(cx - 3), f32(cy + 11)}, 3.0, accent)
		rl.DrawCircle(cx - 12, cy + 12, 2.5, accent)
	case .Targeted_Projectile:
		// Magic bolt / orb with trail
		rl.DrawLineEx({f32(cx - 11), f32(cy + 8)}, {f32(cx + 4), f32(cy - 4)}, 3.0, accent)
		rl.DrawCircle(cx + 6, cy - 6, 6.0, accent)
		rl.DrawCircle(cx + 6, cy - 6, 3.0, rl.RAYWHITE)
	case .Defensive_Dash:
		// Winged boot / dash chevrons
		rl.DrawTriangle(
			{f32(cx + 11), f32(cy)},
			{f32(cx - 3), f32(cy - 9)},
			{f32(cx - 3), f32(cy + 9)},
			accent,
		)
		rl.DrawLineEx({f32(cx - 12), f32(cy - 5)}, {f32(cx - 5), f32(cy - 5)}, 2.5, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 14), f32(cy)}, {f32(cx - 5), f32(cy)}, 2.5, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 12), f32(cy + 5)}, {f32(cx - 5), f32(cy + 5)}, 2.5, rl.RAYWHITE)
	}
}

render_skill_bar :: proc(player: ^structs.Player) {
	count := player.ability_count
	if count <= 0 do return

	slot_size: i32 = 64
	slot_gap: i32 = 14
	total_w := i32(count) * slot_size + i32(count - 1) * slot_gap
	start_x := (structs.WINDOW_WIDTH - total_w) / 2
	bar_y: i32 = structs.WINDOW_HEIGHT - slot_size - 22

	// Subtle backing panel behind all skill slots
	panel_pad: i32 = 10
	rl.DrawRectangle(
		start_x - panel_pad,
		bar_y - panel_pad,
		total_w + panel_pad * 2,
		slot_size + panel_pad * 2,
		{10, 10, 15, 200},
	)
	rl.DrawRectangleLines(
		start_x - panel_pad,
		bar_y - panel_pad,
		total_w + panel_pad * 2,
		slot_size + panel_pad * 2,
		{45, 50, 68, 255},
	)

	for i in 0 ..< count {
		ability := player.abilities[i]
		sx := start_x + i32(i) * (slot_size + slot_gap)
		sy := bar_y
		accent := spec_accent_color(ability.spec_type)

		// Slot background
		rl.DrawRectangle(sx, sy, slot_size, slot_size, {24, 26, 36, 255})

		// Cooldown fill overlay
		if ability.cooldown_time > 0 && ability.cooldown > 0 {
			cd_ratio := clamp(ability.cooldown / ability.cooldown_time, 0.0, 1.0)
			cd_h := i32(f32(slot_size) * cd_ratio)
			rl.DrawRectangle(sx, sy + (slot_size - cd_h), slot_size, cd_h, {10, 10, 16, 170})
		}

		// Draw distinct ability vector icon in slot center
		draw_ability_icon(ability.kind, sx + slot_size / 2, sy + slot_size / 2 - 4, accent)

		// XP progress bar at bottom of the slot
		xp_req := entities.xp_for_next_level(ability.level)
		xp_ratio := clamp(ability.xp / max(xp_req, 1.0), 0.0, 1.0)
		xp_h: i32 = 5
		rl.DrawRectangle(sx + 2, sy + slot_size - xp_h - 2, slot_size - 4, xp_h, {15, 16, 22, 255})
		rl.DrawRectangle(
			sx + 2,
			sy + slot_size - xp_h - 2,
			i32(f32(slot_size - 4) * xp_ratio),
			xp_h,
			accent,
		)

		// Slot border colored by specialization
		rl.DrawRectangleLines(sx, sy, slot_size, slot_size, accent)

		// Level badge at bottom-right
		lvl_str := fmt.ctprintf("Lv.%d", ability.level)
		lvl_w := rl.MeasureText(lvl_str, 12)
		rl.DrawRectangle(sx + slot_size - lvl_w - 6, sy + slot_size - 21, lvl_w + 4, 13, {12, 12, 18, 220})
		rl.DrawText(lvl_str, sx + slot_size - lvl_w - 4, sy + slot_size - 20, 12, rl.RAYWHITE)

		// Slot key number at top-left
		key_str := fmt.ctprintf("%d", i + 1)
		rl.DrawText(key_str, sx + 4, sy + 3, 12, {170, 175, 195, 255})
	}
}

draw_centered_text :: proc(text: cstring, y: i32, font_size: i32, color: rl.Color) {
	w := rl.MeasureText(text, font_size)
	rl.DrawText(text, (structs.WINDOW_WIDTH - w) / 2, y, font_size, color)
}

render_menu :: proc(state: ^structs.Game_State) {
	// Subtle background grid on main menu
	render_world_grid({f32(structs.WINDOW_WIDTH) * 0.5, f32(structs.WINDOW_HEIGHT) * 0.5})

	draw_centered_text("PROJECT DESCENT", 180, 56, {80, 235, 145, 255})
	draw_centered_text("Action Roguelike Prototype", 250, 22, {160, 170, 190, 255})

	options := [2]cstring{"START RUN", "QUIT"}
	for i in 0 ..< len(options) {
		selected := state.menu_selection == i
		label := fmt.ctprintf("> %s <", options[i]) if selected else options[i]
		color := rl.Color{255, 230, 110, 255} if selected else rl.RAYWHITE
		draw_centered_text(label, 360 + i32(i) * 48, 28, color)
	}

	draw_centered_text(
		"W/S or Arrow Keys = Select | ENTER / SPACE = Confirm",
		structs.WINDOW_HEIGHT - 48,
		18,
		{130, 135, 150, 255},
	)
}

render_pause :: proc(state: ^structs.Game_State) {
	// Dark translucent backdrop over paused world
	rl.DrawRectangle(0, 0, structs.WINDOW_WIDTH, structs.WINDOW_HEIGHT, {8, 8, 12, 185})

	draw_centered_text("PAUSED", 200, 48, rl.RAYWHITE)

	options := [3]cstring{"RESUME", "RESTART RUN", "MAIN MENU"}
	for i in 0 ..< len(options) {
		selected := state.pause_selection == i
		label := fmt.ctprintf("> %s <", options[i]) if selected else options[i]
		color := rl.Color{80, 235, 145, 255} if selected else {200, 205, 215, 255}
		draw_centered_text(label, 310 + i32(i) * 44, 26, color)
	}

	draw_centered_text(
		"W/S or Arrow Keys = Select | ENTER / SPACE = Confirm | ESC / P = Resume",
		structs.WINDOW_HEIGHT - 48,
		18,
		{150, 155, 170, 255},
	)
}
