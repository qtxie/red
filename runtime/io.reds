Red/System [
	Title:	"I/O facilities"
	Author: "Xie Qingtian"
	File: 	%io.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#enum io-event-type! [
	IO_EVT_NONE:	100
	IO_EVT_ACCEPT
	IO_EVT_CONNECT
	IO_EVT_READ
	IO_EVT_WROTE
	IO_EVT_CLOSE
	;-- more IO Events
	;-- IO_EVT...
]

#include %platform/io.reds
#include %devices/devices.reds

g-iocp: as iocp! 0			;-- global I/O completion port

io: context [

	get-port-event: func [
		type	[integer!]
		return: [red-value!]
	][
		as red-value! switch type [
			IO_EVT_ACCEPT	[words/_accept]
			IO_EVT_CONNECT	[words/_connect]
			IO_EVT_READ		[words/_read]
			IO_EVT_WROTE	[words/_wrote]
			IO_EVT_CLOSE	[words/_close]
		]
	]

	call-awake: func [
		red-port	[red-object!]
		msg			[red-object!]
		op			[io-event-type!]
		/local
			values	 [red-value!]
			awake	 [red-function!]
	][
		values: object/get-values red-port
		awake: as red-function! values + port/field-awake
		stack/mark-func words/_awake awake/ctx
		;-- call port/awake: func [port type][]
		stack/push as red-value! msg	;-- port
		stack/push get-port-event op	;-- type
		port/call-function awake awake/ctx
		stack/reset
	]

	init: does [
		devices/init
	]
]