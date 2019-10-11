Red/System [
	Title:	"low-level UDP port"
	Author: "Xie Qingtian"
	File: 	%udp.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

udp-device: context [
	verbose: 1

	udp-data!: alias struct! [
		iocp		[iocp-data! value]
		port		[red-object! value]		;-- red port! cell
		flags		[integer!]
		send-buf	[node!]					;-- send buffer
		addr		[sockaddr_in6!]			;-- IPv4 or IPv6 address
		addr-sz		[integer!]
	]

	event-handler: func [
		data		[iocp-data!]
		/local
			p		[red-object!]
			msg		[red-object!]
			udp		[udp-data!]
			type	[integer!]
			bin		[red-binary!]
			s		[series!]
	][
		udp: as udp-data! data
		p: as red-object! :udp/port
		msg: p
		type: data/event
probe "UDP event-handler"
		switch type [
			IO_EVT_READ	[
				bin: as red-binary! (object/get-values p) + port/field-data
				s: GET_BUFFER(bin)
				probe ["read data: " data/transferred]
				s/tail: as cell! (as byte-ptr! s/tail) + data/transferred
				io/unpin-memory bin/node
				msg: create-red-port p -1 udp/addr
				#if OS = 'Windows [
					either data/accept-sock = PENDING_IO_FLAG [
						free as byte-ptr! data
					][
						data/event: IO_EVT_NONE
					]
				]
			]
			IO_EVT_WRITE	[
				io/unpin-memory udp/send-buf
				#if OS = 'Windows [
					either data/accept-sock = PENDING_IO_FLAG [
						free as byte-ptr! data
					][
						data/event: IO_EVT_NONE
					]
				]
			]
			default [data/event: IO_EVT_NONE]
		]

		io/call-awake p msg type
	]

	create-red-port: func [
		proto		[red-object!]
		sock		[integer!]
		addr		[sockaddr_in6!]
		return:		[red-object!]
		/local
			data	[udp-data!]
	][
		proto: port/make none-value object/get-values proto TYPE_NONE

		;; @@ add it to a block, so GC can mark it. Improve it later!!!
		block/rs-append ports-block as red-value! proto

		data: as udp-data! io/create-socket-data proto sock as int-ptr! :event-handler size? udp-data!
		;#if OS <> 'Windows [data/iocp/type: SOCK_DGRAM]

		proto
	]

	create-udp-data: func [
		port	[red-object!]
		sock	[integer!]
		addr	[c-string!]
		num		[integer!]			;-- port number
		return: [udp-data!]
		/local
			data	[udp-data!]
			saddr	[sockaddr_in!]
	][
		data: as udp-data! io/create-socket-data port sock as int-ptr! :event-handler size? udp-data!
		data/iocp/type: IOCP_TYPE_UDP

		;@@ TBD add IPv6 support
		data/addr-sz: size? sockaddr_in!
		saddr: as sockaddr_in! :data/addr
		num: htons num
		saddr/sin_family: num << 16 or AF_INET
		either addr <> null [
			saddr/sin_addr: inet_addr addr
		][
			saddr/sin_addr: 0
		]
		saddr/sa_data1: 0
		saddr/sa_data2: 0
		data
	]

	get-udp-data: func [
		red-port	[red-object!]
		return:		[udp-data!]
		/local
			state	[red-handle!]
			data	[iocp-data!]
			new		[udp-data!]
	][
		state: as red-handle! (object/get-values red-port) + port/field-state
		if TYPE_OF(state) <> TYPE_HANDLE [
			probe "ERROR: No low-level handle"
			0 ;; TBD throw error
		]

		#either OS = 'Windows [
			data: as iocp-data! state/value
			either data/event = IO_EVT_NONE [		;-- we can reuse this one
				as udp-data! data
			][										;-- needs to create a new one
				new: as udp-data! alloc0 size? udp-data!
				new/iocp/event-handler: as iocp-event-handler! :event-handler
				new/iocp/device: data/device
				new/iocp/accept-sock: PENDING_IO_FLAG ;-- use it as a flag to indicate pending data
				copy-cell as cell! red-port as cell! :new/port
				new
			]
		][
			as udp-data! state/value
		]
	]

	udp-client: func [
		port	[red-object!]
		host	[red-string!]
		num		[red-integer!]
		/local
			fd		[integer!]
			n		[integer!]
			addr	[c-string!]
	][
		#if debug? = yes [if verbose > 0 [print-line "udp client"]]

		fd: socket/create AF_INET SOCK_DGRAM IPPROTO_UDP
		iocp/bind g-iocp as int-ptr! fd
		n: -1
		addr: unicode/to-utf8 host :n
		create-udp-data port fd addr num/value
	]

	udp-server: func [
		port	[red-object!]
		num		[red-integer!]
		/local
			fd	[integer!]
			acp [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "udp server"]]

		fd: socket/create AF_INET SOCK_DGRAM IPPROTO_UDP
		create-udp-data port fd null num/value
		socket/bind fd num/value AF_INET
		iocp/bind g-iocp as int-ptr! fd
	]

	;-- actions

	open: func [
		red-port	[red-object!]
		new?		[logic!]
		read?		[logic!]
		write?		[logic!]
		seek?		[logic!]
		allow		[red-value!]
		return:		[red-value!]
		/local
			values	[red-value!]
			spec	[red-object!]
			state	[red-handle!]
			host	[red-string!]
			num		[red-integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "udp/open"]]

		values: object/get-values red-port
		state: as red-handle! values + port/field-state
		if TYPE_OF(state) <> TYPE_NONE [return as red-value! red-port]

		spec:	as red-object! values + port/field-spec
		values: object/get-values spec
		host:	as red-string! values + 2
		num:	as red-integer! values + 3		;-- port number

		either zero? string/rs-length? host [	;-- e.g. open udp://:8000
			udp-server red-port num
		][
			udp-client red-port host num
		]
		as red-value! red-port
	]

	close: func [
		red-port	[red-object!]
		return:		[red-value!]
		/local
			data	[iocp-data!]
	][
		#if debug? = yes [if verbose > 0 [print-line "udp/close"]]

		data: io/get-iocp-data red-port
		if data <> null [socket/close as-integer data/device]
		as red-value! red-port
	]

	insert: func [
		port		[red-object!]
		value		[red-value!]
		part		[red-value!]
		only?		[logic!]
		dup			[red-value!]
		append?		[logic!]
		return:		[red-value!]
		/local
			data	[udp-data!]
			bin		[red-binary!]
			n		[integer!]
	][
		switch TYPE_OF(value) [
			TYPE_BINARY [
				bin: as red-binary! value
				io/pin-memory bin/node
			]
			default [return as red-value! port]
		]

		data: get-udp-data port
		data/send-buf: bin/node

		socket/usend
			as-integer data/iocp/device
			as sockaddr_in! data/addr
			data/addr-sz
			binary/rs-head bin
			binary/rs-length? bin
			as iocp-data! data
		as red-value! port
	]

	copy: func [
		red-port	[red-object!]
		new			[red-value!]
		part		[red-value!]
		deep?		[logic!]
		types		[red-value!]
		return:		[red-value!]
		/local
			data	[udp-data!]
			buf		[red-binary!]
			s		[series!]
	][
		buf: as red-binary! (object/get-values red-port) + port/field-data
		if TYPE_OF(buf) <> TYPE_BINARY [
			binary/make-at as cell! buf SOCK_READBUF_SZ
		]
		buf/head: 0
		io/pin-memory buf/node
		s: GET_BUFFER(buf)
		data: as udp-data! get-udp-data red-port
		socket/urecv
			as-integer data/iocp/device
			as byte-ptr! s/offset
			s/size
			as sockaddr_in! :data/addr
			:data/addr-sz
			as sockdata! data
		as red-value! red-port
	]

	table: [
		;-- Series actions --
		null			;append
		null			;at
		null			;back
		null			;change
		null			;clear
		:copy
		null			;find
		null			;head
		null			;head?
		null			;index?
		:insert
		null			;length?
		null			;move
		null			;next
		null			;pick
		null			;poke
		null			;put
		null			;remove
		null			;reverse
		null			;select
		null			;sort
		null			;skip
		null			;swap
		null			;tail
		null			;tail?
		null			;take
		null			;trim
		;-- I/O actions --
		null			;create
		:close
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