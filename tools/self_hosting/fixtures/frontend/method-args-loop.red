Red [Title: "Compiled method argument fixture"]

parser: context [
	parse: func [args [block!] /local index token][
		index: 1
		while [index <= length? args][
			token: to string! pick args index
			print token
			index: index + 1
		]
		true
	]
]

print parser/parse ["--version" "extra"]
