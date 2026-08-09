Red/System [
	Title: "O2 SysV x64 imported aggregate ABI coverage"
]

#if all [target = 'X86-64 OS <> 'Windows] [
	mixed-is!: alias struct! [
		left   [integer!]
		right  [integer!]
		weight [float32!]
	]

	mixed-si!: alias struct! [
		first  [float32!]
		second [float32!]
		tag    [integer!]
		pad    [integer!]
	]

	pair-f32!: alias struct! [
		first  [float32!]
		second [float32!]
	]

	memory-int!: alias struct! [
		a [integer!]
		b [integer!]
		c [integer!]
		d [integer!]
		e [integer!]
	]

	#import [
		"libsysvagg.so" cdecl [
			sysv-check-mixed-is: "sysv_check_mixed_is" [
				value [mixed-is! value]
				return: [integer!]
			]
			sysv-check-mixed-si: "sysv_check_mixed_si" [
				value [mixed-si! value]
				return: [integer!]
			]
			sysv-check-pair-f32: "sysv_check_pair_f32" [
				value [pair-f32! value]
				return: [integer!]
			]
			sysv-check-rollback: "sysv_check_rollback" [
				a [integer!]
				b [integer!]
				c [integer!]
				d [integer!]
				e [integer!]
				value [mixed-is! value]
				tail [integer!]
				return: [integer!]
			]
			sysv-return-mixed-is: "sysv_return_mixed_is" [
				left [integer!]
				right [integer!]
				weight [float32!]
				return: [mixed-is! value]
			]
			sysv-return-mixed-si: "sysv_return_mixed_si" [
				first [float32!]
				second [float32!]
				tag [integer!]
				return: [mixed-si! value]
			]
			sysv-return-pair-f32: "sysv_return_pair_f32" [
				first [float32!]
				second [float32!]
				return: [pair-f32! value]
			]
			sysv-check-memory: "sysv_check_memory" [
				value [memory-int! value]
				return: [integer!]
			]
			sysv-return-memory: "sysv_return_memory" [
				input [mixed-is! value]
				tail [integer!]
				return: [memory-int! value]
			]
		]
	]

	check-mixed-is: func [return: [integer!] /local value [mixed-is! value]][
		value/left: 10
		value/right: 20
		value/weight: as float32! 3.5
		sysv-check-mixed-is value
	]

	check-mixed-si: func [return: [integer!] /local value [mixed-si! value]][
		value/first: as float32! 4.5
		value/second: as float32! 5.5
		value/tag: 7
		value/pad: 0
		sysv-check-mixed-si value
	]

	check-pair-f32: func [return: [integer!] /local value [pair-f32! value]][
		value/first: as float32! 6.5
		value/second: as float32! 7.5
		sysv-check-pair-f32 value
	]

	check-rollback: func [return: [integer!] /local value [mixed-is! value]][
		value/left: 1
		value/right: 2
		value/weight: as float32! 3.5
		sysv-check-rollback 1 2 3 4 5 value 6
	]

	check-return-mixed-is: func [return: [integer!] /local value [mixed-is! value]][
		value: sysv-return-mixed-is 11 12 as float32! 4.5
		sysv-check-mixed-is value
	]

	check-return-mixed-si: func [return: [integer!] /local value [mixed-si! value]][
		value: sysv-return-mixed-si (as float32! 8.5) (as float32! 9.5) 10
		sysv-check-mixed-si value
	]

	check-return-pair-f32: func [return: [integer!] /local value [pair-f32! value]][
		value: sysv-return-pair-f32 (as float32! 13.5) (as float32! 14.5)
		sysv-check-pair-f32 value
	]

	check-memory: func [return: [integer!] /local value [memory-int! value]][
		value/a: 1
		value/b: 2
		value/c: 3
		value/d: 4
		value/e: 5
		sysv-check-memory value
	]

	check-return-memory: func [
		return: [integer!]
		/local input [mixed-is! value] value [memory-int! value]
	][
		input/left: 1
		input/right: 2
		input/weight: as float32! 3.5
		value: sysv-return-memory input 4
		sysv-check-memory value
	]

	main: func [return: [integer!]][
		either all [
			check-mixed-is = 33
			check-mixed-si = 16
			check-pair-f32 = 13
			check-rollback = 27
			check-return-mixed-is = 27
			check-return-mixed-si = 27
			check-return-pair-f32 = 27
			check-memory = 15
			check-return-memory = 20
		][0][1]
	]

	#syscall [
		sys-exit: 60 [status [integer!]]
	]
	sys-exit main
]
