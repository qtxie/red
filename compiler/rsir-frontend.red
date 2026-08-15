Red [
	Title: "Red/System to RSIR compiler frontend"
	File:  %rsir-frontend.red
]

unless value? 'int-to-bin [do %int-to-bin.red]

compiler-rsir-frontend: context [
	; RSIR values used directly by this frontend slice.
	magic: 1380537170
	target-x64: abi-win64: endian-little: 1
	header-size: 64
	directory-size: 32
	fingerprint: 1783469997
	module-user: 2
	module-support: 3
	module-glue: 4
	image-executable: 1
	type-void: 1
	type-integer: 3
	type-signed: 1
	gc-none: 0
	call-red-system: 1
	symbol-function: 1
	linkage-internal: 2
	visibility-hidden: 2
	constant-scalar: 2
	value-instruction: 2
	value-no-flags: 0
	operand-value: 1
	operand-constant: 2
	operand-no-flags: 0
	effect-control: 256
	alias-none: 0
	op-constant: 1
	op-return: 41

	; name, flags, record size, alignment.  Indexed sections use flags 2 + 4.
	sections: [
		module               0 32 4
		data-layout          0 32 4
		strings              6  8 4
		string-data          0  1 1
		files                6 16 4
		file-checksum-data   0  1 1
		types                0 40 4
		fields               0 32 4
		signatures           0 32 4
		parameters           0 32 4
		symbols              6 32 4
		constants            0 32 4
		constant-data        0  1 1
		constant-parts       0 32 4
		constant-bindings    6  8 4
		globals              0 32 4
		imports              6 24 4
		exports              6 16 4
		functions            0 40 4
		locals               0 32 4
		blocks               0 32 4
		edges                0 24 4
		values               0 24 4
		instructions         0 48 4
		operands             0 16 4
		calls                0 32 4
		target-fragments     0 32 4
		source-locations     6 16 4
		exception-regions    0 24 4
		exception-blocks     0  8 4
		subroutines          0 32 4
		subroutine-blocks    0  8 4
	]

	ERROR-ARGUMENTS: 1
	ERROR-NAME: 2
	ERROR-KIND: 3
	ERROR-LIMIT: 4
	ERROR-SERIALIZE: 5
	ERROR-UNSUPPORTED: 6
	ERROR-FUNCTION-COUNT: 7
	DEFAULT-MAX-BYTES: 16777216

	last-error: none
	module-name: function-name: module-kind: none
	module-kind-id: image-kind-id: output-limit: function-count: 0
	block-instruction-count: 0

	types: make binary! 80
	signatures: make binary! 32
	symbols: make binary! 32
	constants: make binary! 64
	constant-data: make binary! 16
	functions: make binary! 40
	blocks: make binary! 32
	values: make binary! 48
	instructions: make binary! 96
	operands: make binary! 32

	emit-words: func [output [binary!] values [block!] /local value][
		foreach value values [append output int-to-bin/to-bin32 value]
		output
	]

	throw-error: func [code [integer!] message [string! block!] /local record][
		record: make object! [code: 0 message: none]
		record/code: code
		record/message: form either block? message [reduce message][message]
		last-error: record
		throw/name record 'rsir-frontend-error
	]

	valid-name?: func [name [string!]][
		all [not empty? name not find to binary! name 0]
	]

	init-module: func [
		name [string! none!]
		kind image [word!]
		limit [integer!]
	][
		if limit <= 0 [throw-error ERROR-LIMIT "invalid RSIR output limit"]
		if all [name not valid-name? name][
			throw-error ERROR-NAME "invalid RSIR module name"
		]
		module-kind: kind
		module-kind-id: switch/default kind [
			user [module-user]
			support [module-support]
			glue [module-glue]
		][throw-error ERROR-KIND "unsupported RSIR module kind"]
		unless image = 'executable [
			throw-error ERROR-KIND "unsupported RSIR image kind"
		]
		image-kind-id: image-executable

		module-name: either name [copy name][none]
		output-limit: limit
		function-name: none
		function-count: 0
		block-instruction-count: 0
		foreach table [
			types signatures symbols constants functions blocks
			values instructions operands
		][clear get table]
		clear constant-data
		emit-words types reduce [
			type-void 0 0 0 0 0 0 0 0 gc-none
		]
	]

	function-return-kind: func [spec [block!]][
		if empty? spec [return 'void]
		unless all [
			(length? spec) = 2
			spec/1 = to set-word! 'return
			block? spec/2
			(length? spec/2) = 1
		][return none]
		case [
			spec/2 = [integer!] ['i32]
			spec/2 = [int32!] ['i32]
			true [none]
		]
	]

	next-id: func [table [binary!] record-width [integer!]][
		1 + to integer! ((length? table) / record-width)
	]

	bump-block: does [
		block-instruction-count: block-instruction-count + 1
	]

	emit-return: func [first-operand operand-count [integer!]][
		emit-words instructions reduce [
			1 op-return 0 0 0 0 first-operand operand-count
			effect-control alias-none 0 0
		]
		bump-block
	]

	emit-i32-constant: func [
		literal [integer!]
		/local constant-id instruction-id operand-id value-id data-offset
	][
		constant-id: next-id constants 32
		instruction-id: next-id instructions 48
		operand-id: next-id operands 16
		value-id: next-id values 24
		data-offset: length? constant-data

		emit-words constants reduce [
			2 constant-scalar 0 data-offset 4 0 0 0
		]
		append constant-data int-to-bin/to-bin32 literal
		emit-words values reduce [
			value-instruction instruction-id 0 2 1 value-no-flags
		]
		emit-words instructions reduce [
			1 op-constant 0 0 value-id 1 operand-id 1
			0 alias-none 0 0
		]
		emit-words operands reduce [
			operand-constant constant-id 0 operand-no-flags
		]
		bump-block
		value-id
	]

	compile-body: func [kind [word!] body [block!] /local expression value-id operand-id][
		either kind = 'void [
			unless empty? body [
				throw-error ERROR-UNSUPPORTED "void function body must be empty"
			]
			emit-return 0 0
		][
			expression: case [
				(length? body) = 1 [body/1]
				all [(length? body) = 2 body/1 = 'return] [body/2]
				true [none]
			]
			unless integer? expression [
				throw-error ERROR-UNSUPPORTED
					"i32 function body must return one integer literal"
			]
			value-id: emit-i32-constant expression
			operand-id: next-id operands 16
			emit-words operands reduce [
				operand-value value-id 0 operand-no-flags
			]
			emit-return operand-id 1
		]
	]

	compile-function: func [name [set-word!] spec body [block!] /local kind return-type][
		if function-count <> 0 [
			throw-error ERROR-FUNCTION-COUNT
				"RSIR frontend currently supports one function"
		]
		function-name: form to word! name
		unless valid-name? function-name [
			throw-error ERROR-NAME "invalid RSIR function name"
		]
		unless kind: function-return-kind spec [
			throw-error ERROR-UNSUPPORTED
				"function parameters, attributes, locals, or return type are unsupported"
		]

		function-count: 1
		return-type: either kind = 'void [1][2]
		if return-type = 2 [
			emit-words types reduce [
				type-integer type-signed 4 4 0 0 0 0 0 gc-none
			]
		]
		emit-words signatures reduce [
			call-red-system 0 return-type 0 0 0 0 0
		]
		emit-words symbols reduce [
			0 symbol-function linkage-internal visibility-hidden
			1 0 0 0
		]
		emit-words functions [1 1 0 1 1 1 0 0 0 0]
		compile-body kind body
		emit-words blocks reduce [
			1 0 1 block-instruction-count 0 0 0 0
		]
	]

	compile-source: func [source [block!] /local header position name spec body][
		unless all [not tail? source source/1 = 'Red/System] [
			throw-error ERROR-ARGUMENTS "source is not a Red/System program"
		]
		unless all [not tail? next source block? source/2] [
			throw-error ERROR-ARGUMENTS "missing Red/System program header"
		]
		header: source/2
		unless parse header [any [set-word! skip]] [
			throw-error ERROR-ARGUMENTS "invalid Red/System program header"
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
			throw-error ERROR-UNSUPPORTED
				"RSIR frontend requires top-level function declarations"
		]
		if function-count <> 1 [
			throw-error ERROR-FUNCTION-COUNT "RSIR module has no function"
		]
	]

	canonical-strings: func [
		/local source ordered value bytes records data offset
	][
		source: reduce ["" function-name]
		if module-name [append source module-name]
		ordered: sort/case copy source
		source: make block! length? ordered
		foreach value ordered [
			unless all [not empty? source strict-equal? value last source] [
				append source value
			]
		]
		records: make binary! ((length? source) * 8)
		data: make binary! 64
		offset: 0
		foreach value source [
			bytes: to binary! value
			append records int-to-bin/to-bin32 offset
			append records int-to-bin/to-bin32 length? bytes
			append data bytes
			offset: offset + length? bytes
		]
		reduce [records data source]
	]

	string-id: func [strings [block!] name [string!] /local id value][
		id: 1
		foreach value strings [
			if strict-equal? value name [return id]
			id: id + 1
		]
		none
	]

	align-size: func [size alignment [integer!] /local remainder][
		remainder: size // alignment
		if remainder <> 0 [size: size + alignment - remainder]
		size
	]

	write-rsir: func [
		/local strings module-id function-id entry symbols* module layout payloads
			section-count directory size kind section flags record-size alignment
			payload payload-size offset count output padding
	][
		strings: canonical-strings
		module-id: either module-name [string-id strings/3 module-name][0]
		function-id: string-id strings/3 function-name
		if any [none? module-id none? function-id] [
			throw-error ERROR-SERIALIZE "lost a canonical RSIR string ID"
		]
		entry: either module-kind = 'glue [1][0]
		symbols*: copy symbols
		change/part symbols* int-to-bin/to-bin32 function-id 4
		module: make binary! 32
		emit-words module reduce [
			module-id module-kind-id image-kind-id 0 0 entry 0 0
		]
		layout: make binary! 32
		emit-words layout [1 8 8 16 8 8 8 0]

		payloads: reduce [
			module layout
			strings/1 strings/2
			#{} #{}
			types #{} signatures #{} symbols*
			constants constant-data
			#{} #{} #{} #{} #{}
			functions #{} blocks #{} values instructions operands
			#{} #{} #{} #{} #{} #{} #{}
		]
		section-count: (length? sections) / 4
		unless (length? payloads) = section-count [
			throw-error ERROR-SERIALIZE "incomplete RSIR section list"
		]

		size: header-size + (section-count * directory-size)
		if size > output-limit [
			throw-error ERROR-LIMIT "RSIR output exceeds its limit"
		]
		directory: make binary! (section-count * directory-size)
		kind: 0
		foreach [section flags record-size alignment] sections [
			kind: kind + 1
			payload: pick payloads kind
			payload-size: length? payload
			offset: count: 0
			if payload-size > 0 [
				if (payload-size // record-size) <> 0 [
					throw-error ERROR-SERIALIZE ["invalid" section "section size"]
				]
				size: align-size size alignment
				offset: size
				count: payload-size / record-size
				size: size + payload-size
				if any [size < 0 size > output-limit] [
					throw-error ERROR-LIMIT "RSIR output exceeds its limit"
				]
			]
			emit-words directory reduce [
				kind flags offset payload-size count record-size alignment 0
			]
		]

		output: make binary! size
		append output int-to-bin/to-bin32 magic
		append output int-to-bin/to-bin16 1
		append output int-to-bin/to-bin16 0
		emit-words output reduce [
			header-size 0 size section-count header-size directory-size
			target-x64 abi-win64 endian-little 8 0 0 1 fingerprint
		]
		append output directory
		kind: 0
		foreach [section flags record-size alignment] sections [
			kind: kind + 1
			payload: pick payloads kind
			unless empty? payload [
				padding: (align-size length? output alignment) - length? output
				if padding > 0 [append/dup output 0 padding]
				append output payload
			]
		]
		unless (length? output) = size [
			throw-error ERROR-SERIALIZE "could not serialize RSIR"
		]
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
			init-module name kind image any [max-bytes DEFAULT-MAX-BYTES]
			compile-source source
			write-rsir
		] 'rsir-frontend-error
		either same? result last-error [none][result]
	]
]
