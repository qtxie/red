Red/System [
	Title:	"OSX Draw dialect backend"
	Author: "Qingtian Xie"
	File: 	%draw.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define DRAW_FLOAT_MAX		[as float32! 3.4e38]

max-edges: 1000												;-- max number of edges for a polygon
edges: as CGPoint! allocate max-edges * (size? CGPoint!)	;-- polygone edges buffer

draw-ctx!: alias struct! [
	raw				[handle!]					;-- OS drawing object: CGContext
	pen-join		[integer!]
	pen-cap			[integer!]
	pen-width		[integer!]
	pen-style		[integer!]
	pen-color		[integer!]					;-- 00bbggrr format
	brush-color		[integer!]					;-- 00bbggrr format
	font-color		[integer!]
	pen?			[logic!]
	brush?			[logic!]
	on-image?		[logic!]					;-- drawing on image?
]

draw-begin: func [
	ctx			[draw-ctx!]
	CGCtx		[handle!]
	img			[red-image!]
	on-graphic? [logic!]
	paint?		[logic!]
	return: 	[draw-ctx!]
][
	ctx/raw:			CGCtx
	ctx/pen-width:		1
	ctx/pen-style:		0
	ctx/pen-color:		0						;-- default: black
	ctx/pen-join:		miter
	ctx/pen-cap:		flat
	ctx/brush-color:	0
	ctx/font-color:		0
	ctx/pen?:			yes
	ctx/brush?:			no

	CGContextSetMiterLimit CGCtx DRAW_FLOAT_MAX
	ctx
]

draw-end: func [
	dc			[draw-ctx!]
	hWnd		[handle!]
	on-graphic? [logic!]
	cache?		[logic!]
	paint?		[logic!]
][
	0
]

OS-draw-anti-alias: func [
	dc	[draw-ctx!]
	on? [logic!]
][
	CGContextSetAllowsAntialiasing dc/raw on?
	CGContextSetAllowsFontSmoothing dc/raw on?
]

OS-draw-line: func [
	dc	   [draw-ctx!]
	point  [red-pair!]
	end	   [red-pair!]
	/local
		pt		[CGPoint!]
		nb		[integer!]
		pair	[red-pair!]
		ctx		[handle!]
][
	ctx:	dc/raw
	pt:		edges
	pair:	point
	nb:		0

	while [all [pair <= end nb < max-edges]][
		pt/x: as float32! pair/x
		pt/y: as float32! pair/y
		nb: nb + 1
		pt: pt + 1
		pair: pair + 1
	]
	CGContextBeginPath ctx
	CGContextAddLines ctx edges nb
	CGContextStrokePath ctx
]

OS-draw-pen: func [
	dc	   [draw-ctx!]
	color  [integer!]									;-- aabbggrr format
	off?   [logic!]
	alpha? [logic!]
	/local
		r  [float32!]
		g  [float32!]
		b  [float32!]
		a  [float32!]
][
	dc/pen?: not off?
	if all [not off? dc/pen-color <> color][
		dc/pen-color: color
		r: as float32! (as-float color and FFh) / 255.0
		g: as float32! (as-float color >> 8 and FFh) / 255.0
		b: as float32! (as-float color >> 16 and FFh) / 255.0
		a: as float32! (as-float 255 - (color >>> 24)) / 255.0
		CGContextSetRGBStrokeColor dc/raw r g b a
	]
]

OS-draw-fill-pen: func [
	dc	   [draw-ctx!]
	color  [integer!]									;-- aabbggrr format
	off?   [logic!]
	alpha? [logic!]
	/local
		r  [float32!]
		g  [float32!]
		b  [float32!]
		a  [float32!]
][
	either off? [dc/brush?: no][
		if dc/brush-color <> color [
			dc/brush?: yes
			dc/brush-color: color
			r: as float32! (as-float color and FFh) / 255.0
			g: as float32! (as-float color >> 8 and FFh) / 255.0
			b: as float32! (as-float color >> 16 and FFh) / 255.0
			a: as float32! (as-float 255 - (color >>> 24)) / 255.0
			CGContextSetRGBFillColor dc/raw r g b a
		]
	]
]

OS-draw-line-width: func [
	dc	  [draw-ctx!]
	width [red-integer!]
][
	if dc/pen-width <> width/value [
		dc/pen-width: width/value
		CGContextSetLineWidth dc/raw as float32! width/value
	]
]

OS-draw-box: func [
	dc	  [draw-ctx!]
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
		if dc/brush? [				;-- fill rect
			CGContextFillRect dc/raw rc/x rc/y rc/w rc/h
		]
		CGContextStrokeRect dc/raw rc/x rc/y rc/w rc/h
	]
]

OS-draw-triangle: func [
	dc	  [draw-ctx!]
	start [red-pair!]
	/local
		ctx   [handle!]
		point [CGPoint!]
][
	ctx: dc/raw
	point: edges

	loop 3 [
		point/x: as float32! start/x
		point/y: as float32! start/y
		point: point + 1
		start: start + 1
	]
	point/x: edges/x									;-- close the triangle
	point/y: edges/y
	CGContextBeginPath ctx
	CGContextAddLines ctx edges 4
	CGContextStrokePath ctx								;-- will clear current path
]

OS-draw-polygon: func [
	dc	  [draw-ctx!]
	start [red-pair!]
	end	  [red-pair!]
	/local
		ctx   [handle!]
		pair  [red-pair!]
		point [CGPoint!]
		nb	  [integer!]
		mode  [integer!]
][
	ctx:   dc/raw
	point: edges
	pair:  start
	nb:	   0
	
	while [all [pair <= end nb < max-edges]][
		point/x: as float32! pair/x
		point/y: as float32! pair/y
		nb: nb + 1
		point: point + 1
		pair: pair + 1	
	]
	;if nb = max-edges [fire error]	
	point/x: as float32! start/x						;-- close the polygon
	point/y: as float32! start/y

	CGContextBeginPath ctx
	CGContextAddLines ctx edges nb + 1

	mode: case [
		all [dc/pen? dc/brush?] [kCGPathFillStroke]
		dc/brush?				[kCGPathFill]
		dc/pen?					[kCGPathStroke]
		true					[-1]
	]
	if mode <> -1 [CGContextDrawPath ctx mode]
]

OS-draw-spline: func [
	dc		[draw-ctx!]
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
	dc		[draw-ctx!]
	x		[float32!]
	y		[float32!]
	w		[float32!]
	h		[float32!]
][
	if dc/brush? [CGContextFillEllipseInRect dc/raw x y w h]
	CGContextStrokeEllipseInRect dc/raw x y w h
]

OS-draw-circle: func [
	dc	   [draw-ctx!]
	center [red-pair!]
	radius [red-integer!]
	/local
		rad-x [integer!]
		rad-y [integer!]
		w	  [float32!]
		h	  [float32!]
		f	  [red-float!]
][
	either TYPE_OF(radius) = TYPE_INTEGER [
		either center + 1 = radius [					;-- center, radius
			rad-x: radius/value
			rad-y: rad-x
		][
			rad-y: radius/value							;-- center, radius-x, radius-y
			radius: radius - 1
			rad-x: radius/value
		]
		w: as float32! rad-x * 2
		h: as float32! rad-y * 2
	][
		f: as red-float! radius
		either center + 1 = radius [
			rad-x: as-integer f/value + 0.75
			rad-y: rad-x
			w: as float32! f/value * 2.0
			h: w
		][
			rad-y: as-integer f/value + 0.75
			h: as float32! f/value * 2.0
			f: f - 1
			rad-x: as-integer f/value + 0.75
			w: as float32! f/value * 2.0
		]
	]
	do-draw-ellipse dc as float32! center/x - rad-x as float32! center/y - rad-y w h
]

OS-draw-ellipse: func [
	dc	  	 [draw-ctx!]
	upper	 [red-pair!]
	diameter [red-pair!]
][
	do-draw-ellipse dc as float32! upper/x as float32! upper/y as float32! diameter/x as float32! diameter/y
]

OS-draw-font: func [
	dc		[draw-ctx!]
	font	[red-object!]
	/local
		vals  [red-value!]
		state [red-block!]
		int   [red-integer!]
		color [red-tuple!]
		hFont [draw-ctx!]
][
0
]

OS-draw-text: func [
	dc		[draw-ctx!]
	pos		[red-pair!]
	text	[red-string!]
	/local
		str		[c-string!]
		len		[integer!]
][
0
]

OS-draw-arc: func [
	dc	   [draw-ctx!]
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
	dc	  [draw-ctx!]
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
	dc	  [draw-ctx!]
	style [integer!]
	/local
		mode [integer!]
][
	mode: kCGLineJoinMiter
	if dc/pen-join <> style [
		dc/pen-join: style
		case [
			style = miter		[mode: kCGLineJoinMiter]
			style = miter-bevel [mode: kCGLineJoinMiter]
			style = _round		[mode: kCGLineJoinRound]
			style = bevel		[mode: kCGLineJoinBevel]
			true				[mode: kCGLineJoinMiter]
		]
		CGContextSetLineJoin dc/raw mode
	]
]
	
OS-draw-line-cap: func [
	dc	  [draw-ctx!]
	style [integer!]
	/local
		mode [integer!]
][
	mode: kCGLineCapButt
	if dc/pen-cap <> style [
		dc/pen-cap: style
		case [
			style = flat		[mode: kCGLineCapButt]
			style = square		[mode: kCGLineCapSquare]
			style = _round		[mode: kCGLineCapRound]
			true				[mode: kCGLineCapButt]
		]
		CGContextSetLineCap dc/raw mode
	]
]

CG-draw-image: func [						;@@ use CALayer to get very good performance?
	dc			[handle!]
	bitmap		[integer!]
	x			[integer!]
	y			[integer!]
	width		[integer!]
	height		[integer!]
	/local
		rc		[NSRect!]
		image	[integer!]
		ty		[float32!]
][
	image: CGBitmapContextCreateImage bitmap
	rc: make-rect x y width height
	ty: rc/y + rc/h
	;-- flip coords
	;; drawing an image or PDF by calling Core Graphics functions directly,
	;; we must flip the CTM.
	;; http://stackoverflow.com/questions/506622/cgcontextdrawimage-draws-image-upside-down-when-passed-uiimage-cgimage
	CGContextTranslateCTM dc as float32! 0.0 ty
	CGContextScaleCTM dc as float32! 1.0 as float32! -1.0

	CGContextDrawImage dc rc/x as float32! 0.0 rc/w rc/h image
	CGImageRelease image

	;-- flip back
	CGContextScaleCTM dc as float32! 1.0 as float32! -1.0
	CGContextTranslateCTM dc as float32! 0.0 (as float32! 0.0) - ty
]

OS-draw-image: func [
	dc			[draw-ctx!]
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
	either null? start [x: 0 y: 0][x: start/x y: start/y]
	case [
		start = end [
			width:  IMAGE_WIDTH(image/size)
			height: IMAGE_HEIGHT(image/size)
		]
		start + 1 = end [					;-- two control points
			width: end/x - x
			height: end/y - y
		]
		start + 2 = end [0]					;@@ TBD three control points
		true [0]							;@@ TBD four control points
	]

	CG-draw-image dc/raw as-integer image/node x y width height
]

OS-draw-grad-pen: func [
	dc			[draw-ctx!]
	type		[integer!]
	mode		[integer!]
	offset		[red-pair!]
	count		[integer!]					;-- number of the colors
	brush?		[logic!]
][0]


OS-matrix-rotate: func [
	angle	[red-integer!]
	center	[red-pair!]
	/local
		m	[integer!]
		pts [tagPOINT]
][
	if angle <> as red-integer! center [
0
	]
	;GdipRotateWorldTransform dc/graphics get-float32 angle GDIPLUS_MATRIXORDERAPPEND
	if angle <> as red-integer! center [
0
	]
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
][
0
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
	center: as red-pair! either rotate + 1 = scale [rotate][rotate + 1]
	OS-matrix-rotate rotate center
	OS-matrix-scale scale scale + 1
	OS-matrix-translate translate/x translate/y
]

OS-matrix-push: func [/local state [integer!]][
	state: 0
]

OS-matrix-pop: func [][0]

OS-matrix-reset: func [][0]

OS-matrix-invert: func [/local m [integer!]][
0
]

OS-matrix-set: func [
	blk		[red-block!]
	/local
		m	[integer!]
		val [red-integer!]
][
	m: 0
	val: as red-integer! block/rs-head blk
]
