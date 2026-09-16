Red/System [
	Title:   "Red/System address difference comparison test script"
	Author:  "Nenad Rakocevic"
	File: 	 %pointer-difference-test.reds
	Tabs:	 4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %../../../../quick-test/quick-test.reds

~~~start-file~~~ "address-difference"

;-- The members mirror the series! layout, so the differences below are
;-- computed on two address members sitting in the middle of a struct.
;-- The right operand of such a difference can be allocated to the very
;-- register designated as the result of the subtraction; the emitter must
;-- save it before writing the left operand over that register, otherwise
;-- the subtraction silently yields zero and every comparison against it
;-- is wrong.
struct-layout!: alias struct! [
	node	[int-ptr!]
	offset	[byte-ptr!]
	tail	[byte-ptr!]
	size	[integer!]
	flags	[integer!]
]

anchor: 0
layout-value: declare struct-layout!

layout-limit: func [
	s		[struct-layout!]
	return: [integer!]
][
	as-integer s/tail - s/offset
]

layout-below?: func [
	s		[struct-layout!]
	off		[integer!]
	return: [logic!]
][
	off >= (as-integer s/tail - s/offset)
]

layout-above?: func [
	s		[struct-layout!]
	off		[integer!]
	return: [logic!]
][
	off < (as-integer s/tail - s/offset)
]

layout-equal?: func [
	s		[struct-layout!]
	off		[integer!]
	return: [logic!]
][
	off = (as-integer s/tail - s/offset)
]

layout-below-unit?: func [
	s		[struct-layout!]
	off		[integer!]
	unit	[integer!]
	return: [logic!]
][
	off >= ((as-integer s/tail - s/offset) >> (log-b unit))
]

layout-below-local?: func [
	s		[struct-layout!]
	off		[integer!]
	return: [logic!]
	/local
		lim [integer!]
][
	lim: as-integer s/tail - s/offset
	off >= lim
]


===start-group=== "Address difference as an inline comparison operand"

	layout-value/offset: as byte-ptr! :anchor
	layout-value/tail:   (as byte-ptr! :anchor) + 48
	layout-value/size:   1024
	layout-value/flags:  4

	--test-- "address-difference-1"
	--assert (layout-limit layout-value) = 48

	--test-- "address-difference-2"
	--assert (layout-below-local? layout-value 0) = false
	--assert (layout-below-local? layout-value 47) = false
	--assert (layout-below-local? layout-value 48) = true
	--assert (layout-below-local? layout-value 100) = true

	--test-- "address-difference-3"
	--assert (layout-below? layout-value 0) = false
	--assert (layout-below? layout-value 47) = false
	--assert (layout-below? layout-value 48) = true
	--assert (layout-below? layout-value 100) = true

	--test-- "address-difference-4"
	--assert (layout-above? layout-value 0) = true
	--assert (layout-above? layout-value 47) = true
	--assert (layout-above? layout-value 48) = false
	--assert (layout-above? layout-value 100) = false

	--test-- "address-difference-5"
	--assert (layout-equal? layout-value 0) = false
	--assert (layout-equal? layout-value 48) = true
	--assert (layout-equal? layout-value 100) = false

	--test-- "address-difference-6"
	--assert (layout-below-unit? layout-value 0 16) = false
	--assert (layout-below-unit? layout-value 2 16) = false
	--assert (layout-below-unit? layout-value 3 16) = true
	--assert (layout-below-unit? layout-value 8 16) = true

	--test-- "address-difference-7"
	--assert not any [
		(layout-below-unit? layout-value 2 16)
	]

===end-group===

~~~end-file~~~
