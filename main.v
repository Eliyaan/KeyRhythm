import gg
import os
import abc

struct App {
mut:
	ctx    &gg.Context = unsafe { nil }
	pstaff abc.ProcessedStaff
	play bool // is the game playing
	hits_x []f32 
	hits_y []f32 
	// moving bar
	line_nb int
	progress f32 // x -> x_end on the current line
	speed f32 // add to the progress
}

fn main() {
	mut app := &App{}
	app.play = true
	spawn app.record_keys()
	staff := abc.create_staff('tunes/notes.abc')!
	app.pstaff = abc.process(staff, 50.0, 50.0, 800.0)
	app.line_nb = 0
	current_line := app.pstaff.plines[app.line_nb]
	app.progress = current_line.x
	app.speed = 1.0
	app.ctx = gg.new_context(
		create_window: true
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  4
		bg_color:      gg.Color{255, 255, 255, 255}
	)

	app.ctx.run()
}

fn (mut app App) record_keys() {
	midi_device := "/dev/midi1"
	mut packet := [3]u8{}
	mut file := os.open(midi_device) or {panic(err)}
	defer { file.close() }
	for app.play {
		packet[0] = file.read_u8() or {panic(err)}
		packet[1] = file.read_u8() or {panic(err)}
		packet[2] = file.read_u8() or {panic(err)}
		if app.play {
			if packet[0] == 154 {
				app.hits_x << app.progress
				current_line := app.pstaff.plines[app.line_nb]
				note_y := current_line.y + current_line.px_height - f32(int(abc.midi_to_pitch[packet[1]])) / f32(abc.nb_pitches) * current_line.px_height
				app.hits_y << note_y
			}
			println(packet)
		}
	}
}

fn on_frame(mut app App) {
	if app.play {
		app.progress += app.speed
		if app.progress > app.pstaff.plines[app.line_nb].x_end {
			app.line_nb += 1
			if app.line_nb >= app.pstaff.plines.len {
				app.play = false
			} else {
				app.progress = app.pstaff.plines[app.line_nb].x
			}
		}
	}
	app.ctx.begin()
	app.pstaff.draw(app.ctx)
	if app.play {
		current_line := app.pstaff.plines[app.line_nb]
		app.ctx.draw_line(app.progress, current_line.y, app.progress, current_line.y + current_line.px_height, gg.Color{100, 0, 0, 255})
	}
	for i, h_x in app.hits_x {
		app.ctx.draw_circle_empty(h_x, app.hits_y[i], abc.radius, gg.Color{200, 0, 0, 255})
	}
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	if e.char_code != 0 {
		// println(e.char_code)
	}
	match e.typ {
		.mouse_down {
			//	app.square_size += 1
		}
		.key_down {
			match e.key_code {
				.escape { app.ctx.quit() }
				else {}
			}
		}
		else {}
	}
}
