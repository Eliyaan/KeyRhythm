module abc

import os
import gg

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

enum Lengths {
	thirtysecond // demi-semi-quaver
	sixteenth // semi-quavers
	eighth	// quavers
	quarter	// crochet
	half	// minim
	whole   // semibreve
	doublewhole // breve
}

struct Note {
mut:
	pitch Pitches
	factor int = 1 // relative to the length of the group
	divide bool // if the factor divides or multiplies
}

enum Bars {
	single
}

struct Beam {
mut:
	notes []Note
}

struct Group {
mut:
	length string
	left_bar Bars
	right_bar Bars
	beams []Beam
}

struct Staff {
mut:
	title string
	meter string
	key string
	composer string
	groups []Group
}

pub fn create_staff(file_name string) !Staff {
	file := os.read_bytes(file_name)!
	mut notes := false // in the part with the notes
	mut staff := Staff{}
	mut note := Note{}
	mut beam := Beam{}
	mut group := Group{}

	mut i := 0
	for i < file.len {
		if notes {
			match file[i] {
				`a`...`g` {
					if file[i+1] == `'` {
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
											int(file[i-2] - 48) * 10 + int(file[i-1] - 48)
										}
										else {
											i++
											int(file[i-1] - 48)
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
									int(file[i-2] - 48) * 10 + int(file[i-1] - 48)
								}
								else {
									i++
									int(file[i-1] - 48)
								}
							}
						}
						else {}
					}
					
					beam.notes << note
					note = Note{}
				}
				`A`...`G` {
					if file[i+1] == `,` {
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
											int(file[i-2] - 48) * 10 + int(file[i-1] - 48)
										}
										else {
											i++
											int(file[i-1] - 48)
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
									int(file[i-2] - 48) * 10 + int(file[i-1] - 48)
								}
								else {
									i++
									int(file[i-1] - 48)
								}
							}
						}
						else {}
					}
					
					beam.notes << note
					note = Note{}
				}
				`|`, `:` {
					if file[i+1] == `|` {
						i++
					} else if file[i+1] == `:` {
						i++
					}
					staff.groups << group
					l := group.length
					group = Group{length: l}
					i++
				}
				` ` {
					i++ // ' '
					if beam.notes.len > 0 {
						group.beams << beam
						beam = Beam{}
					}
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
						staff.meter += file[i].ascii_str()
						i++
					}
					i++ // \n
				}
				`L` {
					i++ // T
					i++ // :
					for file[i] != `\n` {
						group.length += file[i].ascii_str()
						i++
					}
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
