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

	record-size: func [records [block!] record [word!] /local definition][
		if record = 'BYTE [return 1]
		definition: select records record
		unless block? definition [fail ["unknown wire profile record: " mold record]]
		select definition 'size
	]

	profile-minimum-size: func [
		records [block!]
		entries [block!]
		/local required-count section record requirement cardinality alignment cursor size remainder
	][
		required-count: 0
		foreach [section record requirement cardinality alignment] entries [
			if requirement = 'REQUIRED [required-count: required-count + 1]
		]
		cursor: (record-size records 'HEADER)
			+ (required-count * (record-size records 'DIRECTORY))
		foreach [section record requirement cardinality alignment] entries [
			if all [requirement = 'REQUIRED cardinality <> 'ANY][
				remainder: cursor // alignment
				if remainder <> 0 [cursor: cursor + alignment - remainder]
				size: record-size records record
				cursor: cursor + size
			]
		]
		cursor
	]

	validate-profiles: func [
		profiles [block!]
		magics [block!]
		enums [block!]
		records [block!]
		/local messages message entries enum-name section-enums seen-sections expected-kind
			section record requirement cardinality alignment kind size saw-optional? cardinalities
	][
		unless even? length? profiles [fail "wire profiles must contain message/body pairs"]
		messages: make block! length? profiles
		cardinalities: select enums 'SECTION_CARDINALITY
		unless block? cardinalities [fail "wire profiles require SECTION_CARDINALITY enum"]

		foreach [message entries] profiles [
			unless all [
				word? message
				string? select magics message
				block? entries
				zero? ((length? entries) // 5)
			][fail ["invalid wire message profile: " mold message]]
			if find messages message [fail ["duplicate wire message profile: " mold message]]
			append messages message

			enum-name: to word! rejoin [form message "_SECTION"]
			section-enums: select enums enum-name
			unless block? section-enums [
				fail ["missing section enum for wire profile: " mold message]
			]
			unless (((length? entries) / 5) = ((length? section-enums) / 2)) [
				fail ["wire profile does not cover every section: " mold message]
			]

			seen-sections: make block! length? entries
			expected-kind: 1
			saw-optional?: no
			foreach [section record requirement cardinality alignment] entries [
				kind: select section-enums section
				size: record-size records record
				unless all [
					word? section
					integer? kind
					kind = expected-kind
					word? record
					find [REQUIRED OPTIONAL] requirement
					word? cardinality
					not none? select cardinalities cardinality
					integer? alignment
					alignment > 0
					alignment < limit
					zero? (alignment and (alignment - 1))
					alignment <= size
				][
					fail ["invalid wire profile section: " mold reduce [
						message section record requirement cardinality alignment
					]]
				]
				if find seen-sections section [
					fail ["duplicate wire profile section: " mold reduce [message section]]
				]
				append seen-sections section
				either requirement = 'OPTIONAL [
					saw-optional?: yes
				][
					if saw-optional? [
						fail ["required section follows optional section: " mold reduce [message section]]
					]
				]
				expected-kind: expected-kind + 1
			]
		]

		unless ((length? messages) = ((length? magics) / 2)) [
			fail "wire profiles must cover every message magic"
		]
		foreach [message value] magics [
			unless find messages message [fail ["missing wire message profile: " mold message]]
		]
		true
	]

	validate: func [
		spec [block!]
		/local required section body sections version magics enums profiles records names values encoded
	][
		unless even? length? spec [fail "wire schema must contain section/body pairs"]
		required: [version magics enums profiles records]
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
		profiles: select spec 'profiles
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
		validate-profiles profiles magics enums records
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

	constants: func [
		spec [block!]
		/local output version magics enums profiles records definition fields message entries
			section record requirement cardinality alignment required-count prefix size value minimum-size
	][
		validate spec
		output: make block! 2048
		version: select spec 'version
		enums: select spec 'enums
		profiles: select spec 'profiles
		records: select spec 'records
		append-constant output "WIRE_VERSION_MAJOR" select version 'major
		append-constant output "WIRE_VERSION_MINOR" select version 'minor
		foreach [name value] select spec 'magics [
			append-constant output rejoin ["WIRE_MAGIC_" upper-name name] magic-integer value
		]
		foreach [group entries] enums [
			foreach [name value] entries [
				append-constant output rejoin [
					"WIRE_" upper-name group "_" upper-name name
				] value
			]
		]
		foreach [name definition] records [
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
		foreach [message entries] profiles [
			required-count: 0
			foreach [section record requirement cardinality alignment] entries [
				if requirement = 'REQUIRED [required-count: required-count + 1]
			]
			append-constant output rejoin [
				"WIRE_" upper-name message "_REQUIRED_SECTION_COUNT"
			] required-count
			append-constant output rejoin [
				"WIRE_" upper-name message "_KNOWN_SECTION_COUNT"
			] ((length? entries) / 5)
			minimum-size: profile-minimum-size records entries
			append-constant output rejoin [
				"WIRE_" upper-name message "_MINIMUM_SIZE"
			] minimum-size
			foreach [section record requirement cardinality alignment] entries [
				prefix: rejoin [
					"WIRE_" upper-name message "_SECTION_" upper-name section
				]
				size: record-size records record
				value: select select enums 'SECTION_CARDINALITY cardinality
				append-constant output rejoin [prefix "_RECORD_SIZE"] size
				append-constant output rejoin [prefix "_ALIGNMENT"] alignment
				append-constant output rejoin [prefix "_CARDINALITY"] value
				append-constant output rejoin [prefix "_REQUIRED"] either requirement = 'REQUIRED [1][0]
			]
		]
		append-constant output "WIRE_SCHEMA_FINGERPRINT" fingerprint spec
		output
	]

	render-red: func [
		spec [block!]
		/local output records enums message entries section record requirement cardinality alignment
	][
		output: make string! 65536
		records: select spec 'records
		enums: select spec 'enums
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
		append output "^/^-profiles: context [^/"
		foreach [message entries] select spec 'profiles [
			append output rejoin [tab tab form message ": context [" newline]
			append output rejoin [
				tab tab tab "required-count: "
				length? collect [
					foreach [section record requirement cardinality alignment] entries [
						if requirement = 'REQUIRED [keep section]
					]
				]
				newline
			]
			append output rejoin [tab tab tab "known-count: " ((length? entries) / 5) newline]
			append output rejoin [tab tab tab "record-sizes: ["]
			foreach [section record requirement cardinality alignment] entries [
				append output rejoin [" " record-size records record]
			]
			append output " ]^/"
			append output rejoin [tab tab tab "alignments: ["]
			foreach [section record requirement cardinality alignment] entries [
				append output rejoin [" " alignment]
			]
			append output " ]^/"
			append output rejoin [tab tab tab "cardinalities: ["]
			foreach [section record requirement cardinality alignment] entries [
				append output rejoin [
					" " select select enums 'SECTION_CARDINALITY cardinality
				]
			]
			append output " ]^/"
			append output rejoin [tab tab tab "required: ["]
			foreach [section record requirement cardinality alignment] entries [
				append output either requirement = 'REQUIRED [" 1"][" 0"]
			]
			append output " ]^/"
			append output rejoin [tab tab "]" newline]
		]
		append output rejoin [tab "]" newline "]" newline]
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
