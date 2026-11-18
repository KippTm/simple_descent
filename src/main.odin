package descent

import rl "vendor:raylib"
import "render"
import "states"
import "structs"

// -----------------------------------------------------------------------------
// Entry Point
// -----------------------------------------------------------------------------

main :: proc() {
	rl.InitWindow(structs.WINDOW_WIDTH, structs.WINDOW_HEIGHT, "Project Descent")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	// Allocate Game_State on the heap so the large fixed pools don't overflow the stack
	state := new(structs.Game_State)
	defer free(state)

	states.init_game(state)

	for !rl.WindowShouldClose() {
		dt := min(rl.GetFrameTime(), 0.05)

		camera := rl.Camera2D {
			target = {state.player.pos.x, state.player.pos.y},
			offset = {f32(structs.WINDOW_WIDTH) * 0.5, f32(structs.WINDOW_HEIGHT) * 0.5},
			zoom   = 1.0,
		}

		states.update_game(state, dt, camera)
		render.render_game(state, camera)

		// Reset temporary allocator at the end of every frame
		free_all(context.temp_allocator)
	}
}
