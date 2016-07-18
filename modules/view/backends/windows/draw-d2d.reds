Red/System [
	Title:	"Direct2D Draw dialect backend"
	Author: "Qingtian Xie"
	File: 	%draw-d2d.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %direct2d.reds

#define DRAW_FLOAT_MAX		[as float32! 3.4e38]

max-edges: 1000												;-- max number of edges for a polygone
edges: as POINT_2F allocate max-edges * (size? POINT_2F)	;-- polygone edges buffer

draw-ctx!: alias struct! [
	rt				[ID2D1HwndRenderTarget]
	this			[this!]
	pen-join		[integer!]
	pen-cap			[integer!]
	pen-width		[integer!]
	pen-style		[integer!]
	pen-color		[integer!]					;-- 00bbggrr format
	brush-color		[integer!]					;-- 00bbggrr format
	font-color		[integer!]
	pen				[integer!]
	brush			[integer!]
	pen?			[logic!]
	brush?			[logic!]
	on-image?		[logic!]					;-- drawing on image?
]

draw-begin: func [
	hwnd		[handle!]
	img			[red-image!]
	on-graphic? [logic!]
	paint?		[logic!]
	return: 	[handle!]
	/local
		this	[this!]
		rt		[ID2D1HwndRenderTarget]
		ctx		[integer!]
		pen		[integer!]
][
	this: create-hwnd-render-target hwnd
	rt: as ID2D1HwndRenderTarget this/vtbl
	rt/BeginDraw this
	pen: 0

	ctx: as draw-ctx! allocate size? draw-ctx!
	ctx/rt:				rt
	ctx/this:			this
	ctx/pen-width:		1
	ctx/pen-style:		0
	ctx/pen-color:		0						;-- default: black
	ctx/pen-join:		miter
	ctx/pen-cap:		flat
	ctx/brush-color:	0
	ctx/font-color:		0
	ctx/pen?:			yes
	ctx/brush?:			no

	as handle! ctx
]

draw-end: func [
	dc			[handle!]
	hWnd		[handle!]
	on-graphic? [logic!]
	cache?		[logic!]
	paint?		[logic!]
	/local
		ctx		[draw-ctx!]
][
	ctx/rt/EndDraw ctx/this null null
	free as byte-ptr! dc
]

OS-draw-anti-alias: func [
	dc	[handle!]
	on? [logic!]
][

]

OS-draw-line: func [
	dc	   [handle!]
	point  [red-pair!]
	end	   [red-pair!]
	/local
		pt		[POINT_2F]
		nb		[integer!]
		pair	[red-pair!]
		ctx		[draw-ctx!]
][
	ctx:	as draw-ctx! dc
	pt:		edges
	pair:	point
	nb:		0

	while [all [pair <= end nb < max-edges]][
		pt/x: as float32! integer/to-float pair/x
		pt/y: as float32! integer/to-float pair/y
		nb: nb + 1
		pt: pt + 1
		pair: pair + 1
	]

	either nb = 2 [
		pt: edges + 1
		ctx/DrawLine ctx/this edges/x edges/y pt/x pt/y
	][
		0
	]
]

OS-draw-pen: func [
	dc	   [handle!]
	color  [integer!]									;-- 00bbggrr format
	off?   [logic!]
	alpha? [logic!]
	/local
		r  [float!]
		g  [float!]
		b  [float!]
		a  [float!]
][
	modes/pen?: not off?
	if modes/pen-color <> color [
		modes/pen-color: color
		r: integer/to-float color and FFh
		r: r / 255.0
		g: integer/to-float color >> 8 and FFh
		g: g / 255.0
		b: integer/to-float color >> 16 and FFh
		b: b / 255.0
		a: integer/to-float 255 - (color >>> 24)
		a: a / 255.0
		;CGContextSetRGBStrokeColor dc as float32! r as float32! g as float32! b as float32! a
	]
]

OS-draw-fill-pen: func [
	dc	   [handle!]
	color  [integer!]									;-- 00bbggrr format
	off?   [logic!]
	alpha? [logic!]
	/local
		r  [float!]
		g  [float!]
		b  [float!]
		a  [float!]
][
	modes/brush?: not off?
	if modes/brush-color <> color [
		modes/brush-color: color
		r: integer/to-float color and FFh
		r: r / 255.0
		g: integer/to-float color >> 8 and FFh
		g: g / 255.0
		b: integer/to-float color >> 16 and FFh
		b: b / 255.0
		a: integer/to-float 255 - (color >>> 24)
		a: a / 255.0
		;CGContextSetRGBFillColor dc as float32! r as float32! g as float32! b as float32! a
	]
]

OS-draw-line-width: func [
	dc	  [handle!]
	width [red-integer!]
][
	if modes/pen-width <> width/value [
		modes/pen-width: width/value
		;CGContextSetLineWidth dc as float32! integer/to-float width/value
	]
]

OS-draw-box: func [
	dc	  [handle!]
	upper [red-pair!]
	lower [red-pair!]
	/local
		radius [red-integer!]
		rad	   [integer!]
		rc	   [NSRect!]
][
	either TYPE_OF(lower) = TYPE_INTEGER [
		radius: as red-integer! lower
		lower:  lower - 1
		rad: radius/value * 2
		;;@@ TBD round box
	][
		rc: make-rect upper/x upper/y lower/x - upper/x lower/y - upper/y
		if modes/brush? [				;-- fill rect
			;CGContextFillRect dc rc/x rc/y rc/w rc/h
		]
		;CGContextStrokeRect dc rc/x rc/y rc/w rc/h
	]
]

OS-draw-triangle: func [
	dc	  [handle!]
	start [red-pair!]
	/local
		point [POINT_2F]
][
	point: edges

	loop 3 [
		point/x: as float32! integer/to-float start/x
		point/y: as float32! integer/to-float start/y
		point: point + 1
		start: start + 1
	]
	point/x: edges/x									;-- close the triangle
	point/y: edges/y
	;CGContextBeginPath dc
	;CGContextAddLines dc edges 4
	;CGContextStrokePath dc
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
		rad-x [integer!]
		rad-y [integer!]
][
0
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
	mode: kCGLineJoinMiter
	if modes/pen-join <> style [
		modes/pen-join: style
		case [
			style = miter		[mode: kCGLineJoinMiter]
			style = miter-bevel [mode: kCGLineJoinMiter]
			style = _round		[mode: kCGLineJoinRound]
			style = bevel		[mode: kCGLineJoinBevel]
			true				[mode: kCGLineJoinMiter]
		]
		;CGContextSetLineJoin dc mode
	]
]
	
OS-draw-line-cap: func [
	dc	  [handle!]
	style [integer!]
	/local
		mode [integer!]
][
	mode: kCGLineCapButt
	if modes/pen-cap <> style [
		modes/pen-cap: style
		case [
			style = flat		[mode: kCGLineCapButt]
			style = square		[mode: kCGLineCapSquare]
			style = _round		[mode: kCGLineCapRound]
			true				[mode: kCGLineCapButt]
		]
		;CGContextSetLineCap dc mode
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
][0]


OS-matrix-rotate: func [
	angle	[red-integer!]
	center	[red-pair!]
][
	if angle <> as red-integer! center [OS-matrix-translate 0 - center/x 0 - center/y]
	if angle <> as red-integer! center [OS-matrix-translate center/x center/y]
]

OS-matrix-scale: func [
	sx		[red-integer!]
	sy		[red-integer!]
][
0
]

OS-matrix-translate: func [
	x	[integer!]
	y	[integer!]
][0
]

OS-matrix-skew: func [
	sx		[red-integer!]
	sy		[red-integer!]
	/local
		m	[integer!]
		x	[float32!]
		y	[float32!]
		u	[float32!]
		z	[float32!]
][
	m: 0
	u: as float32! 1.0
	z: as float32! 0.0
	x: as float32! system/words/tan degree-to-radians get-float sx TYPE_TANGENT
	y: as float32! either sx = sy [0.0][system/words/tan degree-to-radians get-float sy TYPE_TANGENT]
]

OS-matrix-transform: func [
	rotate		[red-integer!]
	scale		[red-integer!]
	translate	[red-pair!]
	/local
		center	[red-pair!]
][
0
]

OS-matrix-push: func [/local state [integer!]][
	state: 0
]

OS-matrix-pop: func [][0]

OS-matrix-reset: func [][0]

OS-matrix-invert: func [/local m [integer!]][
	m: 0
]

OS-matrix-set: func [
	blk		[red-block!]
][0]