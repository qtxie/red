Red [
	Title: "Red/System frontend target data model"
	File:  %compiler/system-target-model.red
]

; This object contains only target facts needed by semantic analysis and ABI
; layout. It deliberately has no instruction-emission hooks or mutable machine
; state, so the frontend can use it without importing a backend target object.
compiler-system-target-model: context [
	last-error: none
	target: none
	little-endian?: true
	struct-align-size: none
	ptr-size: none
	default-align: none
	stack-width: none

	comparison-op: [= <> < > <= >=]
	math-op: compose [+ - * / // (to word! first [%])]
	bitwise-op: [and or xor]

	set-error: func [message [string!] /local record][
		record: make object! [message: none]
		record/message: message
		last-error: record
		none
	]

	configure: func [target-name [word!] /local width][
		last-error: none
		unless find [IA-32 ARM X86-64 ARM64] target-name [
			return set-error rejoin ["unsupported frontend target model: " target-name]
		]
		target: target-name
		width: either find [X86-64 ARM64] target-name [8][4]
		struct-align-size: width
		ptr-size: width
		default-align: width
		stack-width: width
		self
	]
]
