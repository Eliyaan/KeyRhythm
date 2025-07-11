module abc

import math
import os
import gg
import gx

enum Pitches {
	_cc
	_dd
	_ee
	_ff
	_gg
	_aa
	_bb
	_c
	_d
	_e
	_f
	_g
	_a
	_b
	c
	d
	e
	f
	g
	a
	b
	cc
	dd
	ee
	ff
	gg
	aa
	bb
}

const nb_pitches = 28
const staff_lines = [
	Pitches._e,
	._g,
	._b,
	.d,
	.f,
]!

enum Lengths {
	thirtysecond // demi-semi-quaver
	sixteenth    // semi-quavers
	eighth       // quavers
	quarter      // crochet
	half         // minim
	whole        // semibreve
	doublewhole  // breve
}

struct Note {
mut:
	pitch  Pitches
	factor int = 1 // relative to the length of the group
	divide bool // if the factor divides or multiplies
}

enum Bars {
	single
	double
}

struct Beam {
mut:
	notes []Note
}

struct Group {
mut:
	length f32 = 1.0 / 8.0
	//	left_bar  Bars
	right_bar Bars
	beams     []Beam
	new_line  bool
	meter     string
}

pub struct Staff {
mut:
	title string
	//	meter     string
	key       string
	composer  string
	groups    []Group
	px_height f32 = 100.0
}

const radius = f32(4)
const black = gg.Color{0, 0, 0, 255}

fn (n Note) draw(ctx gg.Context, x f32, y f32, x_end f32, staff_heigth f32, g_length f32) (f32, f32, int) {
	px_whole_length := f32(150)
	true_factor := if n.divide {
		g_length / f32(n.factor)
	} else {
		g_length * f32(n.factor)
	}
	n_length := px_whole_length * true_factor
	note_y := y + staff_heigth - f32(int(n.pitch)) / f32(nb_pitches) * staff_heigth

	factor_log2 := math.log2(true_factor * 2)
	rounded_log := math.round(factor_log2)
	if rounded_log != factor_log2 {
		// for notes with dots after
		normalized_len := f32(n.factor) / f32(math.pow(2.0, int(math.log2(f64(n.factor))))) // 1.5 or 1.75
		if normalized_len >= 1.5 {
			ctx.draw_circle_filled(x + 2 * radius, note_y, 2, black)
		}
		if normalized_len == 1.75 {
			ctx.draw_circle_filled(x + 4 * radius, note_y, 2, black)
		}
	}
	mut nb_tails := -int(math.ceil(factor_log2))
	if true_factor < 1.0 && nb_tails <= 0 {
		nb_tails = 1
	}

	if true_factor < 0.5 {
		ctx.draw_circle_filled(x, note_y, radius, black)
	} else {
		if true_factor >= 2.0 {
			ctx.draw_square_empty(x - radius, note_y - radius, 2 * radius, black)
		} else {
			ctx.draw_circle_empty(x, note_y, radius, black)
		}
	}

	next_x := x + n_length
	return next_x, note_y, nb_tails
}

fn (b Beam) draw(ctx gg.Context, x f32, y f32, x_end f32, staff_heigth f32, g_length f32) f32 {
	mut next_x := x
	mut note_y := y
	mut nb_tails := 0
	mut old_x := x

	tail_size := staff_heigth / f32(nb_pitches) * 7
	y_middle := y + staff_heigth / f32(nb_pitches) * 15
	y_top := y + staff_heigth / f32(nb_pitches) * 9
	y_bot := y + staff_heigth / f32(nb_pitches) * 21

	for n in b.notes {
		old_x = next_x
		next_x, note_y, nb_tails = n.draw(ctx, next_x, y, x_end, staff_heigth, g_length)
		if int(n.pitch) >= int(Pitches._b) {
			for i in 0 .. int(n.pitch) - int(Pitches.f) - 1 { // little lines
				if i % 2 == 0 {
					line_y := y_top - f32(i) / f32(nb_pitches) * staff_heigth
					ctx.draw_line(old_x - 1.5 * radius, line_y, old_x + 1.5 * radius,
						line_y, black)
				}
			}
		} else {
			for i in 0 .. int(Pitches._e) - int(n.pitch) - 1 { // little lines
				if i % 2 == 0 {
					line_y := y_bot + f32(i) / f32(nb_pitches) * staff_heigth
					ctx.draw_line(old_x - 1.5 * radius, line_y, old_x + 1.5 * radius,
						line_y, black)
				}
			}
		}
		if nb_tails >= 1 {
			if int(n.pitch) >= int(Pitches._b) {
				tail_x := old_x - radius / 2
				if int(n.pitch) >= int(Pitches.b) {
					ctx.draw_line(tail_x, note_y, tail_x, y_middle, black)
				} else {
					ctx.draw_line(tail_x, note_y, tail_x, note_y + tail_size, black)
				}
			} else {
				tail_x := old_x + radius / 2
				if int(n.pitch) <= int(Pitches._bb) {
					ctx.draw_line(tail_x, note_y, tail_x, y_middle, black)
				} else {
					ctx.draw_line(tail_x, note_y, tail_x, note_y - tail_size, black)
				}
			}
			if nb_tails >= 2 {
				ctx.draw_text(int(old_x), int(note_y), nb_tails.str(), gx.TextCfg{})
			}
		}
	}

	return next_x
}

fn (g Group) draw(ctx gg.Context, x f32, y f32, x_end f32, staff_heigth f32, x_start f32) (f32, f32) {
	mut next_x := x
	mut next_y := y
	if g.new_line {
		next_y += staff_heigth
		next_x = x_start
	}
	old_x := next_x

	if g.new_line {
		ctx.draw_text(int(next_x), int(next_y + staff_heigth / 2), 'treble', gx.TextCfg{})
		next_x += 50.0
		ctx.draw_text(int(next_x), int(next_y + staff_heigth / 2), g.meter, gx.TextCfg{})
		next_x += 50.0
	}

	for b in g.beams {
		next_x = b.draw(ctx, next_x, next_y, x_end, staff_heigth, g.length)
	}

	y_top := next_y + staff_heigth / f32(nb_pitches) * 11
	y_bot := next_y + staff_heigth / f32(nb_pitches) * 19
	ctx.draw_line(next_x, y_top, next_x, y_bot, black)
	if g.right_bar == .double {
		next_x += 5
		ctx.draw_line(next_x, y_top, next_x, y_bot, black)
	}
	next_x += 2 * radius

	for p in staff_lines {
		line_y := next_y + staff_heigth - f32(int(p)) / f32(nb_pitches) * staff_heigth
		ctx.draw_line(old_x - 2 * radius, line_y, next_x, line_y, black)
	}

	return next_x, next_y
}

pub fn (s Staff) draw(ctx gg.Context, x f32, y f32, x_end f32) {
	ctx.draw_text(int(x), int(y), s.title, gx.TextCfg{})
	mut next_x := x
	// top of the staff
	mut next_y := y - s.px_height // first group is new line

	for g in s.groups {
		next_x, next_y = g.draw(ctx, next_x, next_y, x_end, s.px_height, x)
	}
}

pub fn create_staff(file_name string) !Staff {
	file := os.read_bytes(file_name)!
	mut notes := false // in the part with the notes
	mut staff := Staff{}
	mut note := Note{}
	mut beam := Beam{}
	mut group := Group{
		new_line: true
	}

	mut i := 0
	for i < file.len {
		if notes {
			match file[i] {
				`a`...`g` {
					if file[i + 1] == `'` {
						note.pitch = match file[i] {
							`a` { .aa }
							`b` { .bb }
							`c` { .cc }
							`d` { .dd }
							`e` { .ee }
							`f` { .ff }
							`g` { .gg }
							else { return error('${file[i]}') }
						}
						i++ // '
					} else {
						note.pitch = match file[i] {
							`a` { .a }
							`b` { .b }
							`c` { .c }
							`d` { .d }
							`e` { .e }
							`f` { .f }
							`g` { .g }
							else { return error('${file[i]}') }
						}
					}
					i++ // letter

					match file[i] {
						`/` {
							i++ // /
							note.divide = true
							note.factor = match file[i] {
								`1`...`9` {
									match file[i + 1] {
										`1`...`9` {
											i++
											i++
											int(file[i - 2] - 48) * 10 + int(file[i - 1] - 48)
										}
										else {
											i++
											int(file[i - 1] - 48)
										}
									}
								}
								else {
									2
								}
							}
						}
						`1`...`9` {
							note.divide = false
							note.factor = match file[i + 1] {
								`1`...`9` {
									i++
									i++
									int(file[i - 2] - 48) * 10 + int(file[i - 1] - 48)
								}
								else {
									i++
									int(file[i - 1] - 48)
								}
							}
						}
						else {}
					}

					beam.notes << note
					note = Note{}
				}
				`A`...`G` {
					if file[i + 1] == `,` {
						note.pitch = match file[i] {
							`A` { ._aa }
							`B` { ._bb }
							`C` { ._cc }
							`D` { ._dd }
							`E` { ._ee }
							`F` { ._ff }
							`G` { ._gg }
							else { return error('${file[i]}') }
						}
						i++ // '
					} else {
						note.pitch = match file[i] {
							`A` { ._a }
							`B` { ._b }
							`C` { ._c }
							`D` { ._d }
							`E` { ._e }
							`F` { ._f }
							`G` { ._g }
							else { return error('${file[i]}') }
						}
					}
					i++ // letter

					match file[i] {
						`/` {
							i++ // /
							note.divide = true
							note.factor = match file[i] {
								`1`...`9` {
									match file[i + 1] {
										`1`...`9` {
											i++
											i++
											int(file[i - 2] - 48) * 10 + int(file[i - 1] - 48)
										}
										else {
											i++
											int(file[i - 1] - 48)
										}
									}
								}
								else {
									2
								}
							}
						}
						`1`...`9` {
							note.divide = false
							note.factor = match file[i + 1] {
								`1`...`9` {
									i++
									i++
									int(file[i - 2] - 48) * 10 + int(file[i - 1] - 48)
								}
								else {
									i++
									int(file[i - 1] - 48)
								}
							}
						}
						else {}
					}

					beam.notes << note
					note = Note{}
				}
				`|`, `:` {
					if file[i + 1] == `]` {
						group.right_bar = .double
						i++
					} else if file[i + 1] == `:` {
						i++
					}
					staff.groups << group
					l := group.length
					m := group.meter
					group = Group{
						length: l
						meter:  m
					}
					i++
				}
				` ` {
					i++ // ' '
					if beam.notes.len > 0 {
						group.beams << beam
						beam = Beam{}
					}
				}
				`\n` {
					group.new_line = true
					i++
				}
				else {
					println(file[i].ascii_str())
					i++
				}
			}
		} else {
			match file[i] {
				`X` {
					i++
					for file[i - 1] != `\n` {
						i++
					}
				}
				`M` {
					i++ // T
					i++ // :
					for file[i] != `\n` {
						group.meter += file[i].ascii_str()
						i++
					}
					i++ // \n
				}
				`L` {
					i++ // T
					i++ // :
					mut length := ''
					mut first := f32(0.0)
					for file[i] != `\n` {
						if file[i] != `/` {
							length += file[i].ascii_str()
						} else {
							first = length.f32()
							length = ''
						}
						i++
					}
					group.length = first / length.f32()

					i++ // \n
				}
				`K` {
					i++ // T
					i++ // :
					for file[i] != `\n` {
						staff.key += file[i].ascii_str()
						i++
					}
					i++ // \n
					notes = true
				}
				`T` {
					i++ // T
					i++ // :
					for file[i] != `\n` {
						staff.title += file[i].ascii_str()
						i++
					}
					i++ // \n
				}
				else {
					println(file[i].ascii_str())
					i++
				}
			}
		}
	}
	return staff
}
