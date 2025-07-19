import gg
import tsf
import time
import sokol.audio
import os
import abc

const staff_files_x = 50
const staff_files_y_off = 50
const staff_files_y_fact = 30
const minimal_soundfont = [u8(`R`), `I`, `F`, `F`, 220, 1, 0, 0, `s`, `f`, `b`, `k`, `L`, `I`,
	`S`, `T`, 88, 1, 0, 0, `p`, `d`, `t`, `a`, `p`, `h`, `d`, `r`, 76, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 255, 0, 255, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, `p`, `b`, `a`, `g`, 8, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, `p`,
	`m`, `o`, `d`, 10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, `p`, `g`, `e`, `n`, 8, 0, 0, 0, 41,
	0, 0, 0, 0, 0, 0, 0, `i`, `n`, `s`, `t`, 44, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0,
	`i`, `b`, `a`, `g`, 8, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, `i`, `m`, `o`, `d`, 10, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, `i`, `g`, `e`, `n`, 12, 0, 0, 0, 54, 0, 1, 0, 53, 0, 0, 0, 0, 0,
	0, 0, `s`, `h`, `d`, `r`, 92, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 50, 0, 0, 0, 0, 0, 0, 0, 49, 0, 0, 0, 34, 86, 0, 0, 60, 0, 0, 0, 1, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
	0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, `L`, `I`, `S`, `T`, 112, 0, 0, 0, `s`, `d`, `t`,
	`a`, `s`, `m`, `p`, `l`, 100, 0, 0, 0, 86, 0, 119, 3, 31, 7, 147, 10, 43, 14, 169, 17, 58,
	21, 189, 24, 73, 28, 204, 31, 73, 35, 249, 38, 46, 42, 71, 46, 250, 48, 150, 53, 242, 55, 126,
	60, 151, 63, 108, 66, 126, 72, 207, 70, 86, 83, 100, 72, 74, 100, 163, 39, 241, 163, 59, 175,
	59, 179, 9, 179, 134, 187, 6, 186, 2, 194, 5, 194, 15, 200, 6, 202, 96, 206, 159, 209, 35,
	213, 213, 216, 45, 220, 221, 223, 76, 227, 221, 230, 91, 234, 242, 237, 105, 241, 8, 245, 118,
	248, 32, 252]!

fn audio_callback(soundbuffer &f32, num_frames int, num_channels int, mut app App) {
	// eprintln('num_channels: ${num_channels} | num_frames: ${num_frames}')
	app.tiny_sound_font.render_float(soundbuffer, num_frames, false)
}

enum State {
	game
	play
	staff_select
}

struct App {
mut:
	ctx             &gg.Context = unsafe { nil }
	tiny_sound_font &tsf.Tsf
	pstaff          abc.ProcessedStaff
	staff_files     []string
	state           State
	hits_x          []f32
	hits_y          []f32
	// moving bar
	line_nb  int
	progress f32 // x -> x_end on the current line
	speed    f32 // add to the progress
}

fn main() {
	mut app := &App{
		tiny_sound_font: tsf.Tsf.load_memory(&minimal_soundfont, minimal_soundfont.len)
	}
	if isnil(app.tiny_sound_font) {
		panic('Could not load soundfont')
	}
	// Set the rendering output mode to 44.1khz and -10 decibel gain
	app.tiny_sound_font.set_output(.stereo_interleaved, 44100, -10)

	// Start two notes before starting the audio playback
	app.tiny_sound_font.note_on(0, 48, 1) // C2
	app.tiny_sound_font.note_on(0, 52, 1) // E2

	audio.setup(
		stream_userdata_cb: audio_callback
		num_channels:       2
		user_data:          app
	)

	time.sleep(1000 * time.millisecond)
	app.tiny_sound_font.note_off(0, 52) // E2
	time.sleep(1000 * time.millisecond)
	app.tiny_sound_font.note_off(0, 48) // C2

	app.init_staff_select()
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
	midi_device := '/dev/midi1'
	mut packet := [3]u8{}
	mut file := os.open(midi_device) or { panic(err) }
	defer { file.close() }
	for app.state == .play {
		packet[0] = file.read_u8() or { panic(err) }
		packet[1] = file.read_u8() or { panic(err) }
		packet[2] = file.read_u8() or { panic(err) }
		if app.state == .play {
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
	if app.state == .play {
		app.progress += app.speed
		if app.progress > app.pstaff.plines[app.line_nb].x_end {
			app.line_nb += 1
			if app.line_nb >= app.pstaff.plines.len {
				app.state = .game
			} else {
				c_l := app.pstaff.plines[app.line_nb]
				app.progress = c_l.x + c_l.treble_x_size + c_l.meter_x_size
			}
		}
	}
	app.ctx.begin()
	if app.state == .play {
		app.pstaff.draw(app.ctx)
		current_line := app.pstaff.plines[app.line_nb]
		app.ctx.draw_line(app.progress, current_line.y, app.progress, current_line.y +
			current_line.px_height, gg.Color{100, 0, 0, 255})
		app.draw_hits()
	} else if app.state == .game {
		app.pstaff.draw(app.ctx)
		app.draw_hits()
	} else if app.state == .staff_select {
		for i, f in app.staff_files {
			app.ctx.draw_text_def(staff_files_x, i * staff_files_y_fact + staff_files_y_off,
				f)
		}
	}
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	if e.char_code != 0 {
		// println(e.char_code)
	}
	match e.typ {
		.mouse_down {
			if app.state == .staff_select {
				for i, f in app.staff_files {
					if e.mouse_x >= staff_files_x
						&& e.mouse_y < (i + 1) * staff_files_y_fact + staff_files_y_off {
						app.hits_x = []
						app.hits_y = []
						app.state = .play
						staff := abc.create_staff('tunes/${f}') or {
							println(err)
							app.init_staff_select()
							return
						}
						app.pstaff = abc.process(staff, 50.0, 50.0, 800.0)
						spawn app.record_keys()
						app.line_nb = 0
						current_line := app.pstaff.plines[app.line_nb]
						app.progress = current_line.x
						app.speed = 1.0
						break
					}
				}
			}
		}
		.key_down {
			match e.key_code {
				.escape {
					app.ctx.quit()
				}
				.enter {
					if app.state == .game {
						app.init_staff_select()
					}
				}
				else {}
			}
		}
		else {}
	}
}

fn (mut app App) draw_hits() {
	for i, h_x in app.hits_x {
		app.ctx.draw_circle_empty(h_x, app.hits_y[i], abc.radius, gg.Color{200, 0, 0, 255})
	}
}

fn (mut app App) init_staff_select() {
	app.state = .staff_select
	app.staff_files = os.ls('tunes') or { [] }
}
