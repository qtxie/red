Red [
	Title: "Red compiler Crush adapter"
	File:  %compiler/crush.red
]

; The runtime already contains the Crush implementation used by Redbin. Keep
; the compiler boundary in ordinary Red so interpreted and compiled compilers
; use the same native API.
compiler-crush: context [
	; Some hosts expose compress/decompress without Crush (for example older
	; red-console builds). Redbin compression is optional: unavailable Crush
	; must degrade to uncompressed Redbin rather than abort the compile.
	available?: false
	native-compress: none
	native-decompress: none

	probe-crush: has [payload result][
		payload: make binary! 200
		append/dup payload #"A" 200
		set/any 'result try [native-compress payload 'crush]
		all [not error? :result binary? :result]
	]

	if all [value? 'compress value? 'decompress][
		native-compress: :compress
		native-decompress: :decompress
		available?: probe-crush
	]

	compress: func [source [binary!] /local result][
		if any [not available? (length? source) < 128][return none]
		set/any 'result try [native-compress source 'crush]
		either all [not error? :result binary? :result][:result][none]
	]

	decompress: func [source [binary!] /local result][
		unless available? [cause-error 'script 'not-defined [crush]]
		set/any 'result try [native-decompress source 'crush]
		if error? :result [cause-error 'script 'invalid-data []]
		:result
	]
]
