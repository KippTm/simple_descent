package render

import "core:fmt"
import "core:math"
import rl "vendor:raylib"
import "../abilities"
import "../states"
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
	case .Loadout_Select:
		render_loadout_select(state)
	case .Playing:
		render_world(state, camera)
		render_hud(state)
	case .Paused:
		render_world(state, camera)
		render_hud(state)
		render_pause(state)
	case .Upgrade_Select:
		render_world(state, camera)
		render_hud(state)
		render_upgrade_select(state)
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
		vel := state.projectiles[i].vel
		switch state.projectiles[i].kind {
		case .Bolt:
			rl.DrawCircleV({pos.x, pos.y}, rad, rl.RAYWHITE)
		case .Returning_Knife:
			angle := math.atan2(vel.y, vel.x)
			dir := [2]f32{math.cos(angle), math.sin(angle)}
			tail := pos - dir * 9.0
			tip := pos + dir * 9.0
			rl.DrawLineEx({tail.x, tail.y}, {tip.x, tip.y}, 3.5, {235, 240, 255, 255})
			rl.DrawCircleV({tip.x, tip.y}, 2.5, {255, 195, 95, 255})
		case .Mana_Orb:
			aura := state.projectiles[i].aura_radius
			rl.DrawCircleV({pos.x, pos.y}, aura, {110, 170, 255, 32})
			rl.DrawCircleLinesV({pos.x, pos.y}, aura, {130, 195, 255, 140})
			rl.DrawCircleV({pos.x, pos.y}, rad, {150, 220, 255, 255})
			rl.DrawCircleV({pos.x, pos.y}, rad * 0.5, rl.RAYWHITE)
		}
	}
}

render_player :: proc(player: ^structs.Player) {
	p_pos := player.pos
	p_rad := player.radius

	// Render Sweep arc & blade during melee swing
	if player.melee_swing_timer > 0 {
		progress := 1.0 - (player.melee_swing_timer / structs.MELEE_SWING_VISUAL_DUR)
		center_deg := math.atan2(player.melee_swing_dir.y, player.melee_swing_dir.x) * (180.0 / math.PI)
		half_deg := player.melee_swing_half_angle * (180.0 / math.PI)
		start_deg := center_deg - half_deg
		end_deg := center_deg + half_deg
		swing_range := player.melee_swing_range

		rl.DrawCircleSector(
			{p_pos.x, p_pos.y},
			swing_range,
			start_deg,
			end_deg,
			16,
			{255, 200, 110, 75},
		)
		rl.DrawCircleSectorLines(
			{p_pos.x, p_pos.y},
			swing_range,
			start_deg,
			end_deg,
			16,
			{255, 225, 150, 180},
		)

		blade_deg := start_deg + (end_deg - start_deg) * progress
		blade_rad := blade_deg * (math.PI / 180.0)
		tip := [2]f32{
			p_pos.x + math.cos(blade_rad) * swing_range,
			p_pos.y + math.sin(blade_rad) * swing_range,
		}
		hilt := [2]f32{
			p_pos.x + math.cos(blade_rad) * (p_rad + 2.0),
			p_pos.y + math.sin(blade_rad) * (p_rad + 2.0),
		}
		rl.DrawLineEx({hilt.x, hilt.y}, {tip.x, tip.y}, 4.0, {245, 245, 255, 255})
	}

	// Render Stab deep thrust visual
	if player.stab_visual_timer > 0 {
		alpha := u8(clamp((player.stab_visual_timer / structs.STAB_VISUAL_DUR) * 255.0, 0.0, 255.0))
		start := p_pos + player.stab_dir * (p_rad + 2.0)
		tip := p_pos + player.stab_dir * player.stab_range
		rl.DrawLineEx({start.x, start.y}, {tip.x, tip.y}, 7.0, {220, 235, 255, alpha / 2})
		rl.DrawLineEx({start.x, start.y}, {tip.x, tip.y}, 3.0, {255, 255, 255, alpha})
		rl.DrawCircleV({tip.x, tip.y}, 4.0, {255, 245, 200, alpha})
	}

	// Render Lunge frontal strike visual
	if player.lunge_timer > 0 {
		start := p_pos + player.lunge_dir * (p_rad + 2.0)
		tip := p_pos + player.lunge_dir * player.lunge_range
		rl.DrawLineEx({start.x, start.y}, {tip.x, tip.y}, 10.0, {255, 175, 95, 120})
		rl.DrawCircleV({tip.x, tip.y}, 7.0, {255, 220, 145, 200})
	}

	// Render Mana Nova expanding 360-degree ring
	if player.nova_visual_timer > 0 {
		progress := 1.0 - (player.nova_visual_timer / structs.NOVA_VISUAL_DUR)
		alpha := u8(clamp((1.0 - progress) * 230.0, 0.0, 230.0))
		cur_rad := player.nova_visual_radius * (0.25 + 0.75 * progress)
		rl.DrawCircleV({player.nova_visual_pos.x, player.nova_visual_pos.y}, cur_rad, {115, 180, 255, alpha / 4})
		rl.DrawCircleLinesV({player.nova_visual_pos.x, player.nova_visual_pos.y}, cur_rad, {160, 220, 255, alpha})
		rl.DrawCircleLinesV({player.nova_visual_pos.x, player.nova_visual_pos.y}, max(cur_rad - 3.0, 1.0), {235, 245, 255, alpha})
	}

	// Render Mend healing aura
	if player.mend_timer > 0 {
		rl.DrawCircleLinesV({p_pos.x, p_pos.y}, p_rad + 7.0, {95, 245, 145, 180})
	}

	// Render Haste speed aura
	if player.haste_timer > 0 {
		rl.DrawCircleLinesV({p_pos.x, p_pos.y}, p_rad + 5.0, {255, 230, 95, 190})
	}

	// Render Mana Shield bubble
	if player.shield_timer > 0 && player.shield_hp > 0 {
		rl.DrawCircleV({p_pos.x, p_pos.y}, p_rad + 9.0, {75, 185, 255, 65})
		rl.DrawCircleLinesV({p_pos.x, p_pos.y}, p_rad + 9.0, {120, 220, 255, 230})
	}

	// Render Reflect parry ring
	if player.reflect_timer > 0 {
		rl.DrawCircleV({p_pos.x, p_pos.y}, p_rad + 12.0, {255, 245, 170, 55})
		rl.DrawCircleLinesV({p_pos.x, p_pos.y}, p_rad + 12.0, {255, 245, 170, 255})
		rl.DrawCircleLinesV({p_pos.x, p_pos.y}, p_rad + 14.0, {255, 255, 255, 220})
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

	// Optional Mana Shield indicator bar right beneath HP bar when active
	if state.player.shield_timer > 0 && state.player.shield_hp > 0 {
		sh_y := hp_bar_y + hp_bar_h + 6
		sh_ratio := clamp(state.player.shield_hp / max(state.player.shield_max_hp, 1.0), 0.0, 1.0)
		rl.DrawRectangle(hp_bar_x - 1, sh_y - 1, hp_bar_w + 2, 10, {12, 12, 18, 220})
		rl.DrawRectangle(hp_bar_x, sh_y, i32(f32(hp_bar_w) * sh_ratio), 8, {90, 200, 255, 255})
	}

	// Bottom Skill Bar Menu (Icons + Level + XP progress + Spec badge)
	render_skill_bar(&state.player)
}

category_color :: proc(cat: structs.Ability_Category) -> rl.Color {
	switch cat {
	case .None:
		return {130, 135, 155, 255}
	case .Physical:
		return {235, 145, 75, 255}
	case .Magical:
		return {100, 185, 255, 255}
	case .Utility:
		return {115, 230, 155, 255}
	}
	return {130, 135, 155, 255}
}

category_label :: proc(cat: structs.Ability_Category) -> cstring {
	switch cat {
	case .None:
		return ""
	case .Physical:
		return "PHYSICAL"
	case .Magical:
		return "MAGICAL"
	case .Utility:
		return "UTILITY"
	}
	return ""
}

spec_accent_color :: proc(spec: structs.Spec_Type) -> rl.Color {
	switch spec {
	case .None:
		return {145, 155, 175, 255}
	case .Blood:
		return {225, 55, 75, 255}
	case .Ice:
		return {85, 195, 255, 255}
	case .Fire:
		return {255, 140, 45, 255}
	case .Storm:
		return {195, 120, 255, 255}
	}
	return {145, 155, 175, 255}
}

draw_ability_icon :: proc(id: structs.Ability_Id, cx, cy: i32, accent: rl.Color) {
	switch id {
	case .None:
	case .Sweep:
		// Diagonal Broadsword icon
		rl.DrawLineEx({f32(cx - 10), f32(cy + 10)}, {f32(cx + 11), f32(cy - 11)}, 4.0, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 11), f32(cy + 3)}, {f32(cx - 3), f32(cy + 11)}, 3.0, accent)
		rl.DrawCircle(cx - 12, cy + 12, 2.5, accent)
	case .Stab:
		// Sharp forward spear / lance thrust
		rl.DrawLineEx({f32(cx - 13), f32(cy + 4)}, {f32(cx + 10), f32(cy - 4)}, 3.0, rl.RAYWHITE)
		rl.DrawTriangle(
			{f32(cx + 14), f32(cy - 5)},
			{f32(cx + 4), f32(cy - 8)},
			{f32(cx + 6), f32(cy + 1)},
			accent,
		)
	case .Reflect:
		// Reflective parry arc & bounce arrow
		rl.DrawCircleLines(cx, cy, 11.0, accent)
		rl.DrawLineEx({f32(cx - 7), f32(cy + 5)}, {f32(cx), f32(cy - 2)}, 2.5, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx), f32(cy - 2)}, {f32(cx + 8), f32(cy - 8)}, 2.5, accent)
		rl.DrawCircle(cx + 8, cy - 8, 2.5, accent)
	case .Knife_Throw:
		// Returning curved dagger + arc trail
		rl.DrawLineEx({f32(cx - 10), f32(cy + 6)}, {f32(cx + 9), f32(cy - 7)}, 3.0, rl.RAYWHITE)
		rl.DrawCircleLines(cx, cy + 2, 11.0, {accent.r, accent.g, accent.b, 140})
		rl.DrawCircle(cx + 9, cy - 7, 2.5, accent)
	case .Lunge:
		// Short burst arrow with impact spark
		rl.DrawLineEx({f32(cx - 12), f32(cy)}, {f32(cx + 6), f32(cy)}, 3.5, rl.RAYWHITE)
		rl.DrawTriangle(
			{f32(cx + 13), f32(cy)},
			{f32(cx + 3), f32(cy - 7)},
			{f32(cx + 3), f32(cy + 7)},
			accent,
		)
	case .Mana_Bolt:
		// Magic bolt / orb with trail
		rl.DrawLineEx({f32(cx - 11), f32(cy + 8)}, {f32(cx + 4), f32(cy - 4)}, 3.0, accent)
		rl.DrawCircle(cx + 6, cy - 6, 6.0, accent)
		rl.DrawCircle(cx + 6, cy - 6, 3.0, rl.RAYWHITE)
	case .Mana_Shield:
		// Translucent barrier dome
		rl.DrawCircle(cx, cy, 11.0, {accent.r, accent.g, accent.b, 85})
		rl.DrawCircleLines(cx, cy, 11.0, accent)
		rl.DrawCircleLines(cx, cy, 7.0, rl.RAYWHITE)
	case .Mana_Nova:
		// Expanding concentric blast rings
		rl.DrawCircleLines(cx, cy, 12.0, accent)
		rl.DrawCircleLines(cx, cy, 7.0, rl.RAYWHITE)
		rl.DrawCircle(cx, cy, 3.0, accent)
	case .Mana_Orb:
		// Three floating orbs in a triad
		rl.DrawCircle(cx, cy - 8, 4.0, accent)
		rl.DrawCircle(cx - 8, cy + 6, 4.0, accent)
		rl.DrawCircle(cx + 8, cy + 6, 4.0, accent)
		rl.DrawCircle(cx, cy - 8, 1.8, rl.RAYWHITE)
		rl.DrawCircle(cx - 8, cy + 6, 1.8, rl.RAYWHITE)
		rl.DrawCircle(cx + 8, cy + 6, 1.8, rl.RAYWHITE)
	case .Dash:
		// Dash triangle + speed trails
		rl.DrawTriangle(
			{f32(cx + 11), f32(cy)},
			{f32(cx - 3), f32(cy - 9)},
			{f32(cx - 3), f32(cy + 9)},
			accent,
		)
		rl.DrawLineEx({f32(cx - 12), f32(cy - 5)}, {f32(cx - 5), f32(cy - 5)}, 2.5, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 14), f32(cy)}, {f32(cx - 5), f32(cy)}, 2.5, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 12), f32(cy + 5)}, {f32(cx - 5), f32(cy + 5)}, 2.5, rl.RAYWHITE)
	case .Haste:
		// Double forward speed chevrons
		rl.DrawLineEx({f32(cx - 9), f32(cy - 9)}, {f32(cx - 1), f32(cy)}, 3.0, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx - 1), f32(cy)}, {f32(cx - 9), f32(cy + 9)}, 3.0, rl.RAYWHITE)
		rl.DrawLineEx({f32(cx + 1), f32(cy - 9)}, {f32(cx + 9), f32(cy)}, 3.0, accent)
		rl.DrawLineEx({f32(cx + 9), f32(cy)}, {f32(cx + 1), f32(cy + 9)}, 3.0, accent)
	case .Mend:
		// Healing cross
		rl.DrawRectangle(cx - 3, cy - 10, 6, 20, accent)
		rl.DrawRectangle(cx - 10, cy - 3, 20, 6, accent)
		rl.DrawRectangle(cx - 1, cy - 7, 2, 14, rl.RAYWHITE)
		rl.DrawRectangle(cx - 7, cy - 1, 14, 2, rl.RAYWHITE)
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
		def := abilities.ABILITY_DEFS[ability.id]
		sx := start_x + i32(i) * (slot_size + slot_gap)
		sy := bar_y
		accent := spec_accent_color(ability.spec_type) if ability.spec_type != .None else category_color(def.category)

		// Slot background
		rl.DrawRectangle(sx, sy, slot_size, slot_size, {24, 26, 36, 255})

		// Draw distinct ability vector icon in slot center
		draw_ability_icon(ability.id, sx + slot_size / 2, sy + slot_size / 2 - 4, accent)

		// XP progress bar at bottom of the slot
		xp_req := abilities.xp_for_next_level(ability.level)
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

		// Slightly gray cooldown overlay drawn ON TOP of the ability icon
		if ability.cooldown_time > 0 && ability.cooldown > 0 {
			cd_ratio := clamp(ability.cooldown / ability.cooldown_time, 0.0, 1.0)
			cd_h := i32(f32(slot_size) * cd_ratio)
			overlay_y := sy + (slot_size - cd_h)
			rl.DrawRectangle(sx, overlay_y, slot_size, cd_h, {130, 138, 155, 150})
			rl.DrawLine(sx, overlay_y, sx + slot_size, overlay_y, {210, 220, 235, 210})
		}

		// Slot border colored by specialization (or category while unspecialized)
		rl.DrawRectangleLines(sx, sy, slot_size, slot_size, accent)

		// Level badge at bottom-right
		lvl_str := fmt.ctprintf("Lv.%d", ability.level)
		lvl_w := rl.MeasureText(lvl_str, 12)
		rl.DrawRectangle(sx + slot_size - lvl_w - 6, sy + slot_size - 21, lvl_w + 4, 13, {12, 12, 18, 220})
		rl.DrawText(lvl_str, sx + slot_size - lvl_w - 4, sy + slot_size - 20, 12, rl.RAYWHITE)

		// Slot key number at top-left, current upgrade focus tag at top-right
		key_str := fmt.ctprintf("%d", i + 1)
		rl.DrawText(key_str, sx + 4, sy + 3, 12, {170, 175, 195, 255})

		focus_short := upgrade_focus_short(ability.upgrade_focus)
		fw := rl.MeasureText(focus_short, 10)
		rl.DrawText(focus_short, sx + slot_size - fw - 4, sy + 4, 10, accent)
	}
}

upgrade_focus_short :: proc(f: structs.Upgrade_Focus) -> cstring {
	switch f {
	case .Damage:
		return "DMG"
	case .Range:
		return "RNG"
	case .Duration:
		return "DUR"
	case .Projectiles:
		return "PRJ"
	}
	return ""
}

upgrade_focus_name :: proc(f: structs.Upgrade_Focus) -> cstring {
	switch f {
	case .Damage:
		return "Damage / Power"
	case .Range:
		return "Range / Speed"
	case .Duration:
		return "Duration"
	case .Projectiles:
		return "Projectiles"
	}
	return ""
}

upgrade_focus_desc :: proc(id: structs.Ability_Id, f: structs.Upgrade_Focus) -> cstring {
	switch f {
	case .Damage:
		if id == .Mana_Shield do return "+15% shield absorb HP"
		if id == .Reflect do return "+15% reflected damage"
		if id == .Mend do return "+15% heal per second"
		return "+15% ability damage"
	case .Range:
		if id == .Dash do return "+10% dash speed & reach"
		if id == .Lunge do return "+12% lunge distance & reach"
		if id == .Haste do return "+8% movement speed"
		if id == .Mana_Bolt do return "+15% range & +8% speed"
		if id == .Knife_Throw do return "+15% throw distance"
		if id == .Mana_Nova do return "+14% blast radius & force"
		if id == .Mana_Orb do return "+15% orb damage radius"
		return "+12% attack reach"
	case .Duration:
		if id == .Reflect do return "+0.04s parry window"
		if id == .Mana_Shield do return "+0.45s shield duration"
		if id == .Dash do return "+0.03s invulnerability"
		if id == .Haste do return "+0.50s haste duration"
		if id == .Mend do return "+0.75s heal duration"
		return "Longer effect duration"
	case .Projectiles:
		if id == .Mana_Orb do return "+1 extra mana orb"
		if id == .Knife_Throw do return "+1 extra returning knife"
		return "+1 extra projectile"
	}
	return ""
}

render_upgrade_select :: proc(state: ^structs.Game_State) {
	// Dark translucent backdrop over paused combat
	rl.DrawRectangle(0, 0, structs.WINDOW_WIDTH, structs.WINDOW_HEIGHT, {8, 8, 14, 195})

	slot := state.upgrade_select_slot
	if slot < 0 || slot >= state.player.ability_count do return

	ability := state.player.abilities[slot]
	def := abilities.ABILITY_DEFS[ability.id]
	accent := category_color(def.category)

	draw_centered_text(
		fmt.ctprintf("%s REACHED LEVEL %d!", def.name, ability.level),
		160,
		36,
		accent,
	)
	draw_centered_text(
		"Choose what future level-ups will improve:",
		212,
		20,
		{205, 212, 225, 255},
	)

	options, count := states.get_ability_focus_options(ability.id)
	for i in 0 ..< count {
		f := options[i]
		rect := states.upgrade_option_rect(i, count)
		is_cursor := state.upgrade_select_cursor == i
		is_current := ability.upgrade_focus == f

		bg := rl.Color{32, 38, 54, 250} if is_cursor else rl.Color{22, 24, 34, 240}
		border := rl.Color{255, 230, 110, 255} if is_cursor else (accent if is_current else rl.Color{70, 76, 98, 255})
		rl.DrawRectangleRec(rect, bg)
		rl.DrawRectangleLinesEx(rect, 3.0 if is_cursor else 1.5, border)

		rx := i32(rect.x)
		ry := i32(rect.y)
		rl.DrawText(fmt.ctprintf("[%d] %s", i + 1, upgrade_focus_name(f)), rx + 14, ry + 16, 18, rl.RAYWHITE)
		rl.DrawText(upgrade_focus_desc(ability.id, f), rx + 14, ry + 54, 14, {185, 195, 215, 255})
		rl.DrawText(fmt.ctprintf("Current Ranks: %d", ability.focus_ranks[f]), rx + 14, ry + 94, 13, accent)
	}

	draw_centered_text(
		"A/D or Arrows = Select | 1-4 / ENTER / Click = Confirm",
		structs.WINDOW_HEIGHT - 56,
		18,
		{150, 155, 175, 255},
	)
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

render_loadout_select :: proc(state: ^structs.Game_State) {
	render_world_grid({f32(structs.WINDOW_WIDTH) * 0.5, f32(structs.WINDOW_HEIGHT) * 0.5})

	draw_centered_text("CHOOSE YOUR STARTING 3 ABILITIES", 22, 32, {80, 235, 145, 255})
	draw_centered_text(
		fmt.ctprintf("Selected: %d / %d  (All abilities start unspecialized)", state.selected_loadout_count, structs.STARTING_ABILITY_COUNT),
		58,
		16,
		{165, 175, 195, 255},
	)

	// Top 3 Loadout Preview Slots
	slot_w: i32 = 240
	slot_h: i32 = 64
	slot_gap: i32 = 24
	slots_total_w := i32(structs.STARTING_ABILITY_COUNT) * slot_w + i32(structs.STARTING_ABILITY_COUNT - 1) * slot_gap
	slots_start_x := (structs.WINDOW_WIDTH - slots_total_w) / 2
	slots_y: i32 = 90

	for i in 0 ..< structs.STARTING_ABILITY_COUNT {
		sx := slots_start_x + i32(i) * (slot_w + slot_gap)
		id := state.selected_loadout[i] if i < state.selected_loadout_count else .None

		rl.DrawRectangle(sx, slots_y, slot_w, slot_h, {22, 24, 34, 240})
		if id != .None {
			def := abilities.ABILITY_DEFS[id]
			accent := category_color(def.category)
			rl.DrawRectangleLines(sx, slots_y, slot_w, slot_h, accent)
			draw_ability_icon(id, sx + 30, slots_y + slot_h / 2, accent)
			rl.DrawText(fmt.ctprintf("[%d] %s", i + 1, def.name), sx + 58, slots_y + 12, 18, rl.RAYWHITE)
			rl.DrawText(category_label(def.category), sx + 58, slots_y + 36, 12, accent)
		} else {
			rl.DrawRectangleLines(sx, slots_y, slot_w, slot_h, {70, 75, 95, 255})
			rl.DrawText(fmt.ctprintf("[%d] Empty Slot", i + 1), sx + 20, slots_y + 23, 17, {110, 115, 135, 255})
		}
	}

	// 3 Separate Category Columns: Physical | Magical | Utility
	for col in 0 ..< states.LOADOUT_COLS {
		cat := states.LOADOUT_COL_CATEGORIES[col]
		cat_col := category_color(cat)
		header := states.loadout_col_header_rect(col)
		hx := i32(header.x)
		hy := i32(header.y)
		hw := i32(header.width)
		hh := i32(header.height)

		// Column Header Bar
		rl.DrawRectangle(hx, hy, hw, hh, {24, 27, 38, 235})
		rl.DrawLineEx({header.x, header.y + header.height}, {header.x + header.width, header.y + header.height}, 2.0, cat_col)
		label := category_label(cat)
		lw := rl.MeasureText(label, 18)
		rl.DrawText(label, hx + (hw - lw) / 2, hy + 6, 18, cat_col)

		// Skills listed vertically below this column's header
		items, count := states.loadout_col_items(col)
		for row in 0 ..< count {
			idx := items[row]
			id := abilities.SELECTABLE_ABILITIES[idx]
			def := abilities.ABILITY_DEFS[id]
			rect := states.loadout_card_rect_for_col_row(col, row)
			is_cursor := state.loadout_cursor == idx

			selected_slot := -1
			for s in 0 ..< state.selected_loadout_count {
				if state.selected_loadout[s] == id {
					selected_slot = s
					break
				}
			}

			bg := rl.Color{32, 38, 52, 245} if selected_slot >= 0 else rl.Color{22, 24, 34, 235}
			rl.DrawRectangleRec(rect, bg)

			border := rl.Color{255, 230, 110, 255} if is_cursor else (cat_col if selected_slot >= 0 else rl.Color{58, 64, 82, 255})
			border_thick: f32 = 2.5 if is_cursor else (2.0 if selected_slot >= 0 else 1.0)
			rl.DrawRectangleLinesEx(rect, border_thick, border)

			rx := i32(rect.x)
			ry := i32(rect.y)
			draw_ability_icon(id, rx + 26, ry + i32(rect.height) / 2, cat_col)

			rl.DrawText(def.name, rx + 52, ry + 8, 17, rl.RAYWHITE)
			rl.DrawText(fmt.ctprintf("CD %.2fs", def.cooldown_time), rx + 52, ry + 27, 11, cat_col)
			rl.DrawText(def.short_desc, rx + 52, ry + 42, 11, {180, 188, 206, 255})

			if selected_slot >= 0 {
				badge := fmt.ctprintf("SLOT %d", selected_slot + 1)
				bw := rl.MeasureText(badge, 11)
				bx := rx + i32(rect.width) - bw - 12
				by := ry + 8
				rl.DrawRectangle(bx - 4, by - 2, bw + 8, 15, cat_col)
				rl.DrawText(badge, bx, by, 11, {15, 16, 22, 255})
			}
		}
	}

	// Start Run Button
	ready := state.selected_loadout_count == structs.STARTING_ABILITY_COUNT
	btn := states.loadout_start_btn_rect()
	btn_bg := rl.Color{55, 185, 115, 255} if ready else rl.Color{45, 48, 60, 255}
	btn_border := rl.Color{130, 255, 180, 255} if ready else rl.Color{80, 85, 100, 255}
	btn_text_col := rl.Color{12, 18, 16, 255} if ready else rl.Color{130, 135, 150, 255}

	rl.DrawRectangleRec(btn, btn_bg)
	rl.DrawRectangleLinesEx(btn, 2.0, btn_border)
	btn_label: cstring = "START RUN" if ready else "PICK 3 ABILITIES"
	btn_tw := rl.MeasureText(btn_label, 22)
	rl.DrawText(
		btn_label,
		i32(btn.x) + (i32(btn.width) - btn_tw) / 2,
		i32(btn.y) + 12,
		22,
		btn_text_col,
	)

	draw_centered_text(
		"WASD / Arrows = Move | SPACE / Click = Toggle | BACKSPACE = Remove | ENTER = Start | ESC = Back",
		structs.WINDOW_HEIGHT - 36,
		16,
		{140, 145, 165, 255},
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
