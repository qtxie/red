Red [Title: "Compiled options context fixture"]

compiler-options: context [
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

	parse: func [args [block!] /local options index token][
		options: make-options
		index: 1
		while [index <= length? args][
			token: to string! pick args index
			if (first token) <> #"-" [options/source: token]
			index: index + 1
		]
		options
	]
]

probe compiler-options/parse ["red-bootstrap-windows.red"]
