Red [
	Title: "Red compiler Unicode encoders"
	File:  %unicode.red
]

unicode: context [
	to-utf16le: func [
		text [string!]
		/length
		/local output units codepoint
	][
		output: make binary! ((length? text) * 2)
		units: 0
		foreach character text [
			codepoint: to integer! character
			either codepoint < 65536 [
				units: units + 1
				unless length [
					append output int-to-bin/to-bin16 codepoint
				]
			][
				units: units + 2
				unless length [
					codepoint: codepoint - 65536
					append output int-to-bin/to-bin16 (
						55296 + (shift/logical codepoint 10)
					)
					append output int-to-bin/to-bin16 (
						56320 + (codepoint and 1023)
					)
				]
			]
		]
		either length [units][output]
	]
]

; Transitional name used by the current compiler and PE writer.
utf8-to-utf16: :unicode/to-utf16le
