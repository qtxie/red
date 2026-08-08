Red/System [
	Title: "Generated-code signed integer division benchmark"
]

leap-year-fast?: func [
	year [integer!]
	return: [logic!]
][
	all [
		(year and 3) = 0
		any [
			year % 100 <> 0
			year % 400 = 0
		]
	]
]

count-leap-years: func [
	iterations [integer!]
	return: [integer!]
	/local index year count
][
	index: 0
	count: 0
	while [index < iterations][
		year: 1600 + (index % 800)
		if leap-year-fast? year [count: count + 1]
		index: index + 1
	]
	count
]

print-line count-leap-years 20000000
