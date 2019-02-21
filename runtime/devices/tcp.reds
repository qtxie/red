Red/System [
	Title:	"low-level TCP port"
	Author: "Xie Qingtian"
	File: 	%tcp.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

tcp-scheme: context [

	tcp-data!: alias struct! [
		iocp		[iocp-data! value]
		port		[red-object! value]		;-- red port! cell
		buffer		[byte-ptr!]
	]

	event-handler: func [
		data		[iocp-data!]
		/local
			p		[red-object!]
			msg		[red-object!]
			tcp		[tcp-data!]
			type	[integer!]
			bin		[red-binary!]
	][
		tcp: as tcp-data! data
		p: as red-object! :tcp/port
		msg: p

		switch data/event [
			SOCK_EVT_ACCEPT	[
				msg: create-red-port p data/accept-sock
				type: IO_EVT_ACCEPT
			]
			SOCK_EVT_CONNECT [type: IO_EVT_CONNECT]
			SOCK_EVT_READ	[
				bin: binary/load tcp/buffer data/transferred
				copy-cell as cell! bin (object/get-values p) + port/field-data
				stack/pop 1
				type: IO_EVT_READ
			]
			SOCK_EVT_WRITE	[type: IO_EVT_WROTE]
			default			[probe ["wrong tcp event: " data/event]]
		]

		io/call-awake p msg type
	]

	create-red-port: func [
		proto		[red-object!]
		sock		[integer!]
		return:		[red-object!]
	][
		create-tcp-data proto
		port/make none-value object/get-values proto TYPE_NONE
	]

	create-tcp-data: func [
		port	[red-object!]
		return: [iocp-data!]
		/local
			data [tcp-data!]
	][
		;@@ IMPROVEMENT get tcp-data! from the cache first

		data: as tcp-data! alloc0 size? tcp-data!
		data/iocp/type: DEVICE_TCP
		data/iocp/event-handler: as iocp-event-handler! :event-handler
		copy-cell as cell! port as cell! :data/port

		;-- store low-level data into red port
		io/store-iocp-data as iocp-data! data port

		as iocp-data! data
	]

	tcp-client: func [
		port	[red-object!]
		host	[red-string!]
		num		[red-integer!]
		/local
			fd		[integer!]
			n		[integer!]
			addr	[c-string!]
			data	[tcp-data!]
	][
		if null? g-iocp [g-iocp: iocp/create]

		n: -1
		addr: unicode/to-utf8 host :n
		fd: socket/create AF_INET SOCK_STREAM IPPROTO_TCP
		socket/connect fd addr num/value AF_INET create-tcp-data port
	]

	tcp-server: func [
		port	[red-object!]
		num		[red-integer!]
		/local
			fd	[integer!]
			acp [integer!]
	][
		if null? g-iocp [g-iocp: iocp/create]

		fd: socket/create AF_INET SOCK_STREAM IPPROTO_TCP
		socket/bind fd num/value AF_INET
		socket/accept fd create-tcp-data port
	]

	;-- actions

	open: func [
		red-port	[red-object!]
		/local
			values	[red-value!]
			spec	[red-object!]
			state	[red-object!]
			host	[red-string!]
			num		[red-integer!]
	][
		values: object/get-values red-port
		state: as red-object! values + port/field-state
		num: as red-integer! (object/get-values state) + 1
		if TYPE_OF(num) <> TYPE_NONE [exit]

		spec:	as red-object! values + port/field-spec
		values: object/get-values spec
		host:	as red-string! values + 2
		num:	as red-integer! values + 3		;-- port number
		either TYPE_NONE = TYPE_OF(host) [		;-- e.g. open tcp://:8000
			tcp-server red-port num
		][
			tcp-client red-port host num
		]
	]

	init: does [
		devices/register [
			DEVICE_TCP
			"TCP"
			;-- actions
			null			;append
			null			;at
			null			;back
			null			;change
			null			;clear
			null			;copy
			null			;find
			null			;head
			null			;head?
			null			;index?
			null			;insert
			null			;length?
			null			;move
			null			;next
			null			;pick
			null			;poke
			null			;remove
			null			;reverse
			null			;select
			null			;sort
			null			;skip
			null			;tail
			null			;tail?
			null			;take
			null			;trim
			;-- I/O actions --
			null			;create
			null			;close
			null			;delete
			null			;modify
			:open
			null			;open?
			null			;query
			null			;read
			null			;rename
			null			;update
			null			;write
		]
	]
]
