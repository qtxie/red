Red/System [
	Title:	"IOCP on Windows"
	Author: "Xie Qingtian"
	File: 	%windows.reds
	Tabs: 	4
	Rights: "Copyright (C) 2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

iocp-event-handler!: alias function! [
	data		[int-ptr!]
]

iocp!: alias struct! [
	maxn	[integer!]
	port	[int-ptr!]
	events	[OVERLAPPED_ENTRY!]
	evt-cnt [integer!]
]

iocp-data!: alias struct! [
	Internal		[int-ptr!]				;-- inline OVERLAPPED struct begin
	InternalHigh	[int-ptr!]
	Offset			[integer!]				;-- or Pointer [int-ptr!]
	OffsetHigh		[integer!]
	hEvent			[int-ptr!]				;-- inline OVERLAPPED struct end
	;--
	device			[handle!]				;-- device handle
	event-handler	[iocp-event-handler!]
	event			[integer!]
	transferred		[integer!]				;-- number of bytes transferred
	accept-sock		[integer!]
	accept-addr		[byte-ptr!]
]

iocp: context [
	create: func [
		return: [iocp!]
		/local
			p	[iocp!]
	][
		p: as iocp! alloc0 size? iocp!
		p/maxn: 65536
		p/port: CreateIoCompletionPort INVALID_HANDLE null null 0
		assert p/port <> INVALID_HANDLE
		p
	]

	close: func [
		p [iocp!]
	][
		CloseHandle p/port
		if p/events <> null [
			free as byte-ptr! p/events
		]
		free as byte-ptr! p
	]

	bind: func [
		"bind a device handle to the I/O completion port"
		p		[iocp!]
		handle	[int-ptr!]
		/local
			port [int-ptr!]
	][
		port: CreateIoCompletionPort handle p/port null 0
		if port <> p/port [
			probe "iocp bind error"
		]
	]

	wait: func [
		"wait I/O completion events and dispatch them"
		p			[iocp!]
		timeout		[integer!]			;-- time in ms, -1: infinite
		/local
			res		[integer!]
			cnt		[integer!]
			err		[integer!]
			i		[integer!]
			e		[OVERLAPPED_ENTRY!]
			data	[iocp-data!]
	][
		#if debug? = yes [print-line "iocp/wait"]

		if null? p/events [
			p/evt-cnt: 512
			p/events: as OVERLAPPED_ENTRY! allocate p/evt-cnt * size? OVERLAPPED_ENTRY!
		]

		cnt: 0
		res: GetQueuedCompletionStatusEx p/port p/events p/evt-cnt :cnt timeout no

		if cnt = p/evt-cnt [			;-- TBD: extend events buffer
			0
		]

		i: 0
		while [i < cnt][
			e: p/events + i
			data: as iocp-data! e/lpOverlapped
			data/event-handler as int-ptr! data
			i: i + 1
		]
	]
]