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

max-edges: 1000												;-- max number of edges for a polygone
edges: as CGPoint! allocate max-edges * (size? CGPoint!)	;-- polygone edges buffer

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
	on-image?		[logic!]					;-- drawing on image?
]

draw-begin: func [
	CGCtx		[handle!]
	img			[red-image!]
	on-graphic? [logic!]
	paint?		[logic!]
	return: 	[handle!]
	/local
		ctx		[integer!]
][
	modes/pen-width:	1
	modes/pen-style:	0
	modes/pen-color:	0						;-- default: black
	modes/pen-join:		miter
	modes/pen-cap:		flat
	modes/brush-color:	0
	modes/font-color:	0
	modes/brush?:		yes
	modes/brush?:		no

	CGContextSetMiterLimit CGCtx DRAW_FLOAT_MAX
	CGCtx
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

OS-draw-anti-alias: func [
	dc	[handle!]
	on? [logic!]
][
	CGContextSetAllowsAntialiasing dc on?
	CGContextSetAllowsFontSmoothing dc on?
]

OS-draw-line: func [
	dc	   [handle!]
	point  [red-pair!]
	end	   [red-pair!]
	/local
		pt		[CGPoint!]
		nb		[integer!]
		pair	[red-pair!]
][
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
	CGContextBeginPath dc
	CGContextAddLines dc edges nb
	CGContextStrokePath dc
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
		CGContextSetRGBStrokeColor dc as float32! r as float32! g as float32! b as float32! a
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
		CGContextSetRGBFillColor dc as float32! r as float32! g as float32! b as float32! a
	]
]

OS-draw-line-width: func [
	dc	  [handle!]
	width [red-integer!]
][
	if modes/pen-width <> width/value [
		modes/pen-width: width/value
		CGContextSetLineWidth dc as float32! integer/to-float width/value
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
			CGContextFillRect dc rc/x rc/y rc/w rc/h
		]
		CGContextStrokeRect dc rc/x rc/y rc/w rc/h
	]
]

OS-draw-triangle: func [
	dc	  [handle!]
	start [red-pair!]
	/local
		point [CGPoint!]
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
	CGContextBeginPath dc
	CGContextAddLines dc edges 4
	CGContextStrokePath dc
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
		CGContextSetLineJoin dc mode
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
		CGContextSetLineCap dc mode
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

	CG-draw-image dc as-integer image/node x y width height
]

OS-draw-grad-pen: func [
	dc			[handle!]
	type		[integer!]
	mode		[integer!]
	offset		[red-pair!]
	count		[integer!]					;-- number of the colors
	brush?		[logic!]
][0]
