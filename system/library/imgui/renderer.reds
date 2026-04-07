Red/System [
	Title:   "Red/System imgui ASCII renderer"
	Author:  "OpenAI"
	File: 	 %renderer.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %imgui.reds

#define IMGUI-RENDERER-MAX-CELLS 4000

imgui-renderer: context [
	width: 0
	height: 0
	cells: as byte-ptr! 0
	row-buffer: as byte-ptr! 0

	ensure-buffer: func [
		w [integer!]
		h [integer!]
	][
		if any [
			null? cells
			(width <> w)
			(height <> h)
		][
			cells: allocate IMGUI-RENDERER-MAX-CELLS
			row-buffer: allocate 512
		]
		width: w
		height: h
	]

	clear: func [
		w [integer!]
		h [integer!]
	][
		ensure-buffer w h
		set-memory cells #" " (w * h)
	]

	index-of: func [
		x [integer!]
		y [integer!]
		return: [integer!]
	][
		(y * width) + x + 1
	]

	put-char: func [
		x [integer!]
		y [integer!]
		ch [byte!]
		/local idx [integer!]
	][
		if any [
			x < 0
			y < 0
			x >= width
			y >= height
		][exit]
		idx: index-of x y
		cells/idx: ch
	]

	cell-at: func [
		x [integer!]
		y [integer!]
		return: [byte!]
		/local idx [integer!]
	][
		if any [
			x < 0
			y < 0
			x >= width
			y >= height
		][return null-byte]
		idx: index-of x y
		cells/idx
	]

	contains-char?: func [
		ch [byte!]
		return: [logic!]
		/local
			i [integer!]
			limit [integer!]
	][
		i: 1
		limit: width * height
		while [i <= limit][
			if cells/i = ch [return yes]
			i: i + 1
		]
		no
	]

	scale-x: func [v [float!] return: [integer!]][as integer! (v / 8.0)]
	scale-y: func [v [float!] return: [integer!]][as integer! (v / 8.0)]

	draw-text: func [
		x	 [integer!]
		y	 [integer!]
		txt [c-string!]
		/local
			i [integer!]
			p [byte-ptr!]
	][
		if null? txt [exit]
		i: 0
		p: as byte-ptr! txt
		until [
			if p/1 = null-byte [exit]
			put-char (x + i) y p/1
			i: i + 1
			p: p + 1
			no
		]
	]

	draw-hline: func [
		x1 [integer!]
		x2 [integer!]
		y  [integer!]
		ch [byte!]
		/local x [integer!]
	][
		x: x1
		while [x <= x2][
			put-char x y ch
			x: x + 1
		]
	]

	draw-vline: func [
		x  [integer!]
		y1 [integer!]
		y2 [integer!]
		ch [byte!]
		/local y [integer!]
	][
		y: y1
		while [y <= y2][
			put-char x y ch
			y: y + 1
		]
	]

	draw-box: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		ch [byte!]
	][
		draw-hline x1 x2 y1 ch
		draw-hline x1 x2 y2 ch
		draw-vline x1 y1 y2 ch
		draw-vline x2 y1 y2 ch
	]

	draw-fill: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		ch [byte!]
		/local y [integer!]
	][
		y: y1
		while [y <= y2][
			draw-hline x1 x2 y ch
			y: y + 1
		]
	]

	draw-line: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		ch [byte!]
		/local
			dx [integer!]
			dy [integer!]
			steps [integer!]
			i [integer!]
			xf [float!]
			yf [float!]
			x-step [float!]
			y-step [float!]
			fsteps [float!]
		][
		dx: x2 - x1
		dy: y2 - y1
		steps: dx
		if steps < 0 [steps: 0 - steps]
		if dy < 0 [
			if (0 - dy) > steps [steps: 0 - dy]
		]
		if dy >= 0 [
			if dy > steps [steps: dy]
			]
			if zero? steps [
				put-char x1 y1 ch
				exit
			]
			xf: as float! x1
			yf: as float! y1
			fsteps: as float! steps
			x-step: (as float! dx) / fsteps
			y-step: (as float! dy) / fsteps
			i: 0
		while [i <= steps][
			put-char as integer! xf as integer! yf ch
			xf: xf + x-step
			yf: yf + y-step
			i: i + 1
		]
	]

	rect-char-for: func [
		color [integer!]
		return: [byte!]
	][
		either color = 102 [#"="][
			either color = 301 [#"+"][ 
				either color = 302 [#"*"][
					either color = 401 [#"["][
						either color = 501 [#"-"][
							either color = 502 [#"~"][#"#"]
						]
					]
				]
			]
		]
	]

	line-char-for: func [
		color [integer!]
		return: [byte!]
	][
		either color = 402 [#"\"][#"/"]
	]

	render-draw-list: func [
		w [integer!]
		h [integer!]
		/local
			i		[integer!]
			kind	[integer!]
			color	[integer!]
			x1		[integer!]
			y1		[integer!]
			x2		[integer!]
			y2		[integer!]
			label	[c-string!]
			fill	[integer!]
	][
		clear w h
		i: 1
		while [i <= imgui/draw-count?][
			kind: imgui/draw-kind-at i
			color: imgui/draw-color-at i
			x1: scale-x (imgui/draw-x1-at i)
			y1: scale-y (imgui/draw-y1-at i)
			x2: scale-x (imgui/draw-x2-at i)
			y2: scale-y (imgui/draw-y2-at i)
			label: imgui/draw-label-at i
			switch kind [
				IMGUID-Rect [
					either color = 502 [
						fill: x1 + as integer! (((as float! (x2 - x1)) * imgui/draw-value-at i))
						draw-fill x1 y1 fill y2 #"~"
					][
						draw-box x1 y1 x2 y2 (rect-char-for color)
					]
				]
				IMGUID-Text [
					draw-text x1 y1 label
				]
				IMGUID-Line [
					draw-line x1 y1 x2 y2 (line-char-for color)
				]
			]
			i: i + 1
		]
	]

	print-canvas: func [/local x y idx][
		y: 0
		while [y < height][
			x: 0
			while [x < width][
				idx: x + 1
				row-buffer/idx: cell-at x y
				x: x + 1
			]
			idx: width + 1
			row-buffer/idx: null-byte
			print-line as c-string! row-buffer
			y: y + 1
		]
	]
]
