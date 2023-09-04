Red/System [
	Title:	"Events handling"
	Author: "Xie Qingtian"
	File: 	%events.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#define SPECIAL_KEY?(cp) [cp and 80000000h <> 0]
#define MARK_SPECIAL_KEY(cp) [cp: cp or 80000000h]

#enum event-action! [
	EVT_DISPATCH
	EVT_NO_DISPATCH										;-- no further msg processing allowed
]

flags-blk: declare red-block!							;-- static block value for event/flags
flags-blk/header:	TYPE_UNSET
flags-blk/head:		0
flags-blk/node:		alloc-cells 4
flags-blk/header:	TYPE_BLOCK

mouse-x:		as float32! 0
mouse-y:		as float32! 0

map-pt-from-win: func [
	g		[widget!]
	x		[float32!]
	y		[float32!]
	xx		[float32-ptr!]
	yy		[float32-ptr!]
	/local
		a	[float32!]
		b	[float32!]
][
	a: g/box/left
	b: g/box/top
	if g/parent <> null [
		g: g/parent
		while [g/parent <> null][
			a: a + g/box/left
			b: b + g/box/top
			g: g/parent
		]
	]
	xx/value: x - a
	yy/value: y - b
]

get-event-window: func [
	evt		[red-event!]
	return: [red-value!]
][
	null
]

get-event-face: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		widget-evt [widget-event!]
		g		[widget!]
][
	widget-evt: as widget-event! evt/msg
	g: widget-evt/widget
	assert g/face <> 0
	copy-cell as cell! :g/face stack/push*
]

get-event-offset: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		widget-evt [widget-event!]
][
	widget-evt: as widget-event! evt/msg
	as red-value! pair/push as-integer widget-evt/pt/x as-integer widget-evt/pt/y
]

get-event-key: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		widget-evt [widget-event!]
][
	widget-evt: as widget-event! evt/msg
	as red-value! either zero? evt/flags [
		char/push widget-evt/data
	][
		switch evt/flags [
			RED_VK_PRIOR	[_page-up]
			RED_VK_NEXT		[_page-down]
			RED_VK_END		[_end]
			RED_VK_HOME		[_home]
			RED_VK_LEFT		[_left]
			RED_VK_UP		[_up]
			RED_VK_RIGHT	[_right]
			RED_VK_DOWN		[_down]
			RED_VK_INSERT	[_insert]
			RED_VK_DELETE	[_delete]
			RED_VK_F1		[_F1]
			RED_VK_F2		[_F2]
			RED_VK_F3		[_F3]
			RED_VK_F4		[_F4]
			RED_VK_F5		[_F5]
			RED_VK_F6		[_F6]
			RED_VK_F7		[_F7]
			RED_VK_F8		[_F8]
			RED_VK_F9		[_F9]
			RED_VK_F10		[_F10]
			RED_VK_F11		[_F11]
			RED_VK_F12		[_F12]
			RED_VK_LSHIFT	[_left-shift]
			RED_VK_RSHIFT	[_right-shift]
			RED_VK_LCONTROL	[_left-control]
			RED_VK_RCONTROL	[_right-control]
			RED_VK_CAPITAL	[_caps-lock]
			RED_VK_NUMLOCK	[_num-lock]
			RED_VK_LMENU	[_left-alt]
			RED_VK_RMENU	[_right-alt]
			RED_VK_LWIN		[_left-command]
			RED_VK_APPS		[_right-command]
			RED_VK_SCROLL	[_scroll-lock]
			RED_VK_PAUSE	[_pause]
			default			[null]
		]
	]
]

get-event-orientation: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! none-value
]

get-event-picked: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		e	[widget-event!]
][
	e: as widget-event! evt/msg
	as red-value! switch evt/type [
		EVT_WHEEL [float/push as float! e/fdata]
		default	  [integer/push e/data]
	]
]

get-event-flags: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		blk [red-block!]
][
	blk: flags-blk
	block/rs-clear blk	
	if evt/flags and EVT_FLAG_AWAY		 <> 0 [block/rs-append blk as red-value! _away]
	if evt/flags and EVT_FLAG_DOWN		 <> 0 [block/rs-append blk as red-value! _down]
	if evt/flags and EVT_FLAG_MID_DOWN	 <> 0 [block/rs-append blk as red-value! _mid-down]
	if evt/flags and EVT_FLAG_ALT_DOWN	 <> 0 [block/rs-append blk as red-value! _alt-down]
	if evt/flags and EVT_FLAG_AUX_DOWN	 <> 0 [block/rs-append blk as red-value! _aux-down]
	if evt/flags and EVT_FLAG_CTRL_DOWN	 <> 0 [block/rs-append blk as red-value! _control]
	if evt/flags and EVT_FLAG_SHIFT_DOWN <> 0 [block/rs-append blk as red-value! _shift]
	if evt/flags and EVT_FLAG_MENU_DOWN  <> 0 [block/rs-append blk as red-value! _alt]
	as red-value! blk
]

get-event-flag: func [
	flags	[integer!]
	flag	[integer!]
	return: [red-value!]
][
	as red-value! logic/push flags and flag <> 0
]

make-event: func [
	evt			[integer!]
	widget-evt	[widget-event!]
	flags		[integer!]
	return:		[integer!]
	/local
		res		[red-word!]
		word	[red-word!]
		sym		[integer!]
		state	[integer!]
		gui-evt	[red-event! value]
		t?		[logic!]
][
	gui-evt/header: TYPE_EVENT
	gui-evt/msg:    as byte-ptr! widget-evt
	gui-evt/flags:  flags
	gui-evt/type:   evt

	state: EVT_DISPATCH

	stack/mark-try-all words/_anon
	res: as red-word! stack/arguments

	t?: interpreter/tracing?
	interpreter/tracing?: no
	catch CATCH_ALL_EXCEPTIONS [
		#call [system/view/awake :gui-evt]
		stack/unwind
	]
	interpreter/tracing?: t?
	
	stack/adjust-post-try
	if system/thrown <> 0 [system/thrown: 0]

	if TYPE_OF(res) = TYPE_WORD [
		sym: symbol/resolve res/symbol
		if sym = done [state: EVT_NO_DISPATCH]		;-- pass event to widget
	]
	state
]

make-red-event: func [
	evt		[integer!]
	obj		[widget!]
	flags	[integer!]
	return: [integer!]
	/local
		w-evt	[widget-event! value]
		ret		[integer!]
][
	ret: EVT_DISPATCH
	if obj/flags and WIDGET_FLAG_DISABLE = 0 [
		w-evt/widget: obj
		if 0 <> obj/face [
			ret: make-event evt :w-evt flags
		]
	]
	ret
]

send-mouse-event: func [
	evt		[integer!]
	obj		[widget!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	return: [integer!]
	/local
		g-evt	[widget-event! value]
		ret		[integer!]
][
	ret: EVT_DISPATCH
	if obj/flags and WIDGET_FLAG_DISABLE = 0 [
		g-evt/pt/x: x
		g-evt/pt/y: y
		g-evt/widget: obj
		if 0 <> obj/face [
			ret: make-event evt :g-evt flags
		]
	]
	ret
]

next-focused-widget: func [
	/local
		win		[widget!]
		blk		[red-block!]
		len		[integer!]
		i ii	[integer!]
		w		[widget!]
		wm		[window-manager!]
][
	WIDGET_UNSET_FLAG(screen/focus-widget WIDGET_FLAG_FOCUS)
	wm: screen/active-win
	win: wm/window
	blk: CHILD_WIDGET(win)
	screen/focus-widget: win
	if all [
		TYPE_OF(blk) = TYPE_BLOCK
		0 < block/rs-length? blk
	][
		len: block/rs-length? blk
		i: wm/focused-idx
		ii: i
		until [
			i: i % len
			w: as widget! get-face-handle as red-object! (block/rs-head blk) + i
			i: i + 1 % len
			any [WIDGET_FOCUSABLE?(w) i = ii]
		]
		wm/focused-idx: i
		wm/focused: w
		screen/focus-widget: w
	]
	WIDGET_SET_FLAG(screen/focus-widget WIDGET_FLAG_FOCUS)
]

send-key-event: func [
	obj		[widget!]
	char	[integer!]
	flags	[integer!]
	/local
		g-evt	[widget-event! value]
][
	if char = as-integer #"^-" [	;-- tab key
		next-focused-widget
		screen/redraw
	]

	if null? obj [
		obj: screen/focus-widget
	]
	if obj/flags and WIDGET_FLAG_DISABLE = 0 [
		if flags <> 0 [
			char: flags
			MARK_SPECIAL_KEY(char)
		]
		if zero? char [exit]
		g-evt/data: char
		g-evt/widget: obj
		obj/on-event EVT_KEY :g-evt
		make-event EVT_KEY :g-evt flags
	]
]

send-pt-event: func [
	evt		[integer!]
	obj		[widget!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
][
	send-mouse-event evt obj x y flags
]

hover-changed?: func [
	widget-1	[widget!]
	widget-2	[widget!]
	return: [logic!]
	/local
		g	[widget!]
		leave? [logic!]
][
	leave?: no
	g: widget-1
	until [
		g: g/parent
		if g = widget-2 [leave?: yes break]
		null? g
	]
	any [
		leave?
		widget-1/parent = widget-2/parent		;-- overlapped sibling widgets
	]
]

child?: func [
	child	[widget!]
	parent	[widget!]
	return: [logic!]
][
	while [child <> null][
		child: child/parent
		if child = parent [return true]
	]
	false
]

send-captured-event: func [
	evt		[integer!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	filter	[integer!]
	/local
		captured [widget!]
][
	captured: screen/captured-widget
	if all [
		captured <> null
		captured/flags and WIDGET_FLAG_AWAY <> 0
		any [filter = -1 captured/flags and filter <> 0]
	][
		map-pt-from-win captured x y :x :y
		send-mouse-event evt captured x y flags
	]
]

do-mouse-move: func [
	evt		[integer!]
	obj		[widget!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	root?	[logic!]
	return: [integer!]
	/local
		child	[widget!]
		ret		[integer!]
		hover	[widget!]
][
	ret: EVT_DISPATCH

	if null? screen/hover-widget [					;-- mouse enter a new window
		send-mouse-event evt obj x y flags
	]

	child: _widget/find-child obj x y
	either child <> null [
		;screen/add-update obj
		ret: do-mouse-move evt child x - child/box/left y - child/box/top flags no
	][
		hover: screen/hover-widget
		if hover <> obj [
			if hover <> null [
				if hover-changed? hover obj [
					if screen/captured-widget = hover [
						WIDGET_SET_FLAG(hover WIDGET_FLAG_AWAY)
					]
					send-mouse-event
						evt
						hover
						mouse-x
						mouse-y
						flags or EVT_FLAG_AWAY
				]
				if hover-changed? obj hover [
					WIDGET_UNSET_FLAG(obj WIDGET_FLAG_AWAY)
					send-mouse-event evt obj x y flags
				]
			]
			screen/hover-widget: obj
		]
		mouse-x: x
		mouse-y: y
	]
	if all [
		obj/flags and WIDGET_FLAG_ALL_OVER <> 0
		ret = EVT_DISPATCH 
	][
		ret: send-mouse-event evt obj x y flags
	]
	if root? [send-captured-event evt x y flags WIDGET_FLAG_ALL_OVER]
	ret
]

_do-mouse-press: func [
	evt		[integer!]
	obj		[widget!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	return: [integer!]		;-- high-word: return value of click event
	/local
		gb	[widget!]
		r0	[integer!]
		r1	[integer!]
		r2	[integer!]
][
	r0: EVT_DISPATCH

	gb: _widget/find-child obj x y
	if gb <> null [
		r0: _do-mouse-press evt gb x - gb/box/left y - gb/box/top flags
	]
	if r0 and FFFFh = EVT_DISPATCH [
		r1: send-mouse-event evt obj x y flags
	]
	switch evt [
		EVT_LEFT_DOWN [
			array/append-ptr screen/captured as int-ptr! obj
		]
		EVT_LEFT_UP [
			if all [
				r0 >>> 16 = EVT_DISPATCH
				-1 <> array/find-ptr screen/captured as int-ptr! obj
			][
				r2: send-mouse-event EVT_CLICK obj x y flags
			]
		]
		default [0]
	]
	r2 << 16 or r1
]

do-mouse-press: func [
	evt		[integer!]
	obj		[widget!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
][
	if evt = EVT_LEFT_DOWN [screen/captured-widget: screen/hover-widget]
	_do-mouse-press evt obj x y flags
	if evt = EVT_LEFT_UP [
		send-captured-event evt x y flags -1
		screen/captured-widget: null
		array/clear screen/captured
	]
]

do-mouse-wheel: func [
	dir		[integer!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	/local
		evt [widget-event! value]
		w	[widget!]
][
	w: screen/hover-widget
	if all [
		w <> null
		0 <> w/face
		w/flags and WIDGET_FLAG_DISABLE = 0
	][
		evt/fdata: as float32! dir
		evt/pt/x: x
		evt/pt/y: y
		evt/widget: w
		make-event EVT_WHEEL :evt flags
	]
]

exit-loop?: no

post-quit-msg: does [
	exit-loop?: yes
]

do-events: func [
	no-wait? [logic!]
	return:  [logic!]
	/local
		msg?  [logic!]
		n	  [integer!]
][
	LOG_MSG("----------------------------")
	if all [
		not no-wait?
		1 < screen/windows-cnt
	][return no]

	tty/init
	exit-loop?: no

	until [
		n: tty/read-input
		msg?: n > 0
		if all [no-wait? not msg?][break]

		screen/render
		tty/wait 30
		ansi-parser/parse
		any [no-wait? exit-loop?]
	]
	unless no-wait? [tty/restore]
	msg?
]