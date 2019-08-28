Red/System [
	Title:	"A Fixed Size FIFO Multi-Producer Multi-Consumer (MPMC) Queue"
	Author: "Xie Qingtian"
	File: 	%queue.reds
	Tabs:	4
	Rights: "Copyright (C) 2019 Xie Qingtian. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

cacheLinePad!: alias struct! [		;-- 64 bytes
	float1			[float!]
	float2			[float!]
	float3			[float!]
	float4			[float!]
	float5			[float!]
	float6			[float!]
	float7			[float!]
	float8			[float!]
]

qnode!: alias struct! [
	value	[int-ptr!]
	status	[integer!]
]

queue!: alias struct! [
	capacity		[integer!]		;-- size of the data array
	capacityMask	[integer!]
	data			[qnode!]		;-- offset to the first element in data
	pad1			[cacheLinePad! value]
	tail			[integer!]
	pad2			[cacheLinePad! value]
	head			[integer!]
]

queue: context [

	create: func [
		len			[integer!]
		return:		[queue!]
		/local
			q		[queue!]
			ptr		[qnode!]
			i		[integer!]
	][
		if len < 4 [len: 4]
		len: 1 << (1 + log-b len)			;-- rounding up to next power of 2

		q: as queue! allocate size? queue!
		q/capacity: len
		q/capacityMask: len - 1
		q/tail: 0
		q/head: 0
		ptr: as qnode! allocate len * size? qnode!
		q/data: ptr
		i: 0
		loop len [
			ptr/status: i
			ptr: ptr + 1
			i: i + 1
		]
		q
	]

	destroy: func [
		qe	[queue!]
	][
		free as byte-ptr! qe/data
		free as byte-ptr! qe
	]

	push: func [
		qe			[queue!]
		val			[int-ptr!]
		return:		[logic!]
		/local
			node	[qnode!]
			next	[integer!]
			tail	[integer!]
	][
		until [
			tail: system/atomic/load :qe/tail
			node: qe/data + tail
			if (system/atomic/load :node/status) <> tail [return false] ;-- queue is full
			next: tail + 1 and qe/capacityMask
			system/atomic/cas :qe/tail tail next
		]
		node/value: val
		system/atomic/store :node/status -1
		true
	]

	pop: func [
		qe			[queue!]
		return: 	[int-ptr!]
		/local
			node	[qnode!]
			head	[integer!]
			next	[integer!]
	][
		until [
			head: system/atomic/load :qe/head
			node: qe/data + head
			if (system/atomic/load :node/status) = head [return null] ;-- queue is empty
			next: head + 1 and qe/capacityMask
			system/atomic/cas :qe/head head next
		]
		system/atomic/store :node/status head
		node/value
	]

	s-push: func [
		"single producer push, a bit faster than push"
		qe			[queue!]
		val			[int-ptr!]
		return:		[logic!]
		/local
			tail	[integer!]
			node	[qnode!]
	][
		tail: qe/tail
		node: qe/data + tail
		if tail <> node/status [return false] ;-- queue is full
		qe/tail: tail + 1 and qe/capacityMask
		node/value: val
		system/atomic/store :node/status -1
		true
	]

	empty?: func [
		qe			[queue!]
		return: 	[logic!]
		/local
			tail	[integer!]
	][
		tail: system/atomic/load :qe/tail
		qe/head = tail
	]

	size: func [
		qe			[queue!]
		return: 	[integer!]
		/local
			tail	[integer!]
			head	[integer!]
	][
		tail: system/atomic/load :qe/tail
		head: system/atomic/load :qe/head
		if any [
			tail < head
			all [tail = head qe/data/status <> 0]
		][tail: tail + qe/capacity]
		tail - head
	]
]