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

item: declare member-cell!
print-line set-integer-member item 41
print-line set-logic-member item true
print-line set-float-member item 2.5
