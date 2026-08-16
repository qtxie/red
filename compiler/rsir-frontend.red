Red [
	Title: "Compact Red/System IR frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]

compiler-rsir-frontend: context [
	DEFAULT-MAX-BYTES: 16777216

	ERROR-ARGUMENTS: 1
	ERROR-KIND: 2
	ERROR-LIMIT: 3
	ERROR-NAME: 4
	ERROR-FUNCTION-COUNT: 5
	ERROR-UNSUPPORTED: 6
	ERROR-DUPLICATE: 7
	ERROR-REFERENCE: 8

	last-error: none
	module-name: none
	module-kind: 0
	functions: make block! 48
	function-ids: make hash! 48
	function-count: 0

	emit: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
	]

	fail: func [code [integer!] message [string! block!] /local error][
		error: make object! [code: 0 message: none]
		error/code: code
		error/message: form either block? message [reduce message][message]
		last-error: error
		throw/name error 'rsir-error
	]

	valid-name?: func [name [string!]][
		all [not empty? name not find to binary! name 0]
	]

	return-kind: func [spec [block!]][
		if empty? spec [return 'void]
		unless all [
			(length? spec) = 2
			spec/1 = to set-word! 'return
			block? spec/2
			(length? spec/2) = 1
		][return none]
		either any [spec/2 = [integer!] spec/2 = [int32!]] ['i32][none]
	]

	compile-body: func [
		kind [word!]
		body [block!]
		instructions [binary!]
		/local value callee position
	][
		either kind = 'void [
			unless empty? body [
				fail ERROR-UNSUPPORTED "void function body must be empty"
			]
			emit instructions [2 0 0 0 0]              ; return
			1
		][
			value: case [
				(length? body) = 1 [body/1]
				all [(length? body) = 2 body/1 = 'return] [body/2]
				true [none]
			]
			case [
				integer? value [
					emit instructions reduce [
						1 1 1 0 value                         ; literal -> value 1
					]
				]
				word? value [
					callee: select function-ids value
					unless integer? callee [
						fail ERROR-REFERENCE ["unknown function " mold value]
					]
					position: skip functions ((callee - 1) * 3)
					unless position/2 = 'i32 [
						fail ERROR-REFERENCE [
							"function " mold value " does not return i32"
						]
					]
					emit instructions reduce [
						3 1 1 callee 0                        ; call -> value 1
					]
				]
				true [
					fail ERROR-UNSUPPORTED
						"i32 body must return an integer literal or zero-argument call"
				]
			]
			emit instructions [2 1 0 1 0]              ; return value 1
			2
		]
	]

	compile-function: func [
		name [set-word!]
		spec body [block!]
		/local kind spelling key id
	][
		spelling: form key: to word! name
		unless valid-name? spelling [
			fail ERROR-NAME "invalid RSIR function name"
		]
		if select function-ids key [
			fail ERROR-DUPLICATE ["duplicate function " mold key]
		]
		unless kind: return-kind spec [
			fail ERROR-UNSUPPORTED
				"function parameters, attributes, locals, or return type are unsupported"
		]
		id: function-count + 1
		repend function-ids [key id]
		append functions spelling
		append functions kind
		append/only functions body
		function-count: id
	]

	compile-source: func [source [block!] /local header position name spec body][
		unless all [not tail? source source/1 = 'Red/System] [
			fail ERROR-ARGUMENTS "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2] [
			fail ERROR-ARGUMENTS "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]] [
			fail ERROR-ARGUMENTS "invalid Red/System program header"
		]

		position: skip source 2
		unless parse position [
			any [
				set name set-word!
				['func | 'function]
				set spec block!
				set body block!
				(compile-function name spec body)
			]
		][
			fail ERROR-UNSUPPORTED "RSIR frontend requires top-level function declarations"
		]
		if function-count < 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
	]

	write-rsir: func [limit [integer!] /local module strings records instructions output
		position name kind body name-bytes name-offset first-instruction count
		instruction-count size entry
	][
		module: either module-name [to binary! module-name][#{}]
		strings: make binary! ((length? module) + (function-count * 16))
		append strings module
		records: make binary! (function-count * 24)
		instructions: make binary! (function-count * 40)
		position: functions
		first-instruction: 1
		while [not tail? position][
			name: position/1
			kind: position/2
			body: position/3
			name-bytes: to binary! name
			name-offset: length? strings
			append strings name-bytes
			count: compile-body kind body instructions
			emit records reduce [
				name-offset length? name-bytes
				either kind = 'void [0][1]
				first-instruction count 0
			]
			first-instruction: first-instruction + count
			position: skip position 3
		]
		instruction-count: first-instruction - 1

		; Header, source-order function records, instructions, then raw names.
		size: 32 + (length? records) + (length? instructions) + (length? strings)
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [function-count][0]
		output: make binary! size
		emit output reduce [
			size module-kind entry
			0 length? module
			function-count instruction-count length? strings
		]
		append output records
		append output instructions
		append output strings
		output
	]

	compile: func [
		source [block!]
		name [string! none!]
		kind image [word!]
		/limit max-bytes [integer!]
		/local result
	][
		last-error: none
		result: catch/name [
			if all [name not valid-name? name][
				fail ERROR-NAME "invalid RSIR module name"
			]
			unless image = 'executable [
				fail ERROR-KIND "unsupported RSIR image kind"
			]
			module-kind: case [
				kind = 'user [1]
				kind = 'support [2]
				kind = 'glue [3]
				true [0]
			]
			if module-kind = 0 [
				fail ERROR-KIND "unsupported RSIR module kind"
			]

			module-name: either name [copy name][none]
			clear functions
			clear function-ids
			function-count: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
