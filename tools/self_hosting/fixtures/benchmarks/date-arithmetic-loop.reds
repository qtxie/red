Red/System [
	Title: "Generated-code date arithmetic benchmark"
]

date-to-days: func [
	date [integer!]
	return: [integer!]
	/local y m d
][
	y: date >> 17
	m: (date >> 12) and 0Fh
	d: (date >> 7) and 1Fh
	m: (m + 9) % 12
	y: y - (m / 10)
	365 * y + (y / 4) - (y / 100) + (y / 400) + ((m * 306 + 5) / 10) + (d - 1)
]

jan-first-of: func [
	date [integer!]
	return: [integer!]
][
	date: (date and FFFFF07Fh) or (1 << 7)
	date: (date and FFFF0FFFh) or (1 << 12)
	date-to-days date
]

year-day: func [
	date [integer!]
	return: [integer!]
][
	(date-to-days date) - (jan-first-of date) + 1
]

hot-date-loop: func [
	iterations [integer!]
	date [integer!]
	return: [integer!]
	/local index checksum
][
	index: 0
	checksum: 0
	while [index < iterations][
		checksum: checksum + (year-day date)
		index: index + 1
	]
	checksum
]

print-line hot-date-loop 10000000 ((2024 << 17) or ((12 << 12) or (31 << 7)))
