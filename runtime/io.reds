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
	IO_EVT_NONE:		0
	IO_EVT_ERROR:		1
	IO_EVT_READ:		2
	IO_EVT_WRITE:		4
	IO_EVT_CLOSE:		8
	IO_EVT_ACCEPT:		16
	IO_EVT_CONNECT:		32
	IO_EVT_WROTE:		64	
	IO_EVT_PULSE:		128
	;-- more IO Events
	;-- IO_EVT...
]

#include %platform/io.reds

g-iocp: as iocp! 0			;-- global I/O completion port

ports-block: as red-block! 0

io: context [

	get-event-type: func [
		evt		[red-event!]
		return: [red-value!]
	][
		probe ["get-event-type: " evt/type and FFFFh]
		as red-value! switch (evt/type and FFFFh) [
			IO_EVT_ACCEPT	[words/_accept]
			IO_EVT_CONNECT	[words/_connect]
			IO_EVT_READ		[words/_read]
			IO_EVT_WRITE	[words/_wrote]
			IO_EVT_CLOSE	[words/_close]
			IO_EVT_ERROR	[words/_error]
		]
	]

	get-event-port: func [
		evt		[red-event!]
		return: [red-value!]
	][
		as red-value! evt/msg
	]

	call-awake: func [
		red-port	[red-object!]
		msg			[red-object!]
		op			[io-event-type!]
		/local
			evt		[red-event! value]
	][
		evt/header: TYPE_EVENT
		SET_EVENT_TYPE(evt EVT_GROUP_IO op)
		evt/msg: as byte-ptr! msg

		;-- call port/awake: func [event [event!]][]
		stack/mark-func words/_awake red-port/ctx
		stack/push as red-value! :evt
		port/call-function red-port words/_awake
		stack/reset
	]

	store-iocp-data: func [
		data		[iocp-data!]
		red-port	[red-object!]
	][
		handle/make-at
			(object/get-values red-port) + port/field-state
			as-integer data
	]

	get-iocp-data: func [
		red-port	[red-object!]
		return:		[iocp-data!]
		/local
			state	[red-handle!]
	][
		state: as red-handle! (object/get-values red-port) + port/field-state
		either TYPE_OF(state) = TYPE_NONE [null][as iocp-data! state/value]
	]

	do-events: func [
		time	[integer!]		;-- milliseconds, -1: infinite time
	][
		forever [
			if zero? iocp/wait g-iocp time [exit]
			if time > -1 [exit]
		]
	]

	pin-memory: func [
		bin		[red-binary!]
		/local
			s	[series!]
	][
		s: GET_BUFFER(bin)
		s/flags: s/flags or flag-series-fixed
	]

	unpin-memory: func [
		node	[node!]
		/local
			s	[series!]
	][
		s: as series! node/value
		s/flags: s/flags and (not flag-series-fixed)
	]

	init: does [
		g-iocp: iocp/create
		ports-block: block/make-in root 16
	]
]

#include %devices/tcp.reds
