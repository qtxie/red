Red/System [
	Title: "O2 typed struct-member assignment coverage"
]

member-cell!: alias struct! [
	header [integer!]
	value  [integer!]
	flag   [logic!]
	ratio  [float!]
]

set-integer-member: func [
	item [member-cell!]
	value [integer!]
	return: [integer!]
][
	item/value: value
	value
]

set-logic-member: func [
	item [member-cell!]
	value [logic!]
	return: [logic!]
][
	item/flag: value
	value
]

set-float-member: func [
	item [member-cell!]
	value [float!]
	return: [float!]
][
	item/ratio: value
	value
]

get-integer-member: func [
	item [member-cell!]
	return: [integer!]
][
	item/value
]

get-logic-member: func [
	item [member-cell!]
	return: [logic!]
][
	item/flag
]

get-float-member: func [
	item [member-cell!]
	return: [float!]
][
	item/ratio
]

divide-float-member: func [
	item [member-cell!]
	divisor [float!]
	return: [float!]
][
	item/ratio: item/ratio / divisor
	item/ratio
]

divide-float-member-after-call: func [
	item [member-cell!]
	return: [float!]
	/local divisor [float!]
][
	divisor: get-float-member item
	item/ratio: item/ratio / divisor
	item/ratio
]

item: declare member-cell!
set-integer-member item 41
set-logic-member item true
set-float-member item 2.5
print-line get-integer-member item
print-line get-logic-member item
print-line get-float-member item
print-line divide-float-member item 2.0
print-line divide-float-member-after-call item
