Red/System [
	Title: "RSIR logic cast fixture"
]

sample!: alias struct! [value [integer!]]

check: func [
	return: [integer!]
	/local byte-value [byte!] integer-value [integer!]
		text [c-string!] pointer [pointer! [integer!]]
		object [sample!] truth [logic!]
][
	byte-value: #"^(FF)"
	truth: as logic! byte-value
	if not truth [return 1]

	integer-value: -1
	truth: as logic! integer-value
	if not truth [return 2]

	text: ""
	truth: as logic! text
	if not truth [return 3]

	pointer: as [pointer! [integer!]] 7FFFFFFFh
	truth: as logic! pointer
	if not truth [return 4]

	object: declare sample!
	truth: as logic! object
	if not truth [return 5]

	byte-value: #"^(00)"
	truth: as logic! byte-value
	if truth [return 6]

	pointer: as [pointer! [integer!]] 0
	truth: as logic! pointer
	if truth [return 7]

	73
]

quit check
