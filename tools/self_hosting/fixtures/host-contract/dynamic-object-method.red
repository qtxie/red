Red [
	Title: "Dynamic object method host-contract probe"
]

holder: context [
	service: none

	invoke: func [value [integer!]][
		service/twice value
	]
]

holder/service: context [
	twice: func [value [integer!]][value * 2]
]

print holder/invoke 21
