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
][
	gob-evt: as gob-event! evt/msg
	as red-value! gob/push gob-evt/gob
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
	return:		[integer!]
	/local
		res		[red-word!]
		word	[red-word!]
		sym		[integer!]
		state	[integer!]
		gui-evt	[red-event! value]
][
	gui-evt/header: TYPE_EVENT
	gui-evt/type:  evt
	gui-evt/msg:   as byte-ptr! gob-evt
	gui-evt/flags: flags

	state: EVT_DISPATCH

	stack/mark-try-all words/_anon
	res: as red-word! stack/arguments
	catch CATCH_ALL_EXCEPTIONS [
		#call [system/view/awake :gui-evt]
		stack/unwind
	]
	stack/adjust-post-try
	if system/thrown <> 0 [system/thrown: 0]

	if TYPE_OF(res) = TYPE_WORD [
		sym: symbol/resolve res/symbol
		if sym = done [state: EVT_NO_DISPATCH]			;-- prevent other high-level events
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
		child	[gob!]
		g-evt	[gob-event! value]
		ret		[integer!]
][
	ret: EVT_DISPATCH
	if obj/flags and GOB_FLAG_DISABLE = 0 [
		g-evt/pt/x: x
		g-evt/pt/y: y
		g-evt/gob: obj
		ret: make-event evt :g-evt flags
	]
	ret
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

do-mouse-event: func [
	evt		[integer!]
	obj		[gob!]
	x		[float32!]
	y		[float32!]
	flags	[integer!]
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
		ui-manager/add-update obj
		ret: do-mouse-event evt child x - child/box/left y - child/box/top flags
	][
		hover: ui-manager/hover-gob
		if hover <> obj [
			if hover <> null [
				if hover-changed? hover obj [
					send-mouse-event
						evt
						hover
						mouse-x
						mouse-y
						flags or EVT_FLAG_AWAY
				]
				if hover-changed? obj hover [
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
	][ret: send-mouse-event evt obj x y flags]
	ret
]