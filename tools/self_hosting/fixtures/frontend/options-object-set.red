Red [Title: "Compiled options object fixture"]

make-options: does [
	make object! [
		target: "Windows"
		output: none
		source: none
		release?: false
		debug?: false
		static?: false
		no-runtime?: false
		dynamic-lib?: false
		red-only?: false
		dev-mode: none
		no-view?: false
		view-engine: none
		no-compress?: false
		show-func-map?: false
		show: none
		update-libRedRT?: false
		verbose: 0
		config: none
		help?: false
		version?: false
	]
]

set-source: func [/local options][
	options: make-options
	options/source: "red-bootstrap-windows.red"
	print ["source:" mold options/source]
	probe options
]

set-source
