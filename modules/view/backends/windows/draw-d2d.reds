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
grad-stops: as D2D1_GRADIENT_STOP allocate 256 * size? D2D1_GRADIENT_STOP

draw-ctx!: alias struct! [
	rt				[ID2D1HwndRenderTarget]
	this			[this!]
	pen-join		[integer!]
	pen-cap			[integer!]
	pen-width		[float32!]
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

modes: declare draw-ctx!						;@@ TBD remove it after finish

draw-begin: func [
	hwnd		[handle!]
	img			[red-image!]
	on-graphic? [logic!]
	paint?		[logic!]
	return: 	[handle!]
	/local
		this	[this!]
		rt		[ID2D1HwndRenderTarget]
		ctx		[draw-ctx!]
		pen		[integer!]
		bgcolor [red-tuple!]
][
	this: as this! GetWindowLong hwnd wc-offset - 24
	if null? this [
		this: create-hwnd-render-target hwnd
		SetWindowLong hwnd wc-offset - 24 as-integer this
	]
	rt: as ID2D1HwndRenderTarget this/vtbl
	rt/BeginDraw this

	bgcolor: as red-tuple! get-node-facet
				as node! GetWindowLong hwnd wc-offset + 4
				FACE_OBJ_COLOR
	rt/Clear this to-dx-color bgcolor/array1 null

	pen: 0
	rt/CreateSolidColorBrush this to-dx-color 0 null null :pen
	
	ctx: as draw-ctx! allocate size? draw-ctx!
	ctx/rt:				rt
	ctx/this:			this
	ctx/pen-width:		as float32! 1.0
	ctx/pen-style:		0
	ctx/pen-color:		0						;-- default: black
	ctx/pen-join:		miter
	ctx/pen-cap:		flat
	ctx/brush-color:	0
	ctx/font-color:		0
	ctx/pen:			pen
	ctx/brush:			0
	ctx/pen?:			yes
	ctx/brush?:			no

	as handle! ctx
]

draw-end: func [
	dc			[handle!]
	hwnd		[handle!]
	on-graphic? [logic!]
	cache?		[logic!]
	paint?		[logic!]
	/local
		ctx		[draw-ctx!]
][
	ctx: as draw-ctx! dc
	ctx/rt/EndDraw ctx/this null null
	;@@ we should call this function
	;@@ but it's make our window black
	;@@ minimize and restore the window
	;@@ then we get the right result, very strange...
	ValidateRect hwnd null
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
		ctx/rt/DrawLine ctx/this edges/x edges/y pt/x pt/y ctx/pen ctx/pen-width ctx/pen-style
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
		ctx		[draw-ctx!]
		this	[this!]
		pen		[ID2D1SolidColorBrush]
][
	ctx: as draw-ctx! dc
	ctx/pen?: not off?
	if ctx/pen-color <> color [
		ctx/pen-color: color
		this: as this! ctx/pen
		pen: as ID2D1SolidColorBrush this/vtbl
		pen/SetColor this to-dx-color color null
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
	/local
		w	[float32!]
][
	w: as float32! integer/to-float width/value
	if modes/pen-width <> w [
		modes/pen-width: w
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
		;rc	   [NSRect!]
][
	either TYPE_OF(lower) = TYPE_INTEGER [
		radius: as red-integer! lower
		lower:  lower - 1
		rad: radius/value * 2
		;;@@ TBD round box
	][
		0
		;rc: make-rect upper/x upper/y lower/x - upper/x lower/y - upper/y
		;if modes/brush? [				;-- fill rect
			;CGContextFillRect dc rc/x rc/y rc/w rc/h
		;]
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
		ctx		[draw-ctx!]
		ellipse [D2D1_ELLIPSE]
		f		[red-float!]
		r		[float!]
][
	ctx: as draw-ctx! dc
	either TYPE_OF(radius) = TYPE_INTEGER [
		r: integer/to-float radius/value
	][
		f: as red-float! radius
		r: f/value
	]
	ellipse: declare D2D1_ELLIPSE
	ellipse/x: as float32! integer/to-float center/x
	ellipse/y: as float32! integer/to-float center/y
	ellipse/radiusX: as float32! r
	ellipse/radiusY: ellipse/radiusX
	if ctx/brush? [
		ctx/rt/FillEllipse ctx/this ellipse ctx/brush
	]
	if ctx/pen? [
		ctx/rt/DrawEllipse ctx/this ellipse ctx/pen ctx/pen-width ctx/pen-style
	]
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
0
]
	
OS-draw-line-cap: func [
	dc	  [handle!]
	style [integer!]
	/local
		mode [integer!]
][
0
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
		ctx		[draw-ctx!]
		rt		[ID2D1HwndRenderTarget]
		this	[this!]
		obj		[IUnknown]
		gprops	[D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES]
		gstops	[D2D1_GRADIENT_STOP]
		x		[float!]
		y		[float!]
		start	[float!]
		stop	[float!]
		brush	[integer!]
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
	ctx: as draw-ctx! dc
	this: as this! ctx/brush				;-- delete old brush
	COM_SAFE_RELEASE(obj this)

	rt: ctx/rt
	this: ctx/this
	int: as red-integer! offset + 1
	;start: integer/to-float int/value
	int: int + 1
	stop: as float! int/value

	n: 0
	scale?: no
	;y: 1.0
	while [
		int: int + 1
		n < 3
	][										;-- fetch angle, scale-x and scale-y (optional)
		switch TYPE_OF(int) [
			TYPE_INTEGER	[0];p: integer/to-float int/value]
			TYPE_FLOAT		[0];f: as red-float! int p: f/value]
			default			[break]
		]
		;switch n [
		;	0	[0]
		;	1	[if p <> 1.0 [x: p scale?: yes]]
		;	2	[if p <> 1.0 [y: p scale?: yes]]
		;]
		n: n + 1
	]

	gstops: grad-stops
	n: count - 1
	delta: as float! n
	delta: 1.0 / delta
	p: 0.0
	head: as red-value! int
	loop count [
		clr: as red-tuple! either TYPE_OF(head) = TYPE_WORD [_context/get as red-word! head][head]
		next: head + 1
		to-dx-color clr/array1 as D3DCOLORVALUE (as int-ptr! gstops) + 1
		if TYPE_OF(next) = TYPE_FLOAT [head: next f: as red-float! head p: f/value]
		gstops/position: as float32! p
		if next <> head [p: p + delta]
		head: head + 1
		gstops: gstops + 1
	]

	rt/CreateGradientStopCollection this grad-stops count 0 0 :n

	x: as float! offset/x
	y: as float! offset/y

	brush: 0
	either type = linear [
		0
	][
		gprops: declare D2D1_RADIAL_GRADIENT_BRUSH_PROPERTIES
		gprops/center.x: as float32! x
		gprops/center.y: as float32! y
		gprops/offset.x: as float32! 0.0
		gprops/offset.x: as float32! 0.0
		gprops/radius.x: as float32! stop
		gprops/radius.y: as float32! stop
		rt/CreateRadialGradientBrush this gprops null n :brush
	]

	this: as this! n
	COM_SAFE_RELEASE(obj this)

	if brush? [ctx/brush?: yes]				;-- set brush, or set pen
	ctx/brush: brush
]

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