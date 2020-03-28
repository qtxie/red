Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

register-widget 'window make gob! [
	type: 'window offset: 50x50 size: 800x800 
	actors: reduce [
		'over func [gob event][
			probe reduce [gob/type gob/offset event/offset event/flags]
		]
		'resizing func [gob event][gob/size: event/offset]
	]
]

register-widget 'button make gob! [
	offset: 0x0 size: 100x100
	actors: reduce [
		'over func [gob event][
			gob/offset: gob/offset + 10x10
		]
	]
]

register-widget 'base make gob! [
	offset: 0x0 size: 100x100
	actors: reduce [
		'over func [gob event][
			probe reduce [gob/type gob/text gob/offset event/offset event/flags]
		]
	]
	styles: object [
		border: [10 solid 0.0.228]
		;border-radius: 5
		shadow: [0x0 20 -5 0.0.0]
	]
]

view []
probe "done"