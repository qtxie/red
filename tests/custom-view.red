Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

probe "start"

win: make gob! [type: 'window offset: 50x50 size: 800x800]
child: make gob! [
	offset: 100x50 size: 100x100 color: 255.0.0
	actors: object [
		on-over: func [face event][
			probe reduce [1 face/type event/offset event/flags]
		]
	]
]

child2: make gob! [
	offset: 150x50 size: 500x300 color: 255.255.255
	actors: object [
		on-over: func [face event][
			probe reduce [2 face/type event/offset event/flags]
		]
	]
]

child21: make gob! [
	offset: 100x50 size: 100x100 color: 0.222.0
	actors: object [
		on-over: func [face event][
			probe reduce [21 face/type event/offset event/flags]
		]
	]
	draw: [box 20x20 80x80 10 text 20x40 "Hello Red!"]
]
child22: make gob! [
	offset: 250x50 size: 100x100 color: 0.0.223
	actors: object [
		on-over: func [face event][
			probe reduce [22 face/type event/offset event/flags]
		]
	]
	styles: object [
		border: [5 solid 0.255.0]
		shadow: [0x0 12 0.0.0]
	]
]

append child2 child21
append child2 child22

win/actors: make object! [
	on-over: func [face event][
		probe reduce [face/type event/offset event/flags]
	]
]
append win child
append win child2

;t1: now/time/precise
;loop 10000 [
;	append win make gob! compose [
;		size:	(random 50x50)
;		offset: (random 800x800)
;		color:	(random 255.255.255.255)
;	]
;]
;t2: now/time/precise

probe rejoin ["Number of Children: " length? win]
;probe rejoin ["Created 10K GOBs in " round/to 1000 * to-float t2 - t1 .1 "ms"]

view win
probe "done"