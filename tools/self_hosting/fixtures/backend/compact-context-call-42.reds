Red/System []

qualified: context [
	helper: func [return: [integer!]][42]
	inside: func [return: [integer!]][helper]
]

main: func [return: [integer!]][qualified/inside]
