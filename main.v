import gg
import gx
import tsf
import time
import sokol.audio
import os
import abc

const anim_length = time.millisecond * 50
const staff_files_x = 80
const c_staff_files_x_end = 150
const staff_files_y_off = 80
const staff_files_y_fact = 55
const c_song_rect_color = gg.Color{255, 80, 141, 255}
const font_size = 32
const half_font_size = font_size / 2

fn audio_callback(soundbuffer &f32, num_frames int, num_channels int, mut app App) {
	// eprintln('num_channels: ${num_channels} | num_frames: ${num_frames}')
	app.tiny_sound_font.render_float(soundbuffer, num_frames, false)
}

enum State {
	game
	play
	staff_select
	quit
}

struct App {
mut:
	ctx             &gg.Context = unsafe { nil }
	txtcfg          gx.TextCfg
	tiny_sound_font &tsf.Tsf
	midi            os.File // midi file
	pstaff          abc.ProcessedStaff
	state           State
	hits_x          []f32
	hits_y          []f32
	// moving bar
	line_nb  int
	progress f32 // x -> x_end on the current line
	speed    f32 // add to the progress
	// song select menu
	staff_files   []string
	current_song  int       // index in staff_files
	c_song_anim   f32       // 0.0 -> 1.0
	c_song_amin_t time.Time // when the animation started
}

fn main() {
	mut app := &App{
		tiny_sound_font: tsf.Tsf.load_filename('School_Piano_2024.sf2')
		// tiny_sound_font: tsf.Tsf.load_memory(&minimal_soundfont, minimal_soundfont.len)
	}
	if isnil(app.tiny_sound_font) {
		panic('Could not load soundfont')
	}
	// Set the rendering output mode to 44.1khz and -10 decibel gain
	app.tiny_sound_font.set_output(.stereo_interleaved, 44100, -3)

	audio.setup(
		stream_userdata_cb: audio_callback
		num_channels:       2
		user_data:          app
	)

	app.init_staff_select()
	app.ctx = gg.new_context(
		create_window: true
		fullscreen:    true
		user_data:     app
		frame_fn:      on_frame
		event_fn:      on_event
		sample_count:  4
		bg_color:      gg.Color{255, 255, 255, 255}
		font_path:     '0xProtoNerdFontMono-Regular.ttf'
	)

	app.ctx.set_text_style('0xProtoNerdFontMono', '0xProtoNerdFontMono-Regular.ttf', font_size,
		gx.black, int(gx.HorizontalAlign.left), int(gx.VerticalAlign.middle))
	app.txtcfg = gx.TextCfg{gx.black, font_size, .left, .middle, 2000, '', false, false, false}
	app.ctx.run()
	app.state = .quit
}

fn (mut app App) record_keys() {
	midi_device := '/dev/midi1'
	mut packet := [3]u8{}
	app.midi = os.open(midi_device) or {
		println(err)
		return
	}
	defer { app.midi.close() }
	for app.state == .play {
		if os.fd_is_pending(app.midi.fd) {
			packet[0] = app.midi.read_u8() or { panic(err) }
			packet[1] = app.midi.read_u8() or { panic(err) }
			packet[2] = app.midi.read_u8() or { panic(err) }
			if app.state == .play {
				if packet[0] == 154 {
					app.hits_x << app.progress
					current_line := app.pstaff.plines[app.line_nb]
					note_y := current_line.y + current_line.px_height - f32(int(abc.midi_to_pitch[packet[1]])) / f32(abc.nb_pitches) * current_line.px_height
					app.hits_y << note_y
				}
			}
			if packet[0] == 154 {
				app.tiny_sound_font.note_on(0, packet[1], 1)
			} else if packet[0] == 138 {
				app.tiny_sound_font.note_off(0, packet[1])
			}
		} else {
			time.sleep(time.millisecond * 5)
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
		if app.c_song_anim < 1.0 {
			dt := time.now() - app.c_song_amin_t
			if dt >= anim_length {
				app.c_song_anim = 1.0
			} else {
				app.c_song_anim = f32(dt) / f32(anim_length)
			}
		}
		for i, f in app.staff_files {
			if i == app.current_song {
				x := int(staff_files_x + (c_staff_files_x_end - staff_files_x) * app.c_song_anim)
				y := i * staff_files_y_fact + staff_files_y_off
				x_left_margin := 10
				h := staff_files_y_fact
				w := (f.len + 1) * half_font_size + x_left_margin
				app.ctx.draw_rect_filled(x - x_left_margin, y, w, h, c_song_rect_color)
				app.ctx.draw_text(x, y + staff_files_y_fact / 2, f, app.txtcfg)
			} else {
				x := staff_files_x
				y := i * staff_files_y_fact + staff_files_y_off + staff_files_y_fact / 4
				app.ctx.draw_text(x, y, f, app.txtcfg)
			}
		}
	}
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App) {
	if e.char_code != 0 {
		// println(e.char_code)
	}
	match e.typ {
		.mouse_move {
			if app.state == .staff_select {
				for i, _ in app.staff_files {
					if e.mouse_x >= staff_files_x
						&& e.mouse_y < (i + 1) * staff_files_y_fact + staff_files_y_off {
						if app.current_song == i {
							break
						}
						app.current_song = i
						app.c_song_anim = 0.0
						app.c_song_amin_t = time.now()
						break
					}
				}
			}
		}
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
						println('Processed staff')
						spawn app.record_keys()
						app.line_nb = 0
						current_line := app.pstaff.plines[app.line_nb] or {
							println('Unsupported abc file')
							app.init_staff_select()
							return
						}
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
		app.ctx.draw_circle_empty(h_x, app.hits_y[i] or { continue }, abc.radius, gg.Color{200, 0, 0, 255})
	}
}

fn (mut app App) init_staff_select() {
	app.state = .staff_select
	app.staff_files = os.ls('tunes') or { [] }
}
