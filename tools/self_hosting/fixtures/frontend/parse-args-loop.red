Red [Title: "Compiled parse-args loop fixture"]

parse-test: func [args [block!] /local index token][
	index: 1
	while [index <= length? args][
		token: to string! pick args index
		print token
		index: index + 1
	]
	true
]

print parse-test ["--version" "extra"]
