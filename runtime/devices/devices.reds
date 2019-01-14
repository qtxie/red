Red/System [
	Title:	"Device Registration"
	Author: "Xie Qingtian"
	File: 	%devices.reds
	Tabs: 	4
	Rights: "Copyright (C) 2015-2018 Red Foundation. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

device-action-table: as int-ptr! 0				;-- actions jump table

#enum devices! [
	DEVICE_TCP
	DEVICE_UDP
	DEVICE_FILE
	DEVICE_USB

	DEVICE_COUNT
]

#enum device-actions! [

	;-- Series actions --
	DEV_ACT_APPEND
	DEV_ACT_AT
	DEV_ACT_BACK
	DEV_ACT_CHANGE
	DEV_ACT_CLEAR
	DEV_ACT_COPY
	DEV_ACT_FIND
	DEV_ACT_HEAD
	DEV_ACT_HEAD?
	DEV_ACT_INDEX?
	DEV_ACT_INSERT
	DEV_ACT_LENGTH?
	DEV_ACT_MOVE
	DEV_ACT_NEXT
	DEV_ACT_PICK
	DEV_ACT_POKE
	DEV_ACT_REMOVE
	DEV_ACT_REVERSE
	DEV_ACT_SELECT
	DEV_ACT_SORT
	DEV_ACT_SKIP
	DEV_ACT_TAIL
	DEV_ACT_TAIL?
	DEV_ACT_TAKE
	DEV_ACT_TRIM
	
	;-- I/O actions --
	DEV_ACT_CREATE
	DEV_ACT_CLOSE
	DEV_ACT_DELETE
	DEV_ACT_MODIFY
	DEV_ACT_OPEN
	DEV_ACT_OPEN?
	DEV_ACT_QUERY
	DEV_ACT_READ
	DEV_ACT_RENAME
	DEV_ACT_UPDATE
	DEV_ACT_WRITE

	DEV_ACT_COUNT
]

#include %tcp.reds

devices: context [

	register: func [
		[variadic]
		count		[integer!]
		list		[int-ptr!]
		/local
			type	[integer!]
			index	[integer!]
	][
		type: list/value
		assert type < DEVICE_COUNT

		list: list + 2
		count: count - 2							;-- skip the "header" data
		
		if count <> DEV_ACT_COUNT [
			print [
				"*** Datatype Error: invalid actions count for device: " type lf
				"*** Found: " count lf
				"*** Expected: " DEV_ACT_COUNT lf
			]
			halt
		]
		
		index: type * DEV_ACT_COUNT + 1				;-- consume first argument (type ID), one-based index
		until [
			device-action-table/index: list/value
			index: index + 1
			list: list + 1
			count: count - 1
			zero? count
		]
	]

	init: does [
		device-action-table: as int-ptr! allocate 	 ;-- actions jump table	
				DEV_ACT_COUNT * DEVICE_COUNT * size? pointer!

		tcp-scheme/init
	]
]