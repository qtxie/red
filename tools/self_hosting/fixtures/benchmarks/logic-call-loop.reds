Red/System [
	Title: "Generated-code materialized comparison call benchmark"
]

less-result?: func [
	left [integer!]
	right [integer!]
	return: [logic!]
][
	left < right
]

i: 0
count: 0
while [i < 40000000][
	if less-result? i 20000000 [count: count + 1]
	i: i + 1
]

print-line count
