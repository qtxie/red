Red/System [
	Title: "Nested by-value struct layout probe"
]

small!: alias struct! [
	one [integer!]
	two [integer!]
]

nested!: alias struct! [
	first [integer!]
	sub [small! value]
	last [integer!]
]

item: declare nested!
item/first: 11
item/sub/one: 22
item/sub/two: 33
item/last: 44
