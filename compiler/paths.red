Red [
	Title: "Red compiler path normalization"
	File:  %paths.red
]

compiler-paths: context [
	secure-clean: func [
		target [any-string!]
		/limit root [any-string!]
		/nocopy
		/local value root-value root-size absolute? trailing? parts stack
			minimum-depth segment output result
	][
		value: to string! copy target
		replace/all value #"\" #"/"
		absolute?: all [not empty? value (first value) = #"/"]
		trailing?: all [not empty? value (last value) = #"/"]
		minimum-depth: 0

		if limit [
			root-value: to string! copy root
			replace/all root-value #"\" #"/"
			while [all [(length? root-value) > 1 (last root-value) = #"/"]] [
				remove back tail root-value
			]
			root-size: length? root-value
			unless all [
				root-size <= length? value
				root-value = copy/part value root-size
				any [
					root-size = length? value
					(last root-value) = #"/"
					pick value (root-size + 1) = #"/"
				]
			][
				return either nocopy [target][copy target]
			]
			foreach part split root-value #"/" [
				unless empty? part [minimum-depth: minimum-depth + 1]
			]
		]

		stack: make block! 16
		parts: split value #"/"
		foreach segment parts [
			either any [empty? segment segment = "."] [
				none
			][
				either segment = ".." [
					if (length? stack) > minimum-depth [
						remove back tail stack
					]
				][
					append stack segment
				]
			]
		]

		output: copy either absolute? ["/"][""]
		foreach segment stack [
			if all [not empty? output (last output) <> #"/"] [
				append output #"/"
			]
			append output segment
		]
		if all [
			trailing?
			not empty? output
			(last output) <> #"/"
		][
			append output #"/"
		]
		result: case [
			file? target [to file! output]
			url? target [to url! output]
			true [output]
		]
		either nocopy [
			clear target
			append target result
			target
		][
			result
		]
	]
]

; Transitional name used by the current loader and compiler.
secure-clean-path: :compiler-paths/secure-clean
