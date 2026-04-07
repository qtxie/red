Red/System [
	Title:   "Red/System native immediate-mode UI core"
	Author:  "OpenAI"
	File: 	 %imgui.reds
	Rights:  "Copyright (C) 2026"
	License: "BSD-3"
]

#define IMGUI-MAX-WINDOWS	16
#define IMGUI-MAX-ITEMS		256
#define IMGUI-MAX-DRAWS		1024
#define IMGUI-MAX-MESH-VERTS 65536
#define IMGUI-MAX-MESH-IDX   98304
#define IMGUI-MAX-MESH-CMDS  2048
#define IMGUI-FONT-ATLAS-W   128
#define IMGUI-FONT-ATLAS-H   128

#define IMGUI-PADDING		12.0
#define IMGUI-HEADER-H		22.0
#define IMGUI-SPACING		8.0
#define IMGUI-TEXT-H		18.0
#define IMGUI-BUTTON-H		24.0
#define IMGUI-CHECKBOX-SIZE	18.0
#define IMGUI-SLIDER-W		160.0

#enum imgui-item-kind! [
	IMGUIT-None
	IMGUIT-Text
	IMGUIT-Button
	IMGUIT-Checkbox
	IMGUIT-SliderFloat
]

#enum imgui-draw-kind! [
	IMGUID-None
	IMGUID-Rect
	IMGUID-Text
	IMGUID-Line
]

imgui-window!: alias struct! [
	title		[c-string!]
	x			[float!]
	y			[float!]
	w			[float!]
	h			[float!]
	content-x	[float!]
	content-y	[float!]
	cursor-x	[float!]
	cursor-y	[float!]
	last-x		[float!]
	last-y		[float!]
	last-w		[float!]
	last-h		[float!]
]

imgui-item!: alias struct! [
	kind		[integer!]
	label		[c-string!]
	window-id	[integer!]
	x			[float!]
	y			[float!]
	w			[float!]
	h			[float!]
	value-i		[integer!]
	value-f		[float!]
	hovered?	[integer!]
	active?		[integer!]
]

imgui-context!: alias struct! [
	initialized?	[integer!]
	mouse-x			[float!]
	mouse-y			[float!]
	mouse-down?		[integer!]
	mouse-pressed?	[integer!]
	window-count	[integer!]
	item-count		[integer!]
	draw-count		[integer!]
	current-window	[integer!]
	hot-item		[integer!]
	active-item		[integer!]
	focused-item	[integer!]
	prev-focused	[integer!]
	first-focusable [integer!]
	key-tab?		[integer!]
	key-activate?	[integer!]
	key-left?		[integer!]
	key-right?		[integer!]
]

imgui-draw-cmd!: alias struct! [
	kind		[integer!]
	label		[c-string!]
	window-id	[integer!]
	x1			[float!]
	y1			[float!]
	x2			[float!]
	y2			[float!]
	thickness	[float!]
	color		[integer!]
	value-f		[float!]
]

imdraw-vert!: alias struct! [
	pos-x [float!]
	pos-y [float!]
	uv-x  [float!]
	uv-y  [float!]
	col-r [byte!]
	col-g [byte!]
	col-b [byte!]
	col-a [byte!]
]

imdraw-cmd!: alias struct! [
	elem-count [integer!]
	idx-offset [integer!]
	vtx-offset [integer!]
	clip-x1    [float!]
	clip-y1    [float!]
	clip-x2    [float!]
	clip-y2    [float!]
	texture-id [integer!]
]

imdraw-list!: alias struct! [
	cmd-offset [integer!]
	idx-offset [integer!]
	vtx-offset [integer!]
	vtx-count [integer!]
	idx-count [integer!]
	cmd-count [integer!]
]

imdraw-data!: alias struct! [
	valid?      [integer!]
	display-x   [float!]
	display-y   [float!]
	display-w   [float!]
	display-h   [float!]
	total-vtx   [integer!]
	total-idx   [integer!]
	cmd-lists   [integer!]
]

imgui: context [
	ctx: declare imgui-context!
	windows-storage: as int-ptr! 0
	items-storage: as int-ptr! 0
	draws-storage: as int-ptr! 0
	mesh-verts: as byte-ptr! 0
	mesh-indices: as int-ptr! 0
	mesh-cmds: as byte-ptr! 0
	mesh-lists: as byte-ptr! 0
	draw-list: declare imdraw-list!
	draw-data: declare imdraw-data!

	ensure-storage: does [
		if zero? ctx/initialized? [
			windows-storage: as int-ptr! allocate IMGUI-MAX-WINDOWS * size? imgui-window!
			items-storage: as int-ptr! allocate IMGUI-MAX-ITEMS * size? imgui-item!
			draws-storage: as int-ptr! allocate IMGUI-MAX-DRAWS * size? imgui-draw-cmd!
			mesh-verts: allocate IMGUI-MAX-MESH-VERTS * size? imdraw-vert!
			mesh-indices: as int-ptr! allocate IMGUI-MAX-MESH-IDX * size? integer!
			mesh-cmds: allocate IMGUI-MAX-MESH-CMDS * size? imdraw-cmd!
			mesh-lists: allocate IMGUI-MAX-WINDOWS * size? imdraw-list!
			set-memory as byte-ptr! windows-storage null-byte IMGUI-MAX-WINDOWS * size? imgui-window!
			set-memory as byte-ptr! items-storage null-byte IMGUI-MAX-ITEMS * size? imgui-item!
			set-memory as byte-ptr! draws-storage null-byte IMGUI-MAX-DRAWS * size? imgui-draw-cmd!
			set-memory mesh-verts null-byte IMGUI-MAX-MESH-VERTS * size? imdraw-vert!
			set-memory as byte-ptr! mesh-indices null-byte IMGUI-MAX-MESH-IDX * size? integer!
			set-memory mesh-cmds null-byte IMGUI-MAX-MESH-CMDS * size? imdraw-cmd!
			set-memory mesh-lists null-byte IMGUI-MAX-WINDOWS * size? imdraw-list!
			set-memory as byte-ptr! draw-list null-byte size? imdraw-list!
			set-memory as byte-ptr! draw-data null-byte size? imdraw-data!
			set-memory as byte-ptr! ctx null-byte size? imgui-context!
			ctx/initialized?: 1
		]
	]

	reset-frame-storage: does [
		set-memory as byte-ptr! windows-storage null-byte IMGUI-MAX-WINDOWS * size? imgui-window!
		set-memory as byte-ptr! items-storage null-byte IMGUI-MAX-ITEMS * size? imgui-item!
		set-memory as byte-ptr! draws-storage null-byte IMGUI-MAX-DRAWS * size? imgui-draw-cmd!
		set-memory mesh-verts null-byte IMGUI-MAX-MESH-VERTS * size? imdraw-vert!
		set-memory as byte-ptr! mesh-indices null-byte IMGUI-MAX-MESH-IDX * size? integer!
		set-memory mesh-cmds null-byte IMGUI-MAX-MESH-CMDS * size? imdraw-cmd!
		set-memory mesh-lists null-byte IMGUI-MAX-WINDOWS * size? imdraw-list!
		set-memory as byte-ptr! draw-list null-byte size? imdraw-list!
		set-memory as byte-ptr! draw-data null-byte size? imdraw-data!
		ctx/window-count: 0
		ctx/item-count: 0
		ctx/draw-count: 0
		ctx/current-window: 0
		ctx/hot-item: 0
		ctx/active-item: 0
		ctx/prev-focused: ctx/focused-item
		ctx/first-focusable: 0
	]

	clampf: func [
		value [float!]
		low	  [float!]
		high  [float!]
		return: [float!]
	][
		either value < low [low][either value > high [high][value]]
	]

	c-string-len: func [
		s		[c-string!]
		return: [integer!]
		/local
			p	[byte-ptr!]
			n	[integer!]
	][
		if null? s [return 0]
		p: as byte-ptr! s
		n: 0
		until [
			if p/1 = null-byte [return n]
			n: n + 1
			p: p + 1
			no
		]
		n
	]

	window-at: func [
		index	[integer!]
		return: [imgui-window!]
		/local p [byte-ptr!]
	][
		p: (as byte-ptr! windows-storage) + ((index - 1) * size? imgui-window!)
		as imgui-window! p
	]

	item-at: func [
		index	[integer!]
		return: [imgui-item!]
		/local p [byte-ptr!]
	][
		p: (as byte-ptr! items-storage) + ((index - 1) * size? imgui-item!)
		as imgui-item! p
	]

	draw-at: func [
		index	[integer!]
		return: [imgui-draw-cmd!]
		/local p [byte-ptr!]
	][
		p: (as byte-ptr! draws-storage) + ((index - 1) * size? imgui-draw-cmd!)
		as imgui-draw-cmd! p
	]

	mesh-vert-at: func [
		index [integer!]
		return: [imdraw-vert!]
		/local p [byte-ptr!]
	][
		p: mesh-verts + (index * size? imdraw-vert!)
		as imdraw-vert! p
	]

	mesh-cmd-at: func [
		index [integer!]
		return: [imdraw-cmd!]
		/local p [byte-ptr!]
	][
		p: mesh-cmds + (index * size? imdraw-cmd!)
		as imdraw-cmd! p
	]

	mesh-list-at: func [
		index [integer!]
		return: [imdraw-list!]
		/local p [byte-ptr!]
	][
		p: mesh-lists + (index * size? imdraw-list!)
		as imdraw-list! p
	]

	point-in-rect?: func [
		px [float!]
		py [float!]
		x  [float!]
		y  [float!]
		w  [float!]
		h  [float!]
		return: [logic!]
	][
		all [
			px >= x
			py >= y
			px < (x + w)
			py < (y + h)
		]
	]

	make-item: func [
		kind	[integer!]
		label	[c-string!]
		x		[float!]
		y		[float!]
		w		[float!]
		h		[float!]
		return: [imgui-item!]
		/local
			item	[imgui-item!]
			hover?	[logic!]
	][
		ctx/item-count: ctx/item-count + 1
		item: item-at ctx/item-count
		item/kind: kind
		item/label: label
		item/window-id: ctx/current-window
		item/x: x
		item/y: y
		item/w: w
		item/h: h
		item/value-i: 0
		item/value-f: 0.0
		hover?: point-in-rect? ctx/mouse-x ctx/mouse-y x y w h
		item/hovered?: as integer! hover?
		item/active?: as integer! all [hover? ctx/mouse-down? <> 0]
		if hover? [ctx/hot-item: ctx/item-count]
		if item/active? <> 0 [ctx/active-item: ctx/item-count]
		item
	]

	push-draw: func [
		kind		[integer!]
		label		[c-string!]
		x1			[float!]
		y1			[float!]
		x2			[float!]
		y2			[float!]
		thickness	[float!]
		color		[integer!]
		value-f		[float!]
		return:		[imgui-draw-cmd!]
		/local draw [imgui-draw-cmd!]
	][
		if ctx/draw-count >= IMGUI-MAX-DRAWS [return null]
		ctx/draw-count: ctx/draw-count + 1
		draw: draw-at ctx/draw-count
		draw/kind: kind
		draw/label: label
		draw/window-id: ctx/current-window
		draw/x1: x1
		draw/y1: y1
		draw/x2: x2
		draw/y2: y2
		draw/thickness: thickness
		draw/color: color
		draw/value-f: value-f
		draw
	]

	advance-cursor: func [
		win [imgui-window!]
		x	 [float!]
		y	 [float!]
		w	 [float!]
		h	 [float!]
	][
		win/last-x: x
		win/last-y: y
		win/last-w: w
		win/last-h: h
		win/cursor-x: win/content-x
		win/cursor-y: y + h + IMGUI-SPACING
	]

	init: does [
		ensure-storage
		ctx/mouse-x: 0.0
		ctx/mouse-y: 0.0
		ctx/mouse-down?: 0
		ctx/mouse-pressed?: 0
		ctx/focused-item: 0
		ctx/prev-focused: 0
		ctx/key-tab?: 0
		ctx/key-activate?: 0
		ctx/key-left?: 0
		ctx/key-right?: 0
		reset-frame-storage
	]

	begin-frame: does [
		ensure-storage
		reset-frame-storage
	]

	end-frame: does [
		if all [
			ctx/key-tab? <> 0
			zero? ctx/focused-item
			ctx/first-focusable > 0
		][
			ctx/focused-item: ctx/first-focusable
		]
		ctx/key-tab?: 0
		ctx/key-activate?: 0
		ctx/key-left?: 0
		ctx/key-right?: 0
	]

	set-mouse-state: func [
		x		 [float!]
		y		 [float!]
		down?	 [logic!]
		pressed? [logic!]
	][
		ctx/mouse-x: x
		ctx/mouse-y: y
		ctx/mouse-down?: as integer! down?
		ctx/mouse-pressed?: as integer! pressed?
	]

	set-key-state: func [
		tab?      [logic!]
		activate? [logic!]
		left?     [logic!]
		right?    [logic!]
	][
		if tab? [ctx/focused-item: 0]
		ctx/key-tab?: as integer! tab?
		ctx/key-activate?: as integer! activate?
		ctx/key-left?: as integer! left?
		ctx/key-right?: as integer! right?
	]

	register-focusable: func [
		return: [logic!]
		/local idx [integer!]
	][
		idx: ctx/item-count
		if zero? ctx/first-focusable [ctx/first-focusable: idx]
		if all [ctx/mouse-pressed? <> 0 ctx/hot-item = idx][ctx/focused-item: idx]
		if all [
			zero? ctx/focused-item
			ctx/key-tab? <> 0
			any [zero? ctx/prev-focused idx > ctx/prev-focused]
		][
			ctx/focused-item: idx
		]
		ctx/focused-item = idx
	]

	begin: func [
		title	[c-string!]
		x		[float!]
		y		[float!]
		w		[float!]
		h		[float!]
		return: [logic!]
		/local win [imgui-window!]
	][
		if ctx/window-count >= IMGUI-MAX-WINDOWS [return no]
		ctx/window-count: ctx/window-count + 1
		ctx/current-window: ctx/window-count
		win: window-at ctx/current-window
		win/title: title
		win/x: x
		win/y: y
		win/w: w
		win/h: h
		win/content-x: x + IMGUI-PADDING
		win/content-y: y + IMGUI-HEADER-H + IMGUI-PADDING
		win/cursor-x: win/content-x
		win/cursor-y: win/content-y
		win/last-x: win/content-x
		win/last-y: win/content-y
		win/last-w: 0.0
		win/last-h: 0.0
		push-draw IMGUID-Rect title x y (x + w) (y + h) 1.0 101 0.0
		push-draw IMGUID-Rect title x y (x + w) (y + IMGUI-HEADER-H) 1.0 102 0.0
		push-draw IMGUID-Text title (x + IMGUI-PADDING) (y + 4.0) 0.0 0.0 0.0 201 0.0
		yes
	]

	end: does [
		ctx/current-window: 0
	]

	same-line: func [
		offset-from-start-x [float!]
		spacing			  [float!]
		/local
			win	[imgui-window!]
			gap [float!]
	][
		if zero? ctx/current-window [exit]
		win: window-at ctx/current-window
		gap: either spacing < 0.0 [IMGUI-SPACING][spacing]
		either offset-from-start-x > 0.0 [
			win/cursor-x: win/content-x + offset-from-start-x
		][
			win/cursor-x: win/last-x + win/last-w + gap
		]
		win/cursor-y: win/last-y
	]

	text: func [
		label [c-string!]
		/local
			win	 [imgui-window!]
			item [imgui-item!]
			w	 [float!]
		][
			if zero? ctx/current-window [exit]
			win: window-at ctx/current-window
			w: as float! c-string-len label
			w: w * 8.0
			item: make-item IMGUIT-Text label win/cursor-x win/cursor-y w IMGUI-TEXT-H
			push-draw IMGUID-Text label item/x item/y 0.0 0.0 0.0 202 0.0
			advance-cursor win item/x item/y item/w item/h
		]

	button: func [
		label	[c-string!]
		w		[float!]
		h		[float!]
		return: [logic!]
		/local
			win		[imgui-window!]
			item	[imgui-item!]
			bw		[float!]
			bh		[float!]
			color	[integer!]
			focused? [logic!]
		][
			if zero? ctx/current-window [return no]
			win: window-at ctx/current-window
			bw: either w > 0.0 [
				w
			][
				bw: as float! c-string-len label
				(bw * 8.0) + 20.0
			]
			bh: either h > 0.0 [h][IMGUI-BUTTON-H]
			item: make-item IMGUIT-Button label win/cursor-x win/cursor-y bw bh
			focused?: register-focusable
			color: either item/hovered? <> 0 [302][301]
			push-draw IMGUID-Rect label item/x item/y (item/x + item/w) (item/y + item/h) 1.0 color 0.0
			if focused? [
				push-draw IMGUID-Rect label (item/x - 2.0) (item/y - 2.0) (item/x + item/w + 2.0) (item/y + item/h + 2.0) 1.0 601 0.0
			]
			push-draw IMGUID-Text label (item/x + 8.0) (item/y + 4.0) 0.0 0.0 0.0 203 0.0
			advance-cursor win item/x item/y item/w item/h
			any [
				all [
					item/hovered? <> 0
					ctx/mouse-pressed? <> 0
				]
				all [
					focused?
					ctx/key-activate? <> 0
				]
			]
		]

	checkbox: func [
		label	[c-string!]
		value	[int-ptr!]
		return: [logic!]
		/local
			win		[imgui-window!]
			item	[imgui-item!]
			size	[float!]
			item-w	[float!]
			changed? [logic!]
			focused? [logic!]
	][
			if zero? ctx/current-window [return no]
			win: window-at ctx/current-window
			size: IMGUI-CHECKBOX-SIZE
			item-w: as float! c-string-len label
			item-w: (item-w * 8.0) + 8.0 + size
			item: make-item
				IMGUIT-Checkbox
				label
				win/cursor-x
					win/cursor-y
					item-w
					size
			focused?: register-focusable
			item/value-i: value/value
			changed?: any [
				all [
					item/hovered? <> 0
					ctx/mouse-pressed? <> 0
				]
				all [
					focused?
					ctx/key-activate? <> 0
				]
			]
			if changed? [
				value/value: either zero? value/value [1][0]
				item/value-i: value/value
			]
			push-draw IMGUID-Rect label item/x item/y (item/x + size) (item/y + size) 1.0 401 0.0
			if focused? [
				push-draw IMGUID-Rect label (item/x - 2.0) (item/y - 2.0) (item/x + size + 2.0) (item/y + size + 2.0) 1.0 601 0.0
			]
			if item/value-i <> 0 [
				push-draw IMGUID-Line label (item/x + 3.0) (item/y + 9.0) (item/x + 7.0) (item/y + 14.0) 2.0 402 0.0
				push-draw IMGUID-Line label (item/x + 7.0) (item/y + 14.0) (item/x + 15.0) (item/y + 4.0) 2.0 402 0.0
			]
			push-draw IMGUID-Text label (item/x + size + 8.0) item/y 0.0 0.0 0.0 204 0.0
			advance-cursor win item/x item/y item/w item/h
			changed?
	]

	slider-float: func [
		label	[c-string!]
		value	[float-ptr!]
		minv	[float!]
		maxv	[float!]
		w		[float!]
		return: [logic!]
		/local
			win		[imgui-window!]
			item	[imgui-item!]
			sw		[float!]
			t		[float!]
			next	[float!]
			changed? [logic!]
			focused? [logic!]
			step	[float!]
	][
		if zero? ctx/current-window [return no]
			win: window-at ctx/current-window
			sw: either w > 0.0 [w][IMGUI-SLIDER-W]
			item: make-item IMGUIT-SliderFloat label win/cursor-x win/cursor-y sw IMGUI-BUTTON-H
			focused?: register-focusable
			item/value-f: value/value
			changed?: no
		if all [
			item/hovered? <> 0
			ctx/mouse-down? <> 0
		][
			t: clampf ((ctx/mouse-x - item/x) / sw) 0.0 1.0
			next: minv + ((maxv - minv) * t)
			if next <> value/value [
				value/value: next
				item/value-f: next
					changed?: yes
				]
			]
			if focused? [
				step: (maxv - minv) / 20.0
				if ctx/key-left? <> 0 [
					next: clampf (value/value - step) minv maxv
					if next <> value/value [
						value/value: next
						item/value-f: next
						changed?: yes
					]
				]
				if ctx/key-right? <> 0 [
					next: clampf (value/value + step) minv maxv
					if next <> value/value [
						value/value: next
						item/value-f: next
						changed?: yes
					]
				]
			]
			push-draw IMGUID-Rect label item/x item/y (item/x + item/w) (item/y + item/h) 1.0 501 0.0
			if focused? [
				push-draw IMGUID-Rect label (item/x - 2.0) (item/y - 2.0) (item/x + item/w + 2.0) (item/y + item/h + 2.0) 1.0 601 0.0
			]
			t: clampf ((value/value - minv) / (maxv - minv)) 0.0 1.0
		push-draw IMGUID-Rect label item/x item/y (item/x + (item/w * t)) (item/y + item/h) 1.0 502 t
		push-draw IMGUID-Text label (item/x + item/w + 8.0) item/y 0.0 0.0 0.0 205 value/value
		advance-cursor win item/x item/y item/w item/h
		changed?
	]

	item-count?: func [return: [integer!]][ctx/item-count]
	draw-count?: func [return: [integer!]][ctx/draw-count]

	item-kind-at: func [
		index [integer!]
		return: [integer!]
		/local item [imgui-item!]
	][
		if any [index < 1 index > ctx/item-count] [return IMGUIT-None]
		item: item-at index
		item/kind
	]

	item-label-at: func [
		index [integer!]
		return: [c-string!]
		/local item [imgui-item!]
	][
		if any [index < 1 index > ctx/item-count] [return null]
		item: item-at index
		item/label
	]

	draw-kind-at: func [
		index [integer!]
		return: [integer!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return IMGUID-None]
		draw: draw-at index
		draw/kind
	]

	draw-label-at: func [
		index [integer!]
		return: [c-string!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return null]
		draw: draw-at index
		draw/label
	]

	draw-color-at: func [
		index [integer!]
		return: [integer!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0]
		draw: draw-at index
		draw/color
	]

	draw-value-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/value-f
	]

	draw-thickness-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/thickness
	]

	draw-x1-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/x1
	]

	draw-y1-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/y1
	]

	draw-x2-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/x2
	]

	draw-y2-at: func [
		index [integer!]
		return: [float!]
		/local draw [imgui-draw-cmd!]
	][
		if any [index < 1 index > ctx/draw-count] [return 0.0]
		draw: draw-at index
		draw/y2
	]

	draw-max-x: func [
		return: [float!]
		/local
			i [integer!]
			v [float!]
			maxv [float!]
			draw [imgui-draw-cmd!]
	][
		i: 1
		maxv: 0.0
		while [i <= ctx/draw-count][
			draw: draw-at i
			v: draw-x2-at i
			if v > maxv [maxv: v]
			v: draw-x1-at i
			if v > maxv [maxv: v]
			if draw/kind = IMGUID-Text [
				v: as float! c-string-len draw/label
				v: draw/x1 + (v * 6.0) + 3.0
				if v > maxv [maxv: v]
			]
			i: i + 1
		]
		maxv
	]

	draw-max-y: func [
		return: [float!]
		/local
			i [integer!]
			v [float!]
			maxv [float!]
			draw [imgui-draw-cmd!]
	][
		i: 1
		maxv: 0.0
		while [i <= ctx/draw-count][
			draw: draw-at i
			v: draw-y2-at i
			if v > maxv [maxv: v]
			v: draw-y1-at i
			if v > maxv [maxv: v]
			if draw/kind = IMGUID-Text [
				v: draw/y1 + 5.0
				if v > maxv [maxv: v]
			]
			i: i + 1
		]
		maxv
	]

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

	build-draw-data: func [
		return: [imdraw-data!]
		/local
			i [integer!]
			kind [integer!]
			color-id [integer!]
			label [c-string!]
			x1 [float!]
			y1 [float!]
			x2 [float!]
			y2 [float!]
			thickness [float!]
			r [byte!]
			g [byte!]
			b [byte!]
			a [byte!]
			batch-start [integer!]
			batch-textured? [logic!]
			next-textured? [logic!]
			cell-x [integer!]
			cell-y [integer!]
			u0 [float!]
			v0f [float!]
			u1 [float!]
			v1 [float!]
			dx [float!]
			dy [float!]
			ax [float!]
			ay [float!]
			scale [float!]
			nx [float!]
			ny [float!]
			half [float!]
			p [byte-ptr!]
			ch [integer!]
			base [integer!]
			idxoff [integer!]
			cmd [imdraw-cmd!]
			prev-cmd [imdraw-cmd!]
			list [imdraw-list!]
			vt [imdraw-vert!]
			src [imgui-draw-cmd!]
			clip-win [imgui-window!]
			batch-window [integer!]
			seg [integer!]
			xa [float!]
			xb [float!]
			ya [float!]
			yb [float!]
	][
		draw-list/vtx-count: 0
		draw-list/idx-count: 0
		draw-list/cmd-count: 0
		draw-data/cmd-lists: 0
		batch-start: 0
		batch-textured?: no
		batch-window: 0
		i: 1
		while [i <= ctx/draw-count][
			src: draw-at i
			kind: src/kind
			next-textured?: kind = IMGUID-Text
			if draw-list/idx-count = batch-start [
				batch-textured?: next-textured?
				batch-window: src/window-id
			]
			if all [
				draw-list/idx-count > batch-start
				any [
					next-textured? <> batch-textured?
					src/window-id <> batch-window
				]
			][
				cmd: mesh-cmd-at draw-list/cmd-count
				cmd/texture-id: either batch-textured? [1][0]
				cmd/idx-offset: batch-start
				cmd/vtx-offset: 0
				cmd/elem-count: draw-list/idx-count - batch-start
					either positive? batch-window [
						clip-win: window-at batch-window
						cmd/clip-x1: clip-win/content-x
						cmd/clip-y1: clip-win/content-y
						cmd/clip-x2: (clip-win/x + clip-win/w) - IMGUI-PADDING
						cmd/clip-y2: (clip-win/y + clip-win/h) - IMGUI-PADDING
				][
					cmd/clip-x1: 0.0
					cmd/clip-y1: 0.0
					cmd/clip-x2: draw-max-x
					cmd/clip-y2: draw-max-y
				]
				draw-list/cmd-count: draw-list/cmd-count + 1
				batch-start: draw-list/idx-count
				batch-textured?: next-textured?
				batch-window: src/window-id
			]
			color-id: src/color
			x1: src/x1
			y1: src/y1
			x2: src/x2
			y2: src/y2
			label: src/label
			thickness: src/thickness
			r: null-byte g: null-byte b: null-byte a: null-byte
			resolve-color color-id :r :g :b :a
			u0: 0.5
			u0: u0 / as float! IMGUI-FONT-ATLAS-W
			v0f: 0.5
			v0f: v0f / as float! IMGUI-FONT-ATLAS-H
			switch kind [
				IMGUID-Rect [
					seg: either any [color-id = 102 color-id = 502] [1][4]
					while [seg > 0][
						case [
							seg = 4 [xa: x1 xb: x2 ya: y1 yb: y1 + 1.0]
							seg = 3 [xa: x1 xb: x2 ya: y2 - 1.0 yb: y2]
							seg = 2 [xa: x1 xb: x1 + 1.0 ya: y1 + 1.0 yb: y2 - 1.0]
							seg = 1 [xa: either seg = 1 [either any [color-id = 102 color-id = 502] [x1][x2 - 1.0]][x1] xb: either any [color-id = 102 color-id = 502] [x2][x2] ya: either any [color-id = 102 color-id = 502] [y1][y1 + 1.0] yb: either any [color-id = 102 color-id = 502] [y2][y2 - 1.0]]
						]
						base: draw-list/vtx-count
						vt: mesh-vert-at base     vt/pos-x: xa vt/pos-y: ya vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
						vt: mesh-vert-at (base + 1) vt/pos-x: xb vt/pos-y: ya vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
						vt: mesh-vert-at (base + 2) vt/pos-x: xb vt/pos-y: yb vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
						vt: mesh-vert-at (base + 3) vt/pos-x: xa vt/pos-y: yb vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
						idxoff: draw-list/idx-count + 1
						mesh-indices/idxoff: base
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 1
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 2
							idxoff: idxoff + 1
							mesh-indices/idxoff: base
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 2
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 3
							draw-list/vtx-count: draw-list/vtx-count + 4
							draw-list/idx-count: draw-list/idx-count + 6
							either any [color-id = 102 color-id = 502] [seg: 0][seg: seg - 1]
					]
				]
				IMGUID-Line [
					if thickness < 1.0 [thickness: 1.0]
					dx: x2 - x1
					dy: y2 - y1
					ax: either dx < 0.0 [0.0 - dx][dx]
					ay: either dy < 0.0 [0.0 - dy][dy]
					scale: either ax > ay [ax][ay]
					if scale < 1.0 [scale: 1.0]
					half: thickness / 2.0
					nx: (0.0 - dy) * (half / scale)
					ny: dx * (half / scale)
					base: draw-list/vtx-count
					vt: mesh-vert-at base     vt/pos-x: x1 + nx vt/pos-y: y1 + ny vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
					vt: mesh-vert-at (base + 1) vt/pos-x: x2 + nx vt/pos-y: y2 + ny vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
					vt: mesh-vert-at (base + 2) vt/pos-x: x2 - nx vt/pos-y: y2 - ny vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
					vt: mesh-vert-at (base + 3) vt/pos-x: x1 - nx vt/pos-y: y1 - ny vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
					idxoff: draw-list/idx-count + 1
					mesh-indices/idxoff: base
					idxoff: idxoff + 1
					mesh-indices/idxoff: base + 1
					idxoff: idxoff + 1
					mesh-indices/idxoff: base + 2
					idxoff: idxoff + 1
					mesh-indices/idxoff: base
					idxoff: idxoff + 1
					mesh-indices/idxoff: base + 2
					idxoff: idxoff + 1
					mesh-indices/idxoff: base + 3
					draw-list/vtx-count: draw-list/vtx-count + 4
					draw-list/idx-count: draw-list/idx-count + 6
				]
				IMGUID-Text [
					p: as byte-ptr! label
					while [p/1 <> null-byte][
						ch: as integer! p/1
						if all [ch >= 97 ch <= 122][ch: ch - 32]
						if ch <> 32 [
							cell-x: ((ch - 32) % 16) * 8
							cell-y: ((ch - 32) / 16) * 8 + 8
							u0: as float! cell-x
							u0: u0 / as float! IMGUI-FONT-ATLAS-W
							v0f: as float! cell-y
							v0f: v0f / as float! IMGUI-FONT-ATLAS-H
							u1: as float! (cell-x + 5)
							u1: u1 / as float! IMGUI-FONT-ATLAS-W
							v1: as float! (cell-y + 7)
							v1: v1 / as float! IMGUI-FONT-ATLAS-H
							base: draw-list/vtx-count
							vt: mesh-vert-at base     vt/pos-x: x1       vt/pos-y: y1       vt/uv-x: u0 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
							vt: mesh-vert-at (base + 1) vt/pos-x: x1 + 5.0 vt/pos-y: y1       vt/uv-x: u1 vt/uv-y: v0f vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
							vt: mesh-vert-at (base + 2) vt/pos-x: x1 + 5.0 vt/pos-y: y1 + 7.0 vt/uv-x: u1 vt/uv-y: v1  vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
							vt: mesh-vert-at (base + 3) vt/pos-x: x1       vt/pos-y: y1 + 7.0 vt/uv-x: u0 vt/uv-y: v1  vt/col-r: r vt/col-g: g vt/col-b: b vt/col-a: a
							idxoff: draw-list/idx-count + 1
							mesh-indices/idxoff: base
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 1
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 2
							idxoff: idxoff + 1
							mesh-indices/idxoff: base
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 2
							idxoff: idxoff + 1
							mesh-indices/idxoff: base + 3
							draw-list/vtx-count: draw-list/vtx-count + 4
							draw-list/idx-count: draw-list/idx-count + 6
						]
						x1: x1 + 6.0
						p: p + 1
					]
				]
			]
			i: i + 1
		]
		if draw-list/idx-count > batch-start [
			cmd: mesh-cmd-at draw-list/cmd-count
			cmd/texture-id: either batch-textured? [1][0]
			cmd/idx-offset: batch-start
			cmd/vtx-offset: 0
			cmd/elem-count: draw-list/idx-count - batch-start
			either positive? batch-window [
				clip-win: window-at batch-window
				cmd/clip-x1: clip-win/content-x
				cmd/clip-y1: clip-win/content-y
				cmd/clip-x2: (clip-win/x + clip-win/w) - IMGUI-PADDING
				cmd/clip-y2: (clip-win/y + clip-win/h) - IMGUI-PADDING
			][
				cmd/clip-x1: 0.0
				cmd/clip-y1: 0.0
				cmd/clip-x2: draw-max-x
				cmd/clip-y2: draw-max-y
			]
			draw-list/cmd-count: draw-list/cmd-count + 1
		]
			if draw-list/cmd-count > 0 [
				i: 0
				while [i < draw-list/cmd-count][
					cmd: mesh-cmd-at i
					if positive? i [prev-cmd: mesh-cmd-at (i - 1)]
					either any [
						zero? draw-data/cmd-lists
						any [
							all [positive? i cmd/clip-x1 <> prev-cmd/clip-x1]
							all [positive? i cmd/clip-y1 <> prev-cmd/clip-y1]
							all [positive? i cmd/clip-x2 <> prev-cmd/clip-x2]
							all [positive? i cmd/clip-y2 <> prev-cmd/clip-y2]
						]
					][
					list: mesh-list-at draw-data/cmd-lists
					list/cmd-offset: i
					list/idx-offset: cmd/idx-offset
					list/vtx-offset: cmd/vtx-offset
					list/cmd-count: 1
					list/idx-count: cmd/elem-count
					list/vtx-count: 0
					draw-data/cmd-lists: draw-data/cmd-lists + 1
				][
					list: mesh-list-at (draw-data/cmd-lists - 1)
					list/cmd-count: list/cmd-count + 1
					list/idx-count: list/idx-count + cmd/elem-count
				]
				i: i + 1
			]
		]
		draw-data/valid?: 1
		draw-data/display-x: 0.0
		draw-data/display-y: 0.0
		draw-data/display-w: draw-max-x
		draw-data/display-h: draw-max-y
		draw-data/total-vtx: draw-list/vtx-count
		draw-data/total-idx: draw-list/idx-count
		draw-data
	]

	mesh-vtx-count?: func [return: [integer!]][draw-list/vtx-count]
	mesh-idx-count?: func [return: [integer!]][draw-list/idx-count]
	mesh-cmd-count?: func [return: [integer!]][draw-list/cmd-count]
	mesh-list-count?: func [return: [integer!]][draw-data/cmd-lists]
	mesh-vert: func [index [integer!] return: [imdraw-vert!]][mesh-vert-at index]
	mesh-cmd: func [index [integer!] return: [imdraw-cmd!]][mesh-cmd-at index]
	mesh-list: func [index [integer!] return: [imdraw-list!]][mesh-list-at index]
	mesh-index: func [
		index [integer!]
		return: [integer!]
		/local idx [integer!]
	][
		idx: index + 1
		mesh-indices/idx
	]
]
