Red [
	Title: "Red compiler Redbin adapter"
	File:  %compiler/redbin.red
]

compiler-redbin: context [
	codec: select system/codecs 'redbin
	magic: #{52454442494E}
	last-error: none

	encode: func [
		value
		/fat
		/local saved-compact? outcome
	][
		last-error: none
		saved-compact?: codec/compact?
		codec/compact?: not fat
		outcome: try [reduce ['ok save/as none :value 'redbin]]
		codec/compact?: saved-compact?
		either error? :outcome [
			last-error: :outcome
			none
		][
			outcome/2
		]
	]

	decode: func [payload [binary! file!] /local outcome][
		last-error: none
		outcome: try [reduce ['ok load/as payload 'redbin]]
		either error? :outcome [
			last-error: :outcome
			none
		][
			outcome/2
		]
	]

	header?: func [payload [binary!]][
		all [
			8 <= length? payload
			magic = copy/part payload 6
		]
	]

	version-of: func [payload [binary!]][
		either header? payload [to integer! payload/7][none]
	]

	flags-of: func [payload [binary!]][
		either header? payload [to integer! payload/8][none]
	]

	compact?: func [payload [binary!] /local flags][
		flags: flags-of payload
		all [integer? flags (flags and 1) <> 0]
	]

	compressed?: func [payload [binary!] /local flags][
		flags: flags-of payload
		all [integer? flags (flags and 2) <> 0]
	]

	symbol-table?: func [payload [binary!] /local flags][
		flags: flags-of payload
		all [integer? flags (flags and 4) <> 0]
	]
]
