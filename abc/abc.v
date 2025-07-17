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
	_c // 60 in midi standard (middle C)
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

pub const midi_to_pitch = {
	48: Pitches._cc
	50: Pitches._dd
	52: Pitches._ee
	53: Pitches._ff
	55: Pitches._gg
	57: Pitches._aa
	59: Pitches._bb
	60: Pitches._c
	62: Pitches._d
	64: Pitches._e
	65: Pitches._f
	67: Pitches._g
	69: Pitches._a
	71: Pitches._b
	72: Pitches.c
	74: Pitches.d
	76: Pitches.e
	77: Pitches.f
	79: Pitches.g
	81: Pitches.a
	83: Pitches.b
	84: Pitches.cc
	86: Pitches.dd
	88: Pitches.ee
	89: Pitches.ff
	91: Pitches.gg
	93: Pitches.aa
	95: Pitches.bb
}

pub const nb_pitches = 28
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
pub mut:
	title string
	//	meter     string
	key       string
	composer  string
	groups    []Group
	px_height f32 = 100.0
}

pub struct ProcessedStaff {
pub mut:
	title    string
	key      string
	composer string
	plines   []ProcessedLine
}

pub struct ProcessedLine {
pub mut:
	px_height f32
	// coords of top left
	x             f32
	x_end         f32
	y             f32
	y_lines       []f32
	meter         string
	bars          []ProcessedBar
	notes         []ProcessedNote
	slines        []SupportLine
	treble_x_size f32 = 50.0
	meter_x_size  f32 = 50.0
}

pub struct ProcessedNote {
pub mut:
	x            f32
	y            f32
	pitch        Pitches
	len          Lengths
	nb_dots      int
	tail_x       f32
	tail_start_y f32
	tail_end_y   f32
}

pub struct SupportLine {
pub mut:
	x f32
	y f32
}

pub struct ProcessedBar {
pub mut:
	x     f32
	y_top f32
	y_bot f32
	bar   Bars
}

pub const radius = f32(4)
const black = gg.Color{0, 0, 0, 255}

pub fn (pl ProcessedLine) draw(ctx gg.Context) {
	for y in pl.y_lines {
		ctx.draw_line(pl.x, f32(int(y)) - 0.5, pl.x_end, f32(int(y)) - 0.5, black)
	}
	for n in pl.notes {
		ctx.draw_circle_filled(n.x, f32(int(n.y)) - 0.5, radius, black)
		ctx.draw_line(n.x, n.tail_start_y, n.x, n.tail_end_y, black)
	}
}

pub fn (ps ProcessedStaff) draw(ctx gg.Context) {
	for pl in ps.plines {
		pl.draw(ctx)
	}
}

fn (n Note) process(mut pline ProcessedLine, x f32, y f32, x_end f32, g_length f32) (f32, f32, int) {
	note_y := y + pline.px_height - f32(int(n.pitch)) / f32(nb_pitches) * pline.px_height
	mut pnote := ProcessedNote{
		x:     x
		y:     note_y
		pitch: n.pitch
	}

	px_whole_length := f32(150)
	true_factor := if n.divide {
		g_length / f32(n.factor)
	} else {
		g_length * f32(n.factor)
	}
	factor_log2 := math.log2(true_factor * 2)
	rounded_log := math.round(factor_log2)
	rounded_power_of2 := math.pow(2.0, int(math.log2(f64(n.factor))))
	if rounded_log != factor_log2 {
		// for notes with dots after
		normalized_len := f64(n.factor) / rounded_power_of2 // 1.5 or 1.75
		if normalized_len == 1.5 {
			pnote.nb_dots = 1
		}
		if normalized_len == 1.75 {
			pnote.nb_dots = 2
		}
	}

	pnote.len = if true_factor >= 2.0 {
		.doublewhole
	} else if true_factor >= 1.0 {
		.whole
	} else if true_factor >= 0.5 {
		.half
	} else if true_factor >= 0.25 {
		.quarter
	} else if true_factor >= 0.125 {
		.eighth
	} else if true_factor >= 0.0625 {
		.sixteenth
	} else if true_factor >= 0.03125 {
		.thirtysecond
	} else {
		println('Unsupported note length ${n} ${true_factor}')
		Lengths.quarter
	}

	n_length := px_whole_length * true_factor
	next_x := x + n_length

	pline.notes << pnote

	mut nb_tails := -int(math.ceil(factor_log2))
	if true_factor < 1.0 && nb_tails <= 0 {
		nb_tails = 1
	}

	return next_x, note_y, nb_tails
}

fn (b Beam) process(mut pline ProcessedLine, x f32, y f32, x_end f32, g_length f32) f32 {
	mut next_x := x
	mut note_y := y
	mut nb_tails := 0
	mut old_x := x

	tail_size := pline.px_height / f32(nb_pitches) * 7
	y_middle := y + pline.px_height / f32(nb_pitches) * 15
	y_top := y + pline.px_height / f32(nb_pitches) * 9
	y_bot := y + pline.px_height / f32(nb_pitches) * 21

	for n in b.notes {
		old_x = next_x
		next_x, note_y, nb_tails = n.process(mut pline, next_x, y, x_end, g_length)
		if int(n.pitch) >= int(Pitches._b) {
			for i in 0 .. int(n.pitch) - int(Pitches.f) - 1 { // little lines
				if i % 2 == 0 {
					pline.slines << SupportLine{old_x - 1.5 * radius, y_top - f32(i) / f32(nb_pitches) * pline.px_height}
				}
			}
		} else {
			for i in 0 .. int(Pitches._e) - int(n.pitch) - 1 { // little lines
				if i % 2 == 0 {
					pline.slines << SupportLine{old_x - 1.5 * radius, y_bot - f32(i) / f32(nb_pitches) * pline.px_height}
				}
			}
		}
		if nb_tails >= 1 {
			if int(n.pitch) >= int(Pitches._b) {
				pline.notes[pline.notes.len - 1].tail_x = old_x - radius / 2
				if int(n.pitch) >= int(Pitches.b) {
					pline.notes[pline.notes.len - 1].tail_start_y = note_y
					pline.notes[pline.notes.len - 1].tail_end_y = y_middle
				} else {
					pline.notes[pline.notes.len - 1].tail_start_y = note_y
					pline.notes[pline.notes.len - 1].tail_end_y = note_y + tail_size
				}
			} else {
				pline.notes[pline.notes.len - 1].tail_x = old_x + radius / 2
				if int(n.pitch) >= int(Pitches.b) {
					pline.notes[pline.notes.len - 1].tail_start_y = note_y
					pline.notes[pline.notes.len - 1].tail_end_y = y_middle
				} else {
					pline.notes[pline.notes.len - 1].tail_start_y = note_y
					pline.notes[pline.notes.len - 1].tail_end_y = note_y - tail_size
				}
			}
		}
	}

	return next_x
}

fn (g Group) process(mut pstaff ProcessedStaff, x f32, y f32, x_end f32, staff_heigth f32, x_start f32) (f32, f32) {
	mut next_x := x
	mut next_y := y
	if g.new_line {
		next_y += staff_heigth
		next_x = x_start
		pstaff.plines << ProcessedLine{
			meter:     g.meter
			px_height: staff_heigth
			x:         next_x
			y:         next_y
		}
		for p in staff_lines {
			y_line := next_y + staff_heigth - f32(int(p)) / f32(nb_pitches) * staff_heigth
			pstaff.plines[pstaff.plines.len - 1].y_lines << y_line
		}
	}

	if g.new_line {
		// ctx.draw_text(int(next_x), int(next_y + staff_heigth / 2), 'treble', gx.TextCfg{})
		next_x += pstaff.plines[pstaff.plines.len - 1].treble_x_size
		// ctx.draw_text(int(next_x), int(next_y + staff_heigth / 2), g.meter, gx.TextCfg{})
		next_x += pstaff.plines[pstaff.plines.len - 1].meter_x_size
	}

	for b in g.beams {
		next_x = b.process(mut pstaff.plines[pstaff.plines.len - 1], next_x, next_y, x_end,
			g.length)
	}

	y_top := next_y + staff_heigth / f32(nb_pitches) * 11
	y_bot := next_y + staff_heigth / f32(nb_pitches) * 19
	pstaff.plines[pstaff.plines.len - 1].bars << ProcessedBar{next_x, y_top, y_bot, g.right_bar}
	// next_x += 4 * radius

	pstaff.plines[pstaff.plines.len - 1].x_end = next_x

	return next_x, next_y
}

pub fn process(s Staff, x f32, y f32, x_end f32) ProcessedStaff {
	mut p := ProcessedStaff{
		title: s.title
	}
	mut next_x := x
	// top of the staff
	mut next_y := y - s.px_height // first group is new line

	for g in s.groups {
		next_x, next_y = g.process(mut p, next_x, next_y, x_end, s.px_height, x)
	}
	return p
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
