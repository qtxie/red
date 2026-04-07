Red/System [
	Title:   "Red/System imgui pixel renderer"
	Author:  "OpenAI"
	File: 	 %pixel-renderer.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#include %imgui.reds

#define IMGUI-PIXEL-MAX-BYTES 1048576

imgui-pixel-renderer: context [
	width: 0
	height: 0
	pixels: as byte-ptr! 0						;-- BGRA bytes for direct X11 blitting on little-endian Linux

	ensure-buffer: func [
		w [integer!]
		h [integer!]
		/local bytes [integer!]
	][
		bytes: w * h * 4
		if any [
			null? pixels
			(width <> w)
			(height <> h)
		][
			if bytes > IMGUI-PIXEL-MAX-BYTES [bytes: IMGUI-PIXEL-MAX-BYTES]
			pixels: allocate bytes
		]
		width: w
		height: h
	]

	clear: func [
		w [integer!]
		h [integer!]
	][
		ensure-buffer w h
		set-memory pixels null-byte (w * h * 4)
	]

	byte-index-of: func [
		x [integer!]
		y [integer!]
		return: [integer!]
	][
		((y * width) + x) * 4 + 1
	]

	put-pixel-rgb: func [
		x [integer!]
		y [integer!]
		r [byte!]
		g [byte!]
		b [byte!]
		/local idx idx2 idx3 idx4 [integer!]
	][
		if any [
			x < 0
			y < 0
			x >= width
			y >= height
		][exit]
		idx: byte-index-of x y
		idx2: idx + 1
		idx3: idx + 2
		idx4: idx + 3
		pixels/idx: b
		pixels/idx2: g
		pixels/idx3: r
		pixels/idx4: null-byte
	]

	blend-pixel-rgba: func [
		x [integer!]
		y [integer!]
		r [byte!]
		g [byte!]
		b [byte!]
		a [byte!]
		/local
			idx idx2 idx3 [integer!]
			inv sr sg sb dr dg db [integer!]
	][
		if any [
			x < 0
			y < 0
			x >= width
			y >= height
		][exit]
		if zero? as integer! a [exit]
		if (as integer! a) = 255 [
			put-pixel-rgb x y r g b
			exit
		]
		idx: byte-index-of x y
		idx2: idx + 1
		idx3: idx + 2
		sb: as integer! b
		sg: as integer! g
		sr: as integer! r
		db: as integer! pixels/idx
		dg: as integer! pixels/idx2
		dr: as integer! pixels/idx3
		inv: 255 - as integer! a
		pixels/idx: as byte! (((sb * as integer! a) + (db * inv)) / 255)
		pixels/idx2: as byte! (((sg * as integer! a) + (dg * inv)) / 255)
		pixels/idx3: as byte! (((sr * as integer! a) + (dr * inv)) / 255)
	]

	pixel-red-at: func [
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
		idx: byte-index-of x y + 2
		pixels/idx
	]

	pixel-green-at: func [
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
		idx: byte-index-of x y + 1
		pixels/idx
	]

	pixel-blue-at: func [
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
		idx: byte-index-of x y
		pixels/idx
	]

	pixel-at: func [
		x [integer!]
		y [integer!]
		return: [byte!]
	][
		pixel-red-at x y
	]

	scale-x: func [v [float!] return: [integer!]][as integer! v]
	scale-y: func [v [float!] return: [integer!]][as integer! v]

	resolve-color: func [
		color [integer!]
		r-out [byte-ptr!]
		g-out [byte-ptr!]
		b-out [byte-ptr!]
		a-out [byte-ptr!]
	][
		switch color [
			101 [r-out/1: as byte! 38  g-out/1: as byte! 48  b-out/1: as byte! 64  a-out/1: as byte! 255]
			102 [r-out/1: as byte! 29  g-out/1: as byte! 41  b-out/1: as byte! 57  a-out/1: as byte! 230]
			201 [r-out/1: as byte! 244 g-out/1: as byte! 247 b-out/1: as byte! 250 a-out/1: as byte! 255]
			202 [r-out/1: as byte! 66  g-out/1: as byte! 73  b-out/1: as byte! 82  a-out/1: as byte! 255]
			203 [r-out/1: as byte! 28  g-out/1: as byte! 33  b-out/1: as byte! 41  a-out/1: as byte! 255]
			204 [r-out/1: as byte! 42  g-out/1: as byte! 47  b-out/1: as byte! 54  a-out/1: as byte! 255]
			205 [r-out/1: as byte! 55  g-out/1: as byte! 61  b-out/1: as byte! 68  a-out/1: as byte! 255]
			301 [r-out/1: as byte! 76  g-out/1: as byte! 126 b-out/1: as byte! 196 a-out/1: as byte! 200]
			302 [r-out/1: as byte! 112 g-out/1: as byte! 170 b-out/1: as byte! 255 a-out/1: as byte! 220]
			401 [r-out/1: as byte! 68  g-out/1: as byte! 74  b-out/1: as byte! 82  a-out/1: as byte! 220]
			402 [r-out/1: as byte! 48  g-out/1: as byte! 176 b-out/1: as byte! 96  a-out/1: as byte! 255]
			501 [r-out/1: as byte! 124 g-out/1: as byte! 132 b-out/1: as byte! 144 a-out/1: as byte! 140]
			502 [r-out/1: as byte! 234 g-out/1: as byte! 153 b-out/1: as byte! 72  a-out/1: as byte! 225]
			601 [r-out/1: as byte! 0   g-out/1: as byte! 200 b-out/1: as byte! 255 a-out/1: as byte! 160]
			default [
				r-out/1: as byte! 180
				g-out/1: as byte! 180
				b-out/1: as byte! 180
				a-out/1: as byte! 255
			]
		]
	]

	plot-box: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		r [byte!]
		g [byte!]
		b [byte!]
		a [byte!]
		/local x y [integer!]
	][
		x: x1
		while [x <= x2][
			blend-pixel-rgba x y1 r g b a
			blend-pixel-rgba x y2 r g b a
			x: x + 1
		]
		y: y1
		while [y <= y2][
			blend-pixel-rgba x1 y r g b a
			blend-pixel-rgba x2 y r g b a
			y: y + 1
		]
	]

	plot-fill: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		r [byte!]
		g [byte!]
		b [byte!]
		a [byte!]
		/local x y [integer!]
	][
		y: y1
		while [y <= y2][
			x: x1
			while [x <= x2][
				blend-pixel-rgba x y r g b a
				x: x + 1
			]
			y: y + 1
		]
	]

	plot-line: func [
		x1 [integer!]
		y1 [integer!]
		x2 [integer!]
		y2 [integer!]
		r [byte!]
		g [byte!]
		b [byte!]
		a [byte!]
		/local
			dx dy steps i [integer!]
			xf yf x-step y-step fsteps frac [float!]
			ix iy cov [integer!]
	][
		dx: x2 - x1
		dy: y2 - y1
		steps: dx
		if steps < 0 [steps: 0 - steps]
		if dy < 0 [if (0 - dy) > steps [steps: 0 - dy]]
		if dy >= 0 [if dy > steps [steps: dy]]
		if zero? steps [
			blend-pixel-rgba x1 y1 r g b a
			exit
		]
		xf: as float! x1
		yf: as float! y1
		fsteps: as float! steps
		x-step: (as float! dx) / fsteps
		y-step: (as float! dy) / fsteps
		i: 0
		while [i <= steps][
			ix: as integer! xf
			iy: as integer! yf
			frac: xf - as float! ix
			if (0 - dx) > dy [frac: yf - as float! iy] ;-- alternate axis on steep lines
			cov: as integer! ((1.0 - frac) * 255.0)
			if cov < 0 [cov: 0]
			if cov > 255 [cov: 255]
			blend-pixel-rgba ix iy r g b as byte! ((as integer! a * cov) / 255)
			blend-pixel-rgba (ix + 1) iy r g b as byte! ((as integer! a * (255 - cov)) / 255)
			xf: xf + x-step
			yf: yf + y-step
			i: i + 1
		]
	]

	glyph-row: func [
		ch [byte!]
		row [integer!]
		return: [integer!]
	][
		if all [ch >= #"a" ch <= #"z"][ch: ch - 32]
		switch ch [
			#" " [switch row [0 [0] 1 [0] 2 [0] 3 [0] 4 [0] 5 [0] 6 [0]]]
			#"-" [switch row [0 [0] 1 [0] 2 [0] 3 [14] 4 [0] 5 [0] 6 [0]]]
			#"." [switch row [0 [0] 1 [0] 2 [0] 3 [0] 4 [0] 5 [12] 6 [12]]]
			#":" [switch row [0 [0] 1 [12] 2 [12] 3 [0] 4 [12] 5 [12] 6 [0]]]
			#"/" [switch row [0 [1] 1 [2] 2 [4] 3 [8] 4 [16] 5 [0] 6 [0]]]
			#"0" [switch row [0 [14] 1 [17] 2 [19] 3 [21] 4 [25] 5 [17] 6 [14]]]
			#"1" [switch row [0 [4] 1 [12] 2 [4] 3 [4] 4 [4] 5 [4] 6 [14]]]
			#"2" [switch row [0 [14] 1 [17] 2 [1] 3 [2] 4 [4] 5 [8] 6 [31]]]
			#"3" [switch row [0 [30] 1 [1] 2 [1] 3 [14] 4 [1] 5 [1] 6 [30]]]
			#"4" [switch row [0 [2] 1 [6] 2 [10] 3 [18] 4 [31] 5 [2] 6 [2]]]
			#"5" [switch row [0 [31] 1 [16] 2 [16] 3 [30] 4 [1] 5 [1] 6 [30]]]
			#"6" [switch row [0 [14] 1 [16] 2 [16] 3 [30] 4 [17] 5 [17] 6 [14]]]
			#"7" [switch row [0 [31] 1 [1] 2 [2] 3 [4] 4 [8] 5 [8] 6 [8]]]
			#"8" [switch row [0 [14] 1 [17] 2 [17] 3 [14] 4 [17] 5 [17] 6 [14]]]
			#"9" [switch row [0 [14] 1 [17] 2 [17] 3 [15] 4 [1] 5 [1] 6 [14]]]
			#"A" [switch row [0 [14] 1 [17] 2 [17] 3 [31] 4 [17] 5 [17] 6 [17]]]
			#"B" [switch row [0 [30] 1 [17] 2 [17] 3 [30] 4 [17] 5 [17] 6 [30]]]
			#"C" [switch row [0 [14] 1 [17] 2 [16] 3 [16] 4 [16] 5 [17] 6 [14]]]
			#"D" [switch row [0 [30] 1 [17] 2 [17] 3 [17] 4 [17] 5 [17] 6 [30]]]
			#"E" [switch row [0 [31] 1 [16] 2 [16] 3 [30] 4 [16] 5 [16] 6 [31]]]
			#"F" [switch row [0 [31] 1 [16] 2 [16] 3 [30] 4 [16] 5 [16] 6 [16]]]
			#"G" [switch row [0 [14] 1 [17] 2 [16] 3 [23] 4 [17] 5 [17] 6 [14]]]
			#"H" [switch row [0 [17] 1 [17] 2 [17] 3 [31] 4 [17] 5 [17] 6 [17]]]
			#"I" [switch row [0 [14] 1 [4] 2 [4] 3 [4] 4 [4] 5 [4] 6 [14]]]
			#"J" [switch row [0 [1] 1 [1] 2 [1] 3 [1] 4 [17] 5 [17] 6 [14]]]
			#"K" [switch row [0 [17] 1 [18] 2 [20] 3 [24] 4 [20] 5 [18] 6 [17]]]
			#"L" [switch row [0 [16] 1 [16] 2 [16] 3 [16] 4 [16] 5 [16] 6 [31]]]
			#"M" [switch row [0 [17] 1 [27] 2 [21] 3 [21] 4 [17] 5 [17] 6 [17]]]
			#"N" [switch row [0 [17] 1 [25] 2 [21] 3 [19] 4 [17] 5 [17] 6 [17]]]
			#"O" [switch row [0 [14] 1 [17] 2 [17] 3 [17] 4 [17] 5 [17] 6 [14]]]
			#"P" [switch row [0 [30] 1 [17] 2 [17] 3 [30] 4 [16] 5 [16] 6 [16]]]
			#"Q" [switch row [0 [14] 1 [17] 2 [17] 3 [17] 4 [21] 5 [18] 6 [13]]]
			#"R" [switch row [0 [30] 1 [17] 2 [17] 3 [30] 4 [20] 5 [18] 6 [17]]]
			#"S" [switch row [0 [15] 1 [16] 2 [16] 3 [14] 4 [1] 5 [1] 6 [30]]]
			#"T" [switch row [0 [31] 1 [4] 2 [4] 3 [4] 4 [4] 5 [4] 6 [4]]]
			#"U" [switch row [0 [17] 1 [17] 2 [17] 3 [17] 4 [17] 5 [17] 6 [14]]]
			#"V" [switch row [0 [17] 1 [17] 2 [17] 3 [17] 4 [17] 5 [10] 6 [4]]]
			#"W" [switch row [0 [17] 1 [17] 2 [17] 3 [21] 4 [21] 5 [21] 6 [10]]]
			#"X" [switch row [0 [17] 1 [17] 2 [10] 3 [4] 4 [10] 5 [17] 6 [17]]]
			#"Y" [switch row [0 [17] 1 [17] 2 [10] 3 [4] 4 [4] 5 [4] 6 [4]]]
			#"Z" [switch row [0 [31] 1 [1] 2 [2] 3 [4] 4 [8] 5 [16] 6 [31]]]
			default [switch row [0 [31] 1 [17] 2 [2] 3 [4] 4 [8] 5 [0] 6 [8]]]
		]
	]

	plot-text-block: func [
		x [integer!]
		y [integer!]
		txt [c-string!]
		r [byte!]
		g [byte!]
		b [byte!]
		a [byte!]
		/local
			i [integer!]
			row [integer!]
			col [integer!]
			bits [integer!]
			p [byte-ptr!]
	][
		if null? txt [exit]
		i: 0
		p: as byte-ptr! txt
		until [
			if p/1 = null-byte [exit]
			row: 0
			while [row < 7][
				bits: glyph-row p/1 row
				col: 0
				while [col < 5][
					if bits and (1 << (4 - col)) <> 0 [
						blend-pixel-rgba (x + i * 6 + col) (y + row) r g b a
					]
					col: col + 1
				]
				row: row + 1
			]
			i: i + 1
			p: p + 1
			no
		]
	]

	render-draw-list: func [
		w [integer!]
		h [integer!]
		/local
			i kind color [integer!]
			x1 y1 x2 y2 fill [integer!]
			label [c-string!]
			r [byte!]
			g [byte!]
			b [byte!]
			a [byte!]
	][
		clear w h
		r: null-byte
		g: null-byte
		b: null-byte
		a: as byte! 255
		i: 1
		while [i <= imgui/draw-count?][
			kind: imgui/draw-kind-at i
			color: imgui/draw-color-at i
			resolve-color color :r :g :b :a
			x1: scale-x (imgui/draw-x1-at i)
			y1: scale-y (imgui/draw-y1-at i)
			x2: scale-x (imgui/draw-x2-at i)
			y2: scale-y (imgui/draw-y2-at i)
			label: imgui/draw-label-at i
			switch kind [
				IMGUID-Rect [
					either any [color = 102 color = 502][
						either color = 502 [
							fill: x1 + as integer! (((as float! (x2 - x1)) * imgui/draw-value-at i))
							plot-fill x1 y1 fill y2 r g b a
						][
							plot-fill x1 y1 x2 y2 r g b a
						]
					][
						plot-box x1 y1 x2 y2 r g b a
					]
				]
				IMGUID-Text [
					plot-text-block x1 y1 label r g b a
				]
				IMGUID-Line [
					plot-line x1 y1 x2 y2 r g b a
				]
			]
			i: i + 1
		]
	]

	count-lit-pixels: func [
		return: [integer!]
		/local i limit count idx idx2 idx3 [integer!]
	][
		i: 0
		limit: width * height
		count: 0
		while [i < limit][
			idx: i * 4 + 1
			idx2: idx + 1
			idx3: idx + 2
			if any [
				pixels/idx <> null-byte
				pixels/idx2 <> null-byte
				pixels/idx3 <> null-byte
			][count: count + 1]
			i: i + 1
		]
		count
	]
]
