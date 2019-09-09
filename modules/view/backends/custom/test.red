Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

probe "start"

win: make gob! [type: 'window size: 800x800]
child: make gob! [
	offset: 100x50 size: 300x300 color: 255.0.0
	actors: object [
		on-over: func [face event][
			probe reduce [face/type event/offset]
		]
	]
]
win/actors: make object! [
	on-over: func [face event][
		probe reduce [face/type event/offset]
	]
]
append win child
?? win

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