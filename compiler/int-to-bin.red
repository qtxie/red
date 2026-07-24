Red [
	Title: "Red compiler integer encoders"
	File:  %int-to-bin.red
]

; Keep integer serialization independent of host molding and decimal/hex text.
; Red integer! is signed 32-bit; to-bin64 accepts two 32-bit limbs when a
; caller needs a full 64-bit value.
int-to-bin: context [
	little-endian?: true

	to-bin8: func [value [integer! char!]][
		copy/part skip to-binary to integer! value 3 1
	]

	to-bin16: func [value [integer! char!] /local out][
		out: copy/part skip to-binary to integer! value 2 2
		either little-endian? [reverse out][out]
	]

	to-bin32: func [value [integer! char!] /local out][
		out: to-binary to integer! value
		either little-endian? [reverse out][out]
	]

	to-bin64: func [value [integer! char! block!] /local limbs out][
		limbs: either block? value [value][
			reduce [value either negative? value [-1][0]]
		]
		out: rejoin [to-bin32 limbs/1 to-bin32 limbs/2]
		either little-endian? [out][reverse out]
	]
]
