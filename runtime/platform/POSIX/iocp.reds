Red/System [
	Title:	"IOCP on Unix"
	Author: "Xie Qingtian"
	File: 	%iocp.reds
	Tabs: 	4
	Rights: "Copyright (C) 2019 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
	NOTE: {
		This is not a completed IOCP implementation.
	}
]

#define IO_STATE_READING		4000h
#define IO_STATE_WRITING		8000h
#define IO_STATE_PENDING_READ	4001h		;-- READING or EPOLLIN
#define IO_STATE_PENDING_WRITE	8004h		;-- WRITING or EPOLLOUT

iocp-event-handler!: alias function! [
	data		[int-ptr!]
]

iocp!: alias struct! [
	maxn		[integer!]
	epfd		[integer!]				;-- the epoll fd
	events		[epoll_event!]			;-- the events
	nevents		[integer!]				;-- the events count
	pair-1		[integer!]
	pair-2		[integer!]
	ready-socks	[deque!]				;-- a queue for ready socket
	posted?		[logic!]
]

pending-data!: alias struct! [
	header			[list-entry! value]
	buffer			[byte-ptr!]
	buflen			[integer!]
]

iocp-data!: alias struct! [
	io-port			[iocp!]				;--	iocp! handle
	device			[handle!]			;-- device handle. e.g. socket
	event-handler	[iocp-event-handler!]
	event			[integer!]
	transferred		[integer!]			;-- number of bytes transferred
	read-buf		[byte-ptr!]
	read-buflen		[integer!]
	write-buf		[byte-ptr!]
	write-buflen	[integer!]		
	state			[integer!]
	pending-read	[pending-data!]
	pending-write	[pending-data!]
]

iocp: context [
	verbose: 0

	create: func [
		return: [iocp!]
		/local
			p	[iocp!]
			ptr [iocp-data!]
	][
		errno: get-errno-ptr
		p: as iocp! alloc0 size? iocp!
		p/maxn: 65536

		#either OS = 'macOS [
			p/epfd: LibC.kqueue
		][
			p/epfd: epoll_create1 00080000h
		]
		assert p/epfd > 0

		p/ready-socks: deque/create 1024

		if -1 = socketpair 1 SOCK_STREAM 0 :p/pair-1 [
			probe "!!! create pair fail !!!"
		]
		socket/set-nonblocking p/pair-1
		socket/set-nonblocking p/pair-2

		ptr: as iocp-data! alloc0 size? iocp-data!
		ptr/device: as handle! p/pair-2
		ptr/event: IO_EVT_PULSE
		add p p/pair-2 EPOLLIN or EPOLLET ptr
		p
	]
 
	close: func [
		p [iocp!]
	][
		#if debug? = yes [print-line "iocp/close"]

		LibC.close p/pair-1
		LibC.close p/pair-2
		LibC.close p/epfd
		if p/events <> null [
			free as byte-ptr! p/events
		]
		free as byte-ptr! p
	]

	post: func [
		p		[iocp!]
		data	[iocp-data!]
	][
		deque/push p/ready-socks as int-ptr! data
		unless p/posted? [
			p/posted?: yes
			LibC.send p/pair-1 as byte-ptr! "p" 1 0
		]
	]

	bind: func [
		"bind a device handle to the I/O completion port"
		p		[iocp!]
		handle	[int-ptr!]
	][
	]

#either OS = 'macOS [
	#define IOCP_READ_ACTION? [filter = EVFILT_READ]
	#define IOCP_WRITE_ACTION? [filter = EVFILT_WRITE]
][
	#define IOCP_READ_ACTION? [e/events and EPOLLIN <> 0]
	#define IOCP_WRITE_ACTION? [e/events and EPOLLOUT <> 0]
]

	wait: func [
		"wait I/O completion events and dispatch them"
		p			[iocp!]
		timeout		[integer!]			;-- time in ms, -1: infinite
		return:		[integer!]
		/local
			queue	[deque!]
			cnt		[integer!]
			i		[integer!]
			e		[epoll_event!]
			data	[iocp-data!]
			n		[integer!]
			err		[integer!]
			sock	[integer!]
			datalen [integer!]
			state	[integer!]
			#if OS = 'macOS [
			filter	[integer!]
			flags	[integer!]
			_tm		[timespec! value]
			tm		[timespec!]
			]
	][
		#if debug? = yes [if verbose > 0 [print-line "iocp/wait"]]

		err: 0
		if null? p/events [
			p/nevents: 512
			p/events: as epoll_event! allocate p/nevents * size? epoll_event!
		]
		queue: p/ready-socks

		#either OS = 'macOS [
			either timeout < 0 [
				tm: null
			][
				tm: :_tm
				tm/sec: timeout / 1000
				tm/nsec: timeout % 1000 * 1000000
			]

			cnt: LibC.kevent p/epfd null 0 p/events p/nevents tm
			if cnt < 0 [return 0]
		][
			cnt: epoll_wait p/epfd p/events p/nevents timeout
			if all [cnt < 0 errno/value = EINTR][return 0]
		]

?? cnt
		if cnt = p/nevents [		;-- TBD: extend events buffer
			0
		]

		i: 0
		while [i < cnt][
			e: p/events + i
			data: as iocp-data! e/udata
			sock: as-integer data/device
			either data/event = IO_EVT_PULSE [
				datalen: 0
				n: LibC.recv sock as byte-ptr! :datalen 4 0
				assert n = 1

				p/posted?: no
				n: queue/size
?? n
				loop n [
					data: as iocp-data! deque/take queue
					#if debug? = yes [probe ["pluse event: " data/event]]
					data/event-handler as int-ptr! data
				]
			][
				#either OS = 'macOS [
					filter: e/filter and FFFFh
					flags: e/filter >>> 16
					probe ["ready event: " filter " " flags]
				][
					probe ["ready event: " e/events]
				]
				
				state: data/state
				case [
				#if OS = 'macOS [
					flags and EV_ERROR <> 0 [
						probe "kqueue error" halt
					]
					flags and EV_EOF <> 0 [
						probe "kqueue: socket close"
					]
				]
					all [
						IOCP_READ_ACTION?
						state and IO_STATE_READING <> 0
					][
						either null? data/pending-read [
probe [sock " " data/read-buf " " data/read-buflen]
							n: LibC.recv sock data/read-buf data/read-buflen 0
probe errno/value
probe ["read data: " n]
							data/state: state and (not IO_STATE_READING)
							data/transferred: n
							data/event: IO_EVT_READ
							data/event-handler as int-ptr! data
						][
							0 ;TBD
						]
					]
					all [
						IOCP_WRITE_ACTION?
						state and IO_STATE_WRITING <> 0
					][
						either null? data/pending-write [
							datalen: data/write-buflen
							n: LibC.send sock data/write-buf datalen 0
							either n = datalen [
								data/state: state and (not IO_STATE_WRITING)
								data/write-buf: null
								data/event: IO_EVT_WRITE
								data/event-handler as int-ptr! data
							][	;-- remaining data to be sent
								data/write-buf: data/write-buf + n
								data/write-buflen: data/write-buflen - n
							]
						][
							0 ;; TBD
						]
					]
					data/event > IO_EVT_WRITE [
						data/event-handler as int-ptr! data
					]
					true [0]
				]
			]
			i: i + 1
		]
		1
	]

	create-pending: func [
		buffer	[byte-ptr!]
		len		[integer!]
		return: [pending-data!]
		/local
			pending [pending-data!]
	][
		pending: as pending-data! allocate size? pending-data!
		dlink/init as list-entry! pending
		pending/buffer: buffer		;-- save previous data
		pending/buflen: len
		pending
	]

	add-pending: func [
		data	[iocp-data!]
		buffer	[byte-ptr!]
		len		[integer!]
		evt		[integer!]		;-- can only be READ and WRITE event
		/local
			pending	[pending-data!]
	][
		switch evt [
			IO_EVT_READ [
				pending: data/pending-read
				if null? pending [
					pending: create-pending data/read-buf data/read-buflen
					data/pending-read: pending
					data/read-buflen: 1
				]
				data/read-buflen: data/read-buflen + 1
			]
			IO_EVT_WRITE [
				pending: data/pending-write
				if null? pending [
					pending: create-pending data/read-buf data/read-buflen
					data/pending-write: pending
					data/write-buflen: 1
				]
				data/write-buflen: data/write-buflen + 1
			]
			default [exit]
		]
		dlink/append
			as list-entry! pending
			as list-entry! create-pending buffer len
	]

	push-data: func [
		p		[iocp!]
		sdata	[iocp-data!]
	][
		deque/push p/ready-socks as int-ptr! sdata
	]

	pulse: func [
		p		[iocp!]
	][
		LibC.send p/pair-1 as byte-ptr! "p" 1 0
	]

	kill: func [
		p	[iocp!]
	][
		LibC.send p/pair-1 as byte-ptr! "k" 1 0
	]

#either OS = 'macOS [
	_modify: func [
		kqfd	[integer!]
		evs		[kevent!]
		cnt		[integer!]
		/local
			res	[integer!]
	][
		res: LibC.kevent kqfd evs cnt null 0 null
		if res < 0 [
			probe ["change kevent failed, errno: " errno/value]
		]
	]

	add: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
		/local
			e2	[kevent! value]
			e1	[kevent! value]
			e	[kevent!]
			ev	[integer!]
			n	[integer!]
	][
		ev: EV_ADD
		if events and EPOLLET <> 0 [ev: ev or EV_CLEAR]

		e: as kevent! :e1
		n: 0
		if events and EPOLLIN <> 0 [
			EV_SET(e sock EVFILT_READ ev 0 null data)
			n: n + 1
			e: e + 1
		]
		if events and EPOLLOUT <> 0 [
			EV_SET(e sock EVFILT_WRITE ev 0 null data)
			n: n + 1
		]
		_modify p/epfd :e1 n
	]

	remove: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
		/local
			e2	[kevent! value]
			e1	[kevent! value]
			e	[kevent!]
			ev	[integer!]
			n	[integer!]
	][
		ev: EV_DELETE
		e: as kevent! :e1
		n: 0
		if events and EPOLLIN <> 0 [
			EV_SET(e sock EVFILT_READ ev 0 null data)
			n: n + 1
			e: e + 1
		]
		if events and EPOLLOUT <> 0 [
			EV_SET(e sock EVFILT_WRITE ev 0 null data)
			n: n + 1
		]
		_modify p/epfd :e1 n
	]

	modify: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
	][
		add p sock events data
	]
][
	_modify: func [
		epfd	[integer!]
		sock	[integer!]
		evts	[integer!]
		data	[iocp-data!]
		op		[integer!]
		/local
			ev	[epoll_event! value]
	][
		ev/udata: as int-ptr! data
		ev/events: evts
		if 0 <> epoll_ctl epfd op sock :ev [
			probe ["epoll_ctl error! fd: " sock " op: " op]
		]
	]

	add: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
	][
		_modify p/epfd sock events data EPOLL_CTL_ADD
	]

	remove: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
	][
		_modify p/epfd sock events data EPOLL_CTL_DEL
	]

	modify: func [
		p		[iocp!]
		sock	[integer!]
		events	[integer!]
		data	[iocp-data!]
	][
		_modify p/epfd sock events data EPOLL_CTL_MOD
	]
]]