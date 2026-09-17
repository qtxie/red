Red/System [Title: "Counted stack pointer bitmap records"]

; One record per function in the image's bitmap table. Layout, in 32-bit
; words: [arg-slot-count][local-slot-count][first argument bitmap word]
; [local bitmap words...]. The collector always consumes one argument word
; even when the count is zero, so the argument stream below is a fixed
; empty word: physical homes share the local stream, and incoming stack
; arguments stay in the caller's conservatively scanned outgoing area.
; Each bitmap word carries 31 slot flags, lowest bit first; the top bit of
; a non-final word marks that another word follows in the same stream.
stack-bitmap: context [
	words: func [slots [integer!] return: [integer!]][
		either slots = 0 [1][1 + ((slots - 1) / 31)]
	]

	record-size: func [slots [integer!] return: [integer!]][
		12 + ((words slots) * 4)
	]

	initialize: func [record [int-ptr!] slots [integer!]
		/local count index slot [integer!]
	][
		record/1: 0
		record/2: slots
		record/3: 0
		count: words slots
		index: 1
		while [index <= count][
			slot: index + 3
			record/slot: either index < count [80000000h][0]
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
]
