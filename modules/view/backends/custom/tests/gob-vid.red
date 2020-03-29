Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

;; styles

btn-normal: object [
	background: 255.255.255
	border-radius: 4
	shadow: [
		0x3 1 -2 0.0.0.204
		0x2 2 0.0.0.220
		0x1 5 0.0.0.224
	]
]

btn-hover: object [
	background: 240.240.240
	border-radius: 4
	shadow: [
		0x3 1 -2 0.0.0.204
		0x2 2 0.0.0.220
		0x1 5 0.0.0.224
	]
]

btn-down: object [
	background: 210.210.210
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
	actors: reduce [
		'create func [gob _][
			probe "on-create"
		]
		'over func [gob event][
			gob/styles: either find event/flags 'away [btn-normal][btn-hover]
		]
		'down func [gob evt][
			gob/styles: btn-down
		]
		'up func [gob evt][
			gob/styles: btn-normal
		]
	]
	styles: btn-normal
]

register-widget 'base make gob! [
	flags: 'all-over
]

view [
	backdrop 102.204.255
	button 80x30 "Click Me" [probe "Hello Red"]
	base 100x100 on-over [probe event/offset] on-up [probe reduce ["on-up" event/offset]]
]

probe "done"