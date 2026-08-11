Red [
	Title: "Hybrid compiler wire schema generator"
	File:  %wire-schema-generator.red
]

compiler-wire-schema-generator: context [
	limit: 2147483648

	fail: func [message [string! block!]][
		do make error! either block? message [rejoin message][message]
	]

	upper-name: func [value [word!]][
		uppercase copy form value
	]

	magic-integer: func [value [string!] /local bytes result factor][
		unless (length? value) = 4 [fail ["wire magic must contain four bytes: " mold value]]
		bytes: to binary! value
		unless (length? bytes) = 4 [fail ["wire magic must be four ASCII bytes: " mold value]]
		result: 0
		factor: 1
		foreach byte bytes [
			if byte > 127 [fail ["wire magic must be ASCII: " mold value]]
			result: result + (byte * factor)
			factor: factor * 256
		]
		if result >= limit [fail ["wire magic exceeds signed metadata range: " mold value]]
		result
	]

	validate-enums: func [enums [block!] /local group entries groups names values][
		unless even? length? enums [fail "wire enum list must contain name/body pairs"]
		groups: make block! length? enums
		foreach [group entries] enums [
			unless all [word? group block? entries even? length? entries][
				fail ["invalid wire enum group: " mold group]
			]
			if find groups group [fail ["duplicate wire enum group: " mold group]]
			append groups group
			names: make block! length? entries
			values: make block! length? entries
			foreach [name value] entries [
				unless all [word? name integer? value value >= 0 value < limit][
					fail ["invalid wire enum entry: " mold reduce [group name value]]
				]
				if find names name [fail ["duplicate wire enum name: " mold reduce [group name]]]
				if find values value [fail ["duplicate wire enum value: " mold reduce [group value]]]
				append names name
				append values value
			]
		]
		true
	]

	validate-records: func [
		records [block!]
		/local name definition record-names size fields field-names ranges total field-end
	][
		unless even? length? records [fail "wire record list must contain name/body pairs"]
		record-names: make block! length? records
		foreach [name definition] records [
			unless all [word? name block? definition][
				fail ["invalid wire record: " mold name]
			]
			if find record-names name [fail ["duplicate wire record: " mold name]]
			append record-names name
			size: select definition 'size
			fields: select definition 'fields
			unless all [integer? size size > 0 size < limit block? fields][
				fail ["invalid wire record definition: " mold name]
			]
			unless zero? ((length? fields) // 3) [
				fail ["wire fields must be name/offset/width triples: " mold name]
			]
			ranges: make block! length? fields
			field-names: make block! length? fields
			total: 0
			foreach [field offset width] fields [
				unless all [
					word? field
					integer? offset
					integer? width
					offset >= 0
					width > 0
					offset < limit
					width < limit
				][
					fail ["invalid wire field: " mold reduce [name field offset width]]
				]
				if find field-names field [
					fail ["duplicate wire field: " mold reduce [name field]]
				]
				append field-names field
				field-end: offset + width
				if any [field-end > size field-end >= limit][
					fail ["wire field exceeds record: " mold reduce [name field offset width size]]
				]
				foreach [old-start old-end old-field] ranges [
					if all [offset < old-end field-end > old-start][
						fail ["overlapping wire fields: " mold reduce [name old-field field]]
					]
				]
				repend ranges [offset field-end field]
				total: total + width
			]
			unless total = size [
				fail ["wire fields do not cover record: " mold reduce [name total size]]
			]
		]
		true
	]

	validate: func [
		spec [block!]
		/local required section body sections version magics enums records names values encoded
	][
		unless even? length? spec [fail "wire schema must contain section/body pairs"]
		required: [version magics enums records]
		sections: make block! length? spec
		foreach [section body] spec [
			unless all [word? section block? body find required section][
				fail ["unknown wire schema section: " mold section]
			]
			if find sections section [fail ["duplicate wire schema section: " mold section]]
			append sections section
		]
		foreach section required [
			unless find sections section [fail ["missing wire schema section: " mold section]]
		]

		version: select spec 'version
		magics: select spec 'magics
		enums: select spec 'enums
		records: select spec 'records
		unless all [
			(length? version) = 4
			version/1 = 'major
			integer? version/2
			version/2 >= 0
			version/2 < limit
			version/3 = 'minor
			integer? version/4
			version/4 >= 0
			version/4 < limit
		][fail "invalid wire schema version"]
		unless even? length? magics [fail "wire magic list must contain name/value pairs"]
		names: make block! length? magics
		values: make block! length? magics
		foreach [name value] magics [
			unless all [word? name string? value][fail "invalid wire magic entry"]
			if find names name [fail ["duplicate wire magic: " mold name]]
			append names name
			encoded: magic-integer value
			if find values encoded [fail ["duplicate wire magic value: " mold value]]
			append values encoded
		]
		validate-enums enums
		validate-records records
		true
	]

	fingerprint: func [spec [block!] /local digest result][
		validate spec
		digest: checksum mold/flat/all spec 'SHA256
		result: 0
		repeat index 4 [result: (result * 256) + digest/:index]
		result and 2147483647
	]

	append-constant: func [
		output [block!]
		name [string!]
		value [integer!]
		/local constant-name
	][
		constant-name: to word! name
		if find/skip output constant-name 2 [
			fail ["duplicate generated wire constant: " name]
		]
		repend output [constant-name value]
	]

	constants: func [spec [block!] /local output version magics enums records definition fields][
		validate spec
		output: make block! 1024
		version: select spec 'version
		append-constant output "WIRE_VERSION_MAJOR" select version 'major
		append-constant output "WIRE_VERSION_MINOR" select version 'minor
		foreach [name value] select spec 'magics [
			append-constant output rejoin ["WIRE_MAGIC_" upper-name name] magic-integer value
		]
		foreach [group entries] select spec 'enums [
			foreach [name value] entries [
				append-constant output rejoin [
					"WIRE_" upper-name group "_" upper-name name
				] value
			]
		]
		foreach [name definition] select spec 'records [
			append-constant output rejoin ["WIRE_" upper-name name "_SIZE"] select definition 'size
			fields: select definition 'fields
			foreach [field offset width] fields [
				append-constant output rejoin [
					"WIRE_" upper-name name "_" upper-name field "_OFFSET"
				] offset
				append-constant output rejoin [
					"WIRE_" upper-name name "_" upper-name field "_WIDTH"
				] width
			]
		]
		append-constant output "WIRE_SCHEMA_FINGERPRINT" fingerprint spec
		output
	]

	render-red: func [spec [block!] /local output][
		output: make string! 65536
		append output {Red [
	Title: "Generated hybrid compiler wire constants"
	File:  %wire-schema.red
]

; Generated by tools/self_hosting/generate-wire-schema.red. Do not edit.
compiler-wire-schema: context [
}
		foreach [name value] constants spec [
			append output rejoin [tab form name ": " value newline]
		]
		append output "]^/"
		output
	]

	render-reds: func [spec [block!] /local output][
		output: make string! 65536
		append output {Red/System [
	Title: "Generated hybrid compiler wire constants"
	File:  %wire-schema.reds
]

; Generated by tools/self_hosting/generate-wire-schema.red. Do not edit.
#enum compiler-wire-schema! [
}
		foreach [name value] constants spec [
			append output rejoin [tab form name ": " value newline]
		]
		append output "]^/"
		output
	]

	write-generated: func [
		spec [block!]
		red-path [file!]
		reds-path [file!]
	][
		make-dir/deep first split-path red-path
		make-dir/deep first split-path reds-path
		; Binary writes preserve the generated LF bytes on every host.  Text
		; writes translate line endings on Windows and make checked-in output
		; depend on the machine running the generator.
		write red-path to binary! render-red spec
		write reds-path to binary! render-reds spec
		fingerprint spec
	]
]
