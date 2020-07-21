Red/System [
	Title:	"low-level TLS port"
	Author: "Xie Qingtian"
	File: 	%TLS.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

TLS-device: context [
	verbose: 1

	event-handler: func [
		data		[iocp-data!]
		/local
			p		[red-object!]
			msg		[red-object!]
			td		[tls-data!]
			data2	[iocp-data!]
			type	[integer!]
			bin		[red-binary!]
			s		[series!]
			fd		[integer!]
	][
		td: as tls-data! data
		p: as red-object! :td/port
		msg: p
		type: data/event

		switch type [
			IO_EVT_READ	[
				bin: as red-binary! (object/get-values p) + port/field-data
				s: GET_BUFFER(bin)
				s/tail: as cell! (as byte-ptr! s/offset) + data/transferred
				io/unpin-memory bin/node
				#if OS = 'Windows [
					either data/accept-sock = PENDING_IO_FLAG [
						free as byte-ptr! data
					][
						data/event: IO_EVT_NONE
					]
				]
			]
			IO_EVT_WRITE	[
				io/unpin-memory td/send-buf
				#if OS = 'Windows [
					either data/accept-sock = PENDING_IO_FLAG [
						free as byte-ptr! data
					][
						data/event: IO_EVT_NONE
					]
				]
			]
			IO_EVT_ACCEPT	[
				either data/state and IO_STATE_TLS_DONE = 0 [
					;-- swap accepted socket and the server socket
					;-- we'll do the negotiate through the accepted socket
					fd: data/accept-sock
					data/accept-sock: as-integer data/device
					data/device: as int-ptr! fd
					iocp/bind g-iocp as int-ptr! fd
					tls/negotiate as tls-data! data
					exit
				][
					data2: create-tcp-data p data/accept-sock
					#either OS = 'Windows [
						socket/acceptex data/accept-sock data2
					][
						data2/state: EPOLLIN
					]

					msg: create-red-port p
					copy-cell as cell! msg as cell! p
					io/set-iocp-data msg data

					td: as tls-data! data2
					p: as red-object! :td/port

					data/event: IO_EVT_NONE
				]
			]
			default [data/event: IO_EVT_NONE]
		]

		io/call-awake p msg type
	]

	create-red-port: func [
		proto		[red-object!]
		return:		[red-object!]
		/local
			data	[iocp-data!]
	][
		proto: port/make none-value object/get-values proto TYPE_NONE

		;; @@ add it to a block, so GC can mark it. Improve it later!!!
		block/rs-append ports-block as red-value! proto
		proto
	]

	create-tcp-data: func [
		port	[red-object!]
		sock	[integer!]
		return: [iocp-data!]
		/local
			data [iocp-data!]
	][
		data: as iocp-data! io/create-socket-data port sock as int-ptr! :event-handler size? tls-data!
		data/type: IOCP_TYPE_TLS
		data
	]

	get-tcp-data: func [
		red-port	[red-object!]
		return:		[sockdata!]
		/local
			state	[red-handle!]
			data	[iocp-data!]
			new		[sockdata!]
	][
		state: as red-handle! (object/get-values red-port) + port/field-state
		if TYPE_OF(state) <> TYPE_HANDLE [
			probe "ERROR: No low-level handle"
			0 ;; TBD throw error
		]

		#either OS = 'Windows [
			data: as iocp-data! state/value
			either data/event = IO_EVT_NONE [		;-- we can reuse this one
				as sockdata! data
			][										;-- needs to create a new one
				;TBD clone a tls data
				assert 1 = 0		;-- in our current simple test, should never reach this branch
				as sockdata! data
			]
		][
			as sockdata! state/value
		]
	]

	tcp-client: func [
		port	[red-object!]
		host	[red-string!]
		num		[red-integer!]
		/local
			fd		[integer!]
			n		[integer!]
			addr	[c-string!]
			data	[iocp-data!]
	][
		#if debug? = yes [if verbose > 0 [print-line "tls client"]]

		fd: socket/create AF_INET SOCK_STREAM IPPROTO_TCP
		iocp/bind g-iocp as int-ptr! fd
		socket/bind fd 0 AF_INET

		n: -1
		addr: unicode/to-utf8 host :n
		data: create-tcp-data port fd
		#if OS = 'Windows [data/state: IO_STATE_CLIENT]
		socket/connect fd addr num/value AF_INET data
	]

	tcp-server: func [
		port	[red-object!]
		num		[red-integer!]
		/local
			fd	[integer!]
			acp [integer!]
	][
		#if debug? = yes [if verbose > 0 [print-line "tls server"]]

		fd: socket/create AF_INET SOCK_STREAM IPPROTO_TCP
		socket/bind fd num/value AF_INET
		socket/listen fd 1024 create-tcp-data port fd
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
		#if debug? = yes [if verbose > 0 [print-line "tls/open"]]

		values: object/get-values red-port
		state: as red-handle! values + port/field-state
		if TYPE_OF(state) <> TYPE_NONE [return as red-value! red-port]

		spec:	as red-object! values + port/field-spec
		values: object/get-values spec
		host:	as red-string! values + 2
		num:	as red-integer! values + 3		;-- port number

		either zero? string/rs-length? host [	;-- e.g. open tcp://:8000
			tcp-server red-port num
		][
			tcp-client red-port host num
		]
		as red-value! red-port
	]

	close: func [
		red-port	[red-object!]
		return:		[red-value!]
		/local
			data	[iocp-data!]
	][
		#if debug? = yes [if verbose > 0 [print-line "tls/close"]]

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
			data	[sockdata!]
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

		data: get-tcp-data port

		#either OS = 'Windows [
			data/send-buf: alloc-bytes 96 + binary/rs-length? bin
			tls/send
				as-integer data/iocp/device
				binary/rs-head bin
				binary/rs-length? bin
				as tls-data! data
		][
			data/send-buf: bin/node
			socket/send
				as-integer data/iocp/device
				binary/rs-head bin
				binary/rs-length? bin
				as iocp-data! data
		]
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
			data	[iocp-data!]
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
		data: as iocp-data! get-tcp-data red-port
		socket/recv as-integer data/device as byte-ptr! s/offset s/size data
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