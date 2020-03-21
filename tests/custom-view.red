Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

probe "start"

window!: make face! [
	type: 'window
	gob: make gob! [
		type: 'window offset: 50x50 size: 800x800
		actors: reduce [
			'over func [face event][
				probe reduce [face/type event/offset event/flags]
			]
		]
	]
]

base!: make face! [
	type: 'base
	gob: make gob! [
		offset: 0x0 size: 100x100
		actors: reduce [
			'over func [face event][
				probe reduce [face/type event/offset event/flags]
			]
		]
	]
]

win: make window! [offset: 50x50 size: 800x800]

win/pane: reduce [
	child: make base! [
		offset: 100x50 size: 100x100 color: 255.0.0
		actors: object [
			on-over: func [face event][
				probe reduce [1 "over" face/type event/offset event/flags]
			]
			on-up: func [face event][
				probe reduce [1 "mouse up" face/type event/offset event/flags]
			]
			on-down: func [face event][
				probe reduce [1 "mouse down" face/type event/offset event/flags]
			]
			on-click: func [face event][
				probe reduce [1 "mouse click" face/type event/offset event/flags]
			]
		]
	]

	child2: make base! [
		offset: 150x50 size: 500x300 color: 255.255.255
		actors: object [
			on-over: func [face event][
				probe reduce [2 face/type event/offset event/flags]
			]
		]
		draw: [box 20x20 80x80 10]
	]
]

child2/pane: reduce [
	child21: make base! [
		offset: 100x50 size: 100x100 color: 0.222.0 text: "Hello Red"
		actors: object [
			on-over: func [face event][
				probe reduce [21 face/type event/offset event/flags]
				face/size: either find event/flags 'away [100x100][200x200]
			]
		]
	]
]

win/actors: make object! [
	on-over: func [face event][
		probe reduce [face/type event/offset event/flags]
	]
]

view win
probe "done"