Red/System [Title: "Counted stack pointer and handle bitmap records"]

; One record per function in the image's bitmap table. Layout, in 32-bit
; words: [arg-slot-count][local-slot-count][first argument bitmap word]
; [pointer bitmap words...][handle bitmap words...]. The collector always
; consumes one argument word even when the count is zero, so the argument
; stream below is a fixed empty word: physical homes share the local stream,
; and incoming stack arguments stay in the caller's conservatively scanned
; outgoing area.
; Each bitmap word carries 31 slot flags, lowest bit first; the top bit of
; a non-final word marks that another word follows in the same stream.
; The handle stream is a second, equal-length copy of that shape over the same
; slot numbering, so one walk can consult either flag without a shift or a
; mask: a slot holds a pointer, a node handle, or nothing the collector may
; chase. The collector locates the handle word paired with the pointer word it
; is reading by the word count of the local stream, so the two advance in
; lockstep and the walk pays nothing for the stream it is not consulting.
stack-bitmap: context [
	words: func [slots [integer!] return: [integer!]][
		either slots = 0 [1][1 + ((slots - 1) / 31)]
	]

	record-size: func [slots [integer!] return: [integer!]][
		12 + ((words slots) * 8)					;-- header, then both streams
	]

	initialize: func [record [int-ptr!] slots [integer!]
		/local count index slot [integer!] flags [integer!]
	][
		record/1: 0
		record/2: slots
		record/3: 0
		count: words slots
		index: 1
		while [index <= count][
			slot: index + 3
			flags: either index < count [80000000h][0]
			record/slot: flags
			slot: slot + count
			record/slot: flags
			index: index + 1
		]
	]

	; Marks the flag of one physical slot: slot 0 is the home at FP-40, the
	; next slot downward each adds eight bytes. Returns false when the slot
	; falls outside the counted region, which fails compilation loudly.
	mark: func [record [int-ptr!] slot [integer!] return: [logic!]
		/local word [int-ptr!]
	][
		if any [slot < 0 slot >= record/2][return false]
		word: record + 3 + (slot / 31)
		word/value: word/value or (1 << (slot // 31))
		true
	]

	; The same slot, the same numbering, the handle stream. A record knows its
	; own slot count, so the writers only ever pass the record they were given
	; and cannot put a flag in the wrong stream by arithmetic.
	mark-handle: func [record [int-ptr!] slot [integer!] return: [logic!]
		/local word [int-ptr!]
	][
		if any [slot < 0 slot >= record/2][return false]
		word: record + 3 + (words record/2) + (slot / 31)
		word/value: word/value or (1 << (slot // 31))
		true
	]
]
