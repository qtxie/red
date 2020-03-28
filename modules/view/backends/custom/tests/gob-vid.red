Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

;; styles

btn-normal: object [
	border-radius: 4
	shadow: [
		0x3 1 -2 0.0.0.204
		0x2 2 0.0.0.220
		0x1 5 0.0.0.224
	]
]

btn-down: object [
	border-radius: 4
	shadow: [
		0x3 7 -2 0.0.0.180
		0x2 8 0.0.0.200
		0x1 11 0.0.0.204
	]
]

;; widgets

register-widget 'window make gob! [
	type: 'window
	actors: reduce [
		'over func [gob event][
			probe reduce [gob/type gob/offset event/offset event/flags]
		]
	]
]

register-widget 'button make gob! [
	color: 255.255.255
	actors: reduce [
		'over func [gob event /local data][
			data: gob/data
			gob/color: either find event/flags 'away [data/1][data/2]
		]
		'down func [gob evt /local data][
			data: gob/data
			gob/color: data/3
			gob/styles: btn-down
		]
		'up func [gob evt /local data][
			data: gob/data
			gob/color: data/1
			gob/styles: btn-normal
		]
	]
	styles: btn-normal
	data: reduce [
		255.255.255		;-- normal color
		240.240.240		;-- hover color
		210.210.210		;-- down color
	]
]

register-widget 'base make gob! [
	color: 128.128.128
]

view [
	size 200x200
	button 80x30 "Click Me" [probe "Hello Red"]
]

probe "done"