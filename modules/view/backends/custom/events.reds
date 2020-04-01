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
	g		[gob!]
	x		[float32!]
	y		[float32!]
	xx		[float32-ptr!]
	yy		[float32-ptr!]
	/local
		a	[float32!]
		b	[float32!]
][
	a: g/cbox/left
	b: g/cbox/top
	if g/parent <> null [
		g: g/parent
		while [g/parent <> null][
			a: a + g/cbox/left
			b: b + g/cbox/top
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
		gob-evt	[gob-event!]
		grp		[integer!]
		g		[gob!]
][
	grp: GET_EVENT_GROUP(evt)
	gob-evt: as gob-event! evt/msg
	either grp = EVT_GROUP_GOB [
		as red-value! gob/push gob-evt/gob
	][
		g: gob-evt/gob
		assert g/face <> 0
		copy-cell as cell! :g/face stack/push*
	]
]

get-event-offset: func [
	evt		[red-event!]
	return: [red-value!]
	/local
		gob-evt [gob-event!]
][
	gob-evt: as gob-event! evt/msg
	as red-value! pair/push as-integer gob-evt/pt/x as-integer gob-evt/pt/y
]

get-event-key: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! char/push evt/flags and FFFFh
]

get-event-picked: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! integer/push 1
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
	gob-evt		[gob-event!]
	flags		[integer!]
	evt-grp		[integer!]
	return:		[integer!]
	/local
		res		[red-word!]
		word	[red-word!]
		sym		[integer!]
		state	[integer!]
		gui-evt	[red-event! value]
][
	gui-evt/header: TYPE_EVENT
	gui-evt/msg:   as byte-ptr! gob-evt
	gui-evt/flags: flags
	SET_EVENT_TYPE(gui-evt evt-grp evt)

	state: EVT_DISPATCH

	stack/mark-try-all words/_anon
	res: as red-word! stack/arguments
	catch CATCH_ALL_EXCEPTIONS [
		either evt-grp = EVT_GROUP_GOB [
			#call [system/view/awake-gob :gui-evt]
		][
			#call [system/view/awake :gui-evt]
		]
		stack/unwind
	]
	stack/adjust-post-try
	if system/thrown <> 0 [system/thrown: 0]

	if TYPE_OF(res) = TYPE_WORD [
		sym: symbol/resolve res/symbol
		if sym = done [state: EVT_NO_DISPATCH]		;-- pass event to gob
	]
	state
]

send-mouse-event: func [
	evt		[integer!]
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	return: [integer!]
	/local
		g-evt	[gob-event! value]
		ret		[integer!]
][
	ret: EVT_DISPATCH
	if obj/flags and GOB_FLAG_DISABLE = 0 [
		g-evt/pt/x: x
		g-evt/pt/y: y
		g-evt/gob: obj
		if 0 <> obj/face [		;-- root gob of each face!
			ret: make-event evt :g-evt flags EVT_GROUP_GUI
		]
		if ret = EVT_DISPATCH [
			ret: make-event evt :g-evt flags EVT_GROUP_GOB
		]
	]
	ret
]

send-pt-event: func [
	evt		[integer!]
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
][
	send-mouse-event evt obj x y flags
]

hover-changed?: func [
	gob-1	[gob!]
	gob-2	[gob!]
	return: [logic!]
	/local
		g	[gob!]
		leave? [logic!]
][
	leave?: no
	g: gob-1
	until [
		g: g/parent
		if g = gob-2 [leave?: yes break]
		null? g
	]
	any [
		leave?
		gob-1/parent = gob-2/parent		;-- overlapped sibling gobs
	]
]

child?: func [
	child	[gob!]
	parent	[gob!]
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
		captured [gob!]
][
	captured: ui-manager/captured-gob
	if all [
		captured <> null
		captured/flags and GOB_FLAG_AWAY <> 0
		any [filter = -1 captured/flags and filter <> 0]
	][
		map-pt-from-win captured x y :x :y
		send-mouse-event evt captured x y flags
	]
]

do-mouse-move: func [
	evt		[integer!]
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	root?	[logic!]
	return: [integer!]
	/local
		child	[gob!]
		ret		[integer!]
		hover	[gob!]
][
	ret: EVT_DISPATCH

	if null? ui-manager/hover-gob [					;-- mouse enter a new window
		send-mouse-event evt obj x y flags
	]

	child: rs-gob/find-child obj x y
	either child <> null [
		;ui-manager/add-update obj
		ret: do-mouse-move evt child x - child/cbox/left y - child/cbox/top flags no
	][
		hover: ui-manager/hover-gob
		if hover <> obj [
			if hover <> null [
				if hover-changed? hover obj [
					if ui-manager/captured-gob = hover [
						GOB_SET_FLAG(hover GOB_FLAG_AWAY)
					]
					send-mouse-event
						evt
						hover
						mouse-x
						mouse-y
						flags or EVT_FLAG_AWAY
				]
				if hover-changed? obj hover [
					GOB_UNSET_FLAG(obj GOB_FLAG_AWAY)
					send-mouse-event evt obj x y flags
				]
			]
			ui-manager/hover-gob: obj
		]
		mouse-x: x
		mouse-y: y
	]
	if all [
		obj/flags and GOB_FLAG_ALL_OVER <> 0
		ret = EVT_DISPATCH 
	][
		ret: send-mouse-event evt obj x y flags
	]
	if root? [send-captured-event evt x y flags GOB_FLAG_ALL_OVER]
	ret
]

_do-mouse-press: func [
	evt		[integer!]
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
	return: [integer!]		;-- high-word: return value of click event
	/local
		gb	[gob!]
		r0	[integer!]
		r1	[integer!]
		r2	[integer!]
][
	r0: EVT_DISPATCH

	gb: rs-gob/find-child obj x y
	if gb <> null [
		r0: _do-mouse-press evt gb x - gb/cbox/left y - gb/cbox/top flags
	]
	if r0 and FFFFh = EVT_DISPATCH [
		r1: send-mouse-event evt obj x y flags
	]
	switch evt [
		EVT_LEFT_DOWN [
			array/append-ptr ui-manager/captured as int-ptr! obj
		]
		EVT_LEFT_UP [
			if all [
				r0 >>> 16 = EVT_DISPATCH
				-1 <> array/find-ptr ui-manager/captured as int-ptr! obj
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
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
][
	if evt = EVT_LEFT_DOWN [ui-manager/captured-gob: ui-manager/hover-gob]
	_do-mouse-press evt obj x y flags
	if evt = EVT_LEFT_UP [
		send-captured-event evt x y flags -1
		ui-manager/captured-gob: null
		array/clear ui-manager/captured
	]
]