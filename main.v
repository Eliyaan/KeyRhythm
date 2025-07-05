import gg
import abc

struct App {
mut:
	ctx &gg.Context = unsafe { nil }
	staff abc.Staff
}

fn main() {
/*
	midi_device := "/dev/midi1"
	mut packet := [3]u8{}
	mut file := os.open(midi_device) or {panic(err)}
	for {
		packet[0] = file.read_u8() or {panic(err)}
		packet[1] = file.read_u8() or {panic(err)}
		packet[2] = file.read_u8() or {panic(err)}
		println(packet)
	}
*/

	mut app := &App{}
	app.staff = abc.create_staff('tunes/notes.abc')!
	app.ctx = gg.new_context(
		create_window: true
		user_data: app
		frame_fn: on_frame
		event_fn: on_event
		sample_count: 4
		bg_color: gg.Color{255, 255, 255, 255}
	)
	
	app.ctx.run()
}

fn on_frame(mut app App) {
	app.ctx.begin()
	app.staff.draw(app.ctx, 50.0, 50.0, 800.0)
	app.ctx.end()
}

fn on_event(e &gg.Event, mut app App){
        if e.char_code != 0 {
		//println(e.char_code)
        }
	match e.typ {
		.mouse_down{
		//	app.square_size += 1
		}
		.key_down {
			match e.key_code {
				.escape {app.ctx.quit()}
				else {}
			}
		}
		else {}
	}
}
