Red/System [
	Title:	"Test events handling"
	Author: "Nenad Rakocevic"
	File: 	%events.reds
	Tabs: 	4
	Rights: "Copyright (C) 2017-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]


flags-blk: declare red-block!							;-- static block value for event/flags
flags-blk/header:	TYPE_UNSET
flags-blk/head:		0
flags-blk/node:		node-handle-of alloc-cells 4
flags-blk/header:	TYPE_BLOCK

get-event-window: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! none-value
]

get-event-face: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! none-value
]

get-event-offset: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! pair/push 10 10
]

get-event-key: func [
	evt		[red-event!]
	return: [red-value!]
][
	as red-value! char/push evt/flags and FFFFh
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
	if evt/flags and EVT_FLAG_CMD_DOWN	 <> 0 [block/rs-append blk as red-value! _command]	;-- unlike Windows/GTK: the headless
	as red-value! blk																		;-- backend reports every settable flag
]

get-event-flag: func [
	flags	[integer!]
	flag	[integer!]
	return: [red-value!]
][
	as red-value! logic/push flags and flag <> 0
]

OS-send-event: func [									;-- headless regression backend: OS injection is a no-op
	evt		[red-event!]
	queued?	[logic!]
	return:	[logic!]
][
	false
]

OS-make-event: func [
	name	[red-word!]
	face	[red-object!]
	flags	[integer!]
	return: [red-event!]
	/local
		event [red-event!]
		node  [node!]
		s	  [series!]
		pr	  [red-pair!]
		iv	  [red-integer!]
][
	event: declare red-event!
	event/header: TYPE_EVENT
	event/flags: flags or EVT_FLAG_SYNTHETIC
	set-event-type event name

	;-- Keep the test event self-contained and GC-traceable just like `make event!`.
	node: alloc-cells 4
	s: as series! node/value
	copy-cell as cell! face s/offset
	copy-cell as cell! none-value (s/offset + 1)
	pr: as red-pair! (s/offset + 2)
	pr/header: TYPE_PAIR
	pr/x: 10
	pr/y: 10
	iv: as red-integer! (s/offset + 3)
	iv/header: TYPE_INTEGER
	iv/value: 1
	s/tail: s/offset + 4
	event/msg: node-handle-of node
	
	event
]

do-events: func [
	no-wait? [logic!]
	return:  [logic!]
][
	true
]
