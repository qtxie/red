Red/System [
	Title: "O2 date arithmetic and two-address legalization fixture"
]

make-date: func [
	year [integer!]
	month [integer!]
	day [integer!]
	return: [integer!]
][
	(year << 17) or ((month << 12) or (day << 7))
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

print-line either (year-day make-date 2023 1 1) = 1 [1][0]
print-line either (year-day make-date 2023 2 28) = 59 [1][0]
print-line either (year-day make-date 2023 3 1) = 60 [1][0]
print-line either (year-day make-date 2024 3 1) = 61 [1][0]
print-line either (year-day make-date 2024 12 31) = 366 [1][0]
print-line either
	((date-to-days make-date 2024 3 1) - (date-to-days make-date 2024 2 29)) = 1
	[1]
	[0]
