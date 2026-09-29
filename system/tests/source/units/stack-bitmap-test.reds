Red/System [
	Title:		"Red/System stack bitmap record test script"
	Author:		"Xie Qingtian"
	File:		%stack-bitmap-test.reds
	Tabs:		4
	Rights:		"Copyright (C) 2026 Red Foundation. All rights reserved."
	License:	"BSD-3 - https://github.com/red/red/blob/origin/BSD-3-License.txt"
]

#include %../../../../quick-test/quick-test.reds

#include %../../../codegen/stack-bitmap.reds

~~~start-file~~~ "stack-bitmap"

===start-group=== "stack bitmap records"

	sb-record: as int-ptr! allocate 64

	--test-- "sb-words"
		--assert (stack-bitmap/words 0) = 1
		--assert (stack-bitmap/words 31) = 1
		--assert (stack-bitmap/words 32) = 2
		--assert (stack-bitmap/words 62) = 2
		--assert (stack-bitmap/words 63) = 3

	--test-- "sb-record-size"
		;-- A record carries a handle stream beside the pointer one, so it costs
		;-- one more word per 31 slots than it did, and one word past both streams
		;-- for how far the frame reaches below the slots it counts.
		--assert (stack-bitmap/record-size 0) = 24
		--assert (stack-bitmap/record-size 31) = 24
		--assert (stack-bitmap/record-size 32) = 32
		--assert (stack-bitmap/record-size 63) = 40

	--test-- "sb-empty"
		stack-bitmap/initialize sb-record 0
		--assert sb-record/1 = 0
		--assert sb-record/2 = 0
		--assert sb-record/3 = 0						;-- the empty argument word
		--assert sb-record/4 = 0						;-- the one pointer word
		--assert sb-record/5 = 0						;-- the handle word below it
		--assert sb-record/6 = 0						;-- and the gap word past both
		--assert (not stack-bitmap/mark sb-record 0)
		--assert (not stack-bitmap/mark-handle sb-record 0)

	--test-- "sb-three"
		stack-bitmap/initialize sb-record 3
		--assert stack-bitmap/mark sb-record 0
		--assert stack-bitmap/mark sb-record 2
		--assert sb-record/4 = 5
		--assert (not stack-bitmap/mark sb-record 3)
		--assert (not stack-bitmap/mark sb-record -1)
		--assert sb-record/4 = 5

	--test-- "sb-handle-three"
		;-- The handle stream numbers the same slots, and marking it moves neither.
		--assert sb-record/5 = 0
		--assert stack-bitmap/mark-handle sb-record 1
		--assert sb-record/5 = 2
		--assert sb-record/4 = 5
		--assert (not stack-bitmap/mark-handle sb-record 3)
		--assert (not stack-bitmap/mark-handle sb-record -1)

	--test-- "sb-63"
		stack-bitmap/initialize sb-record 63
		--assert sb-record/1 = 0
		--assert sb-record/2 = 63
		--assert sb-record/3 = 0
		--assert sb-record/4 = 80000000h
		--assert sb-record/5 = 80000000h
		--assert sb-record/6 = 0
		--assert stack-bitmap/mark sb-record 30
		--assert stack-bitmap/mark sb-record 31
		--assert stack-bitmap/mark sb-record 61
		--assert stack-bitmap/mark sb-record 62
		--assert sb-record/4 = C0000000h
		--assert sb-record/5 = C0000001h
		--assert sb-record/6 = 1
		--assert (not stack-bitmap/mark sb-record 63)

	--test-- "sb-handle-63"
		;-- Three words of handle flags follow the three of pointer flags, chained
		;-- the same way, so the collector reads one stream without disturbing the
		;-- other.
		--assert sb-record/7 = 80000000h
		--assert sb-record/8 = 80000000h
		--assert sb-record/9 = 0
		--assert stack-bitmap/mark-handle sb-record 0
		--assert stack-bitmap/mark-handle sb-record 31
		--assert stack-bitmap/mark-handle sb-record 62
		--assert sb-record/7 = 80000001h
		--assert sb-record/8 = 80000001h
		--assert sb-record/9 = 1						;-- slot 62 opens the last word
		--assert sb-record/4 = C0000000h				;-- and the pointer stream never moved
		--assert sb-record/5 = C0000001h
		--assert sb-record/6 = 1
		--assert (not stack-bitmap/mark-handle sb-record 63)
		--assert (not stack-bitmap/mark-handle sb-record -1)

	--test-- "sb-gap"
		;-- One word past both streams, and the writer and the reader reach it through
		;-- the same helper, so a record cannot publish a depth the collector would
		;-- go looking for elsewhere. The word starts untagged, which is also what the
		;-- slot after a record from a compiler without gap words reads as; a reach the
		;-- compiler priced carries the tag, and the collector decodes it by masking.
		;-- Every comparison below parenthesises its right side: with no operator
		;-- precedence, `p = q + 5` reads as `(p = q) + 5`.
		stack-bitmap/initialize sb-record 3
		--assert sb-record/6 = 0
		sb-gap: stack-bitmap/gap sb-record
		--assert sb-gap = (sb-record + 5)
		stack-bitmap/publish sb-record 0
		--assert sb-record/6 = stack-bitmap/GAP-TAG
		stack-bitmap/publish sb-record 9
		--assert sb-record/6 = (stack-bitmap/GAP-TAG or 9)
		--assert (sb-record/6 and 3FFFFFFFh) = 9
		--assert sb-record/4 = 0							;-- the streams never moved
		--assert sb-record/5 = 0
		stack-bitmap/publish sb-record -1					;-- a reach left unsaid
		--assert sb-record/6 = 0
		stack-bitmap/initialize sb-record 63
		--assert (stack-bitmap/gap sb-record) = (sb-record + 9)
		--assert sb-record/10 = 0
		free as byte-ptr! sb-record

	#if target = 'ARM64 [
		--test-- "sb-catch"
			;-- The shadow slots the bitmap points at are the frame's own, so a
			;-- nested catch that reloads them must still find what the prolog left.
			sb-catch-bitmap: func [
				/local frame slot [ptr-ptr!] before [integer!]
			][
				frame: as ptr-ptr! system/stack/frame
				slot: frame - 5
				before: as integer! slot/value
				--assert before > 0
				catch 1 [
					--assert (as integer! slot/value) = before
					catch 2 [
						--assert (as integer! slot/value) = before
						throw 2
					]
					--assert (as integer! slot/value) = before
					throw 1
				]
				--assert (as integer! slot/value) = before
			]
			sb-catch-bitmap
	]

===end-group===

~~~end-file~~~
