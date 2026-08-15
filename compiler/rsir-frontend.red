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

	last-error: none
	module-name: none
	module-kind: 0
	function-name: none
	function-kind: none
	function-value: 0
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

	compile-body: func [kind [word!] body [block!] /local value][
		either kind = 'void [
			unless empty? body [
				fail ERROR-UNSUPPORTED "void function body must be empty"
			]
		][
			value: case [
				(length? body) = 1 [body/1]
				all [(length? body) = 2 body/1 = 'return] [body/2]
				true [none]
			]
			unless integer? value [
				fail ERROR-UNSUPPORTED
					"i32 function body must return one integer literal"
			]
			function-value: value
		]
	]

	compile-function: func [name [set-word!] spec body [block!] /local kind][
		if function-count <> 0 [
			fail ERROR-FUNCTION-COUNT "RSIR frontend currently supports one function"
		]
		function-name: form to word! name
		unless valid-name? function-name [
			fail ERROR-NAME "invalid RSIR function name"
		]
		unless kind: return-kind spec [
			fail ERROR-UNSUPPORTED
				"function parameters, attributes, locals, or return type are unsupported"
		]
		function-kind: kind
		function-count: 1
		compile-body kind body
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
		if function-count <> 1 [
			fail ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
	]

	write-rsir: func [limit [integer!] /local module function-bytes strings instructions output
		instruction-count size entry
	][
		module: either module-name [to binary! module-name][#{}]
		function-bytes: to binary! function-name
		strings: make binary! ((length? module) + (length? function-bytes))
		append strings module
		append strings function-bytes

		instructions: make binary! either function-kind = 'void [20][40]
		either function-kind = 'void [
			emit instructions [2 0 0 0 0]                  ; return
			instruction-count: 1
		][
			emit instructions reduce [
				1 1 1 0 function-value                       ; i32 literal -> value 1
				2 1 0 1 0                                    ; return value 1
			]
			instruction-count: 2
		]

		; Header (8 words), one function record (6 words), instructions, strings.
		size: 32 + 24 + (length? instructions) + (length? strings)
		if any [limit <= 0 size > limit] [
			fail ERROR-LIMIT "RSIR output exceeds its limit"
		]
		entry: either module-kind = 3 [1][0]
		output: make binary! size
		emit output reduce [
			size module-kind entry
			0 length? module
			1 instruction-count length? strings
		]
		emit output reduce [
			length? module length? function-bytes
			either function-kind = 'void [0][1]
			1 instruction-count 0
		]
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
			function-name: none
			function-kind: none
			function-value: 0
			function-count: 0
			compile-source source
			write-rsir any [max-bytes DEFAULT-MAX-BYTES]
		] 'rsir-error
		either same? result last-error [none][result]
	]
]
