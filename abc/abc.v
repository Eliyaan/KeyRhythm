import os
import gg

enum Pitches {
	CC
	DD
	EE
	FF
	GG
	AA
	BB
	C
	D
	E
	F
	G
	A
	B
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

struct Lengths {
	thirtysecond // demi-semi-quaver
	sixteenth // semi-quavers
	eighth	// quavers
	quarter	// crochet
	half	// minim
	whole   // semibreve
	doublewhole // breve
}

struct Note {
	pitch Pitches
	factor int // relative to the length of the group
	divide bool // if the factor divides or multiplies
}

enum Bars {
	single
}

struct Beam {
	notes []Note
}

struct Group {
	length string
	left_bar Bars
	right_bar Bars
	beams []Beam
}

struct Staff {
	title string
	meter string
	key string
	composer string
	staff []Group
}

fn create_staff(file_name string) Staff! {
	file := os.read_bytes(file_name)!
	mut staff := Staff{}
	mut notes := false // the part with the notes
	mut note := Note{}
	mut group := Group{}

	mut i := 0
	for i < file.len {
		if notes {
			match staff[i] {
				`a`...`g` {
					if staff[i+1] == `'` {
						note.pitch = match staff[i] {
							`a` { .aa } 
							`b` { .bb } 
							`c` { .cc } 
							`d` { .dd } 
							`e` { .ee } 
							`f` { .ff } 
							`g` { .gg } 
						}
						i++ // '
					} else {
						note.pitch = match staff[i] {
							`a` { .a } 
							`b` { .b } 
							`c` { .c } 
							`d` { .d } 
							`e` { .e } 
							`f` { .f } 
							`g` { .g } 
						}
					}
					i++ // letter
					
					match staff[i] {
						`/` {
							i++ // /
							note.divide = true
							note.length = match staff[i] {
								`1`...`9` {
									match staff[i + 1] {
										`1`...`9` {
											i++
											i++
											int(staff[i-2]) * 10 + int(staff[i-1])
										}
										else {
											i++
											int(staff[i-1])
										}
									}
								}
								else {
									2
								}
							}
						}
						`1`...`9` {
							node.divide = false
							node.length = match staff[i + 1] {
								`1`...`9` {
									i++
									i++
									int(staff[i-2]) * 10 + int(staff[i-1])
								}
								else {
									i++
									int(staff[i-1])
								}
							}
						}
					}
					
					if staff[i] == ` ` {
						
					}
					
				}
				`A`...`G` {
						note.pitch = match staff[i] {
							`A` { .AA } 
							`B` { .BB } 
							`C` { .CC } 
							`D` { .DD } 
							`E` { .EE } 
							`F` { .FF } 
							`G` { .GG } 
						}
				}
				else {
					println(staff[i].ascii_str())
				}
			}
		} else { 
			match staff[i] {
				`X` {
					for staff[i - 1] != `\n` {
						i++
					}
				}
				`M` {
					i++ // T
					i++ // :
					for staff[i] != `\n` {
						staff.meter += staff[i].ascii_str()
						i++
					}
					i++ // \n
				}
				`L` {
					i++ // T
					i++ // :
					for staff[i] != `\n` {
						group.length += staff[i].ascii_str()
						i++
					}
					i++ // \n
				}
				`K` {
					i++ // T
					i++ // :
					for staff[i] != `\n` {
						staff.key += staff[i].ascii_str()
						i++
					}
					i++ // \n
					notes = true
				}
				`T` {
					i++ // T
					i++ // :
					for staff[i] != `\n` {
						staff.title += staff[i].ascii_str()
						i++
					}
					i++ // \n
				}
				else {
					println(staff[i].ascii_str())
				}
			}
		}
	}
}
