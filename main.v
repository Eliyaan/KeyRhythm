import gg
import abc

struct App {
mut:
	ctx &gg.Context = unsafe { nil }
}

fn main() {
	println(abc.create_staff('tunes/beams.abc')!)
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
	app.ctx = gg.new_context(
		create_window: true
		user_data: app
		frame_fn: on_frame
		event_fn: on_event
		sample_count: 2
	)
	
	app.ctx.run()
}

fn on_frame(mut app App) {
	app.ctx.begin()

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
