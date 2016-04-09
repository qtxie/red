Red/System [
	Title:	"Cairo Draw dialect backend"
	Author: "Qingtian Xie"
	File: 	%draw.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

modes: declare struct! [
	pen-join		[integer!]
	pen-cap			[integer!]
	pen-width		[integer!]
	pen-style		[integer!]
	pen-color		[integer!]					;-- 00bbggrr format
	brush-color		[integer!]					;-- 00bbggrr format
	font-color		[integer!]
	pen?			[logic!]
	brush?			[logic!]
	pattern			[handle!]
	on-image?		[logic!]					;-- drawing on image?
]

set-source-color: func [
	cr			[handle!]
	color		[integer!]
	/local
		r		[float!]
		b		[float!]
		g		[float!]
		a		[float!]
][
	r: integer/to-float color and FFh
	r: r / 255.0
	g: integer/to-float color >> 8 and FFh
	g: g / 255.0
	b: integer/to-float color >> 16 and FFh
	b: b / 255.0
	a: integer/to-float 255 - (color >>> 24)
	a: a / 255.0
	cairo_set_source_rgba cr r g b a
]

draw-begin: func [
	cr			[handle!]
	img			[red-image!]
	on-graphic? [logic!]
	paint?		[logic!]
	return: 	[handle!]
][
	modes/pen-width:	1
	modes/pen-style:	0
	modes/pen-color:	0						;-- default: black
	modes/pen-join:		miter
	modes/pen-cap:		flat
	modes/brush-color:	0
	modes/font-color:	0
	modes/pen?:			yes
	modes/brush?:		no
	modes/pattern:		null

	cairo_set_line_width cr 1.0
	set-source-color cr 0
	cr
]

draw-end: func [
	dc			[handle!]
	hWnd		[handle!]
	on-graphic? [logic!]
	cache?		[logic!]
	paint?		[logic!]
][
	0
]

do-paint: func [dc [handle!]][
	if modes/brush? [
		cairo_save dc
		either null? modes/pattern [
			set-source-color dc modes/brush-color
		][
			cairo_set_source dc modes/pattern
		]
		cairo_fill_preserve dc
		cairo_restore dc
	]
	if modes/pen? [cairo_stroke dc]
]

OS-draw-anti-alias: func [
	dc	[handle!]
	on? [logic!]
][
0
]

OS-draw-line: func [
	dc	   [handle!]
	point  [red-pair!]
	end	   [red-pair!]
][
	while [point <= end][
		cairo_line_to dc integer/to-float point/x integer/to-float point/y
		point: point + 1
	]
	cairo_stroke dc
]

OS-draw-pen: func [
	dc	   [handle!]
	color  [integer!]									;-- 00bbggrr format
	off?   [logic!]
	alpha? [logic!]
][
	modes/pen?: not off?
	if modes/pen-color <> color [
		modes/pen-color: color
		set-source-color dc color
	]
]

OS-draw-fill-pen: func [
	dc	   [handle!]
	color  [integer!]									;-- 00bbggrr format
	off?   [logic!]
	alpha? [logic!]
][
	modes/brush?: not off?
	unless null? modes/pattern [
		cairo_pattern_destroy modes/pattern
		modes/pattern: null
	]
	if modes/brush-color <> color [
		modes/brush-color: color
	]
]

OS-draw-line-width: func [
	dc	  [handle!]
	width [red-integer!]
	/local
		w [integer!]
][
	w: width/value
	if modes/pen-width <> w [
		modes/pen-width: w
		cairo_set_line_width dc integer/to-float w
	]
]

OS-draw-box: func [
	dc	  [handle!]
	upper [red-pair!]
	lower [red-pair!]
	/local
		radius	[red-integer!]
		rad		[integer!]
		x		[float!]
		y		[float!]
		w		[float!]
		h		[float!]
][
	either TYPE_OF(lower) = TYPE_INTEGER [
		radius: as red-integer! lower
		lower:  lower - 1
		rad: radius/value * 2
		;;@@ TBD round box
	][
		x: integer/to-float upper/x
		y: integer/to-float upper/y
		w: integer/to-float lower/x - upper/x
		h: integer/to-float lower/y - upper/y
		cairo_rectangle dc x y w h
		do-paint dc
	]
]

OS-draw-triangle: func [
	dc	  [handle!]
	start [red-pair!]
][
	loop 3 [
		cairo_line_to dc integer/to-float start/x integer/to-float start/y
		start: start + 1
	]
	cairo_close_path dc									;-- close the triangle
	cairo_stroke dc
]

OS-draw-polygon: func [
	dc	  [handle!]
	start [red-pair!]
	end	  [red-pair!]
	/local
		pair  [red-pair!]
		point [tagPOINT]
		nb	  [integer!]
][
0
]

OS-draw-spline: func [
	dc		[handle!]
	start	[red-pair!]
	end		[red-pair!]
	closed? [logic!]
	/local
		pair  [red-pair!]
		point [tagPOINT]
		nb	  [integer!]
][
0
]

do-draw-ellipse: func [
	dc		[handle!]
	x		[integer!]
	y		[integer!]
	width	[integer!]
	height	[integer!]
][
0
]

OS-draw-circle: func [
	dc	   [handle!]
	center [red-pair!]
	radius [red-integer!]
	/local
		x [float!]
		y [float!]
][
	x: integer/to-float center/x
	y: integer/to-float center/y
	cairo_arc dc x y integer/to-float radius/value 0.0 2.0 * pi
	do-paint dc
]

OS-draw-ellipse: func [
	dc	  	 [handle!]
	upper	 [red-pair!]
	diameter [red-pair!]
][
0
]

OS-draw-font: func [
	dc		[handle!]
	font	[red-object!]
	/local
		vals  [red-value!]
		state [red-block!]
		int   [red-integer!]
		color [red-tuple!]
		hFont [handle!]
][
0
]

OS-draw-text: func [
	dc		[handle!]
	pos		[red-pair!]
	text	[red-string!]
	/local
		str		[c-string!]
		len		[integer!]
][
0
]

OS-draw-arc: func [
	dc	   [handle!]
	center [red-pair!]
	end	   [red-value!]
	/local
		radius		[red-pair!]
		angle		[red-integer!]
		rad-x		[integer!]
		rad-y		[integer!]
		start-x		[integer!]
		start-y 	[integer!]
		end-x		[integer!]
		end-y		[integer!]
		angle-begin [float!]
		angle-len	[float!]
		rad-x-float	[float!]
		rad-y-float	[float!]
		rad-x-2		[float!]
		rad-y-2		[float!]
		rad-x-y		[float!]
		tan-2		[float!]
		closed?		[logic!]
][
0
]

OS-draw-curve: func [
	dc	  [handle!]
	start [red-pair!]
	end	  [red-pair!]
	/local
		pair  [red-pair!]
		point [tagPOINT]
		p2	  [red-pair!]
		p3	  [red-pair!]
		nb	  [integer!]
		count [integer!]
][
0
]

OS-draw-line-join: func [
	dc	  [handle!]
	style [integer!]
	/local
		mode [integer!]
][
	if modes/pen-join <> style [
		modes/pen-join: style
	]
]
	
OS-draw-line-cap: func [
	dc	  [handle!]
	style [integer!]
	/local
		mode [integer!]
][
	if modes/pen-cap <> style [
		modes/pen-cap: style
	]
]

OS-draw-image: func [
	dc			[handle!]
	image		[red-image!]
	start		[red-pair!]
	end			[red-pair!]
	key-color	[red-tuple!]
	border?		[logic!]
	pattern		[red-word!]
	/local
		x		[integer!]
		y		[integer!]
		width	[integer!]
		height	[integer!]
][
0
]

OS-draw-grad-pen: func [
	dc			[handle!]
	type		[integer!]
	mode		[integer!]
	offset		[red-pair!]
	count		[integer!]					;-- number of the colors
	brush?		[logic!]
	/local
		x		[float!]
		y		[float!]
		start	[float!]
		stop	[float!]
		pattern	[handle!]
		int		[red-integer!]
		f		[red-float!]
		head	[red-value!]
		next	[red-value!]
		clr		[red-tuple!]
		n		[integer!]
		delta	[float!]
		p		[float!]
		scale?	[logic!]
][
	x: integer/to-float offset/x
	y: integer/to-float offset/y

	int: as red-integer! offset + 1
	start: integer/to-float int/value
	int: int + 1
	stop: integer/to-float int/value

	pattern: either type = linear [
		cairo_pattern_create_linear x + start y x + stop y
	][
		cairo_pattern_create_radial x y start x y stop
	]

	n: 0
	scale?: no
	y: 1.0
	while [
		int: int + 1
		n < 3
	][								;-- fetch angle, scale-x and scale-y (optional)
		switch TYPE_OF(int) [
			TYPE_INTEGER	[p: integer/to-float int/value]
			TYPE_FLOAT		[f: as red-float! int p: f/value]
			default			[break]
		]
		switch n [
			0	[0]					;-- rotation
			1	[x:	p scale?: yes]
			2	[y:	p]
		]
		n: n + 1
	]

	if scale? [0]

	delta: 1.0 / integer/to-float count - 1
	p: 0.0
	head: as red-value! int
	loop count [
		clr: as red-tuple! either TYPE_OF(head) = TYPE_WORD [_context/get as red-word! head][head]
		next: head + 1
		n: clr/array1
		x: integer/to-float n and FFh
		x: x / 255.0
		y: integer/to-float n >> 8 and FFh
		y: y / 255.0
		start: integer/to-float n >> 16 and FFh
		start: start / 255.0
		stop: integer/to-float 255 - (n >>> 24)
		stop: stop / 255.0
		if TYPE_OF(next) = TYPE_FLOAT [head: next f: as red-float! head p: f/value]
		cairo_pattern_add_color_stop_rgba pattern p x y start stop
		p: p + delta
		head: head + 1
	]

	if brush? [modes/brush?: yes]				;-- set brush, or set pen
	unless null? modes/pattern [cairo_pattern_destroy modes/pattern]
	modes/pattern: pattern
]
