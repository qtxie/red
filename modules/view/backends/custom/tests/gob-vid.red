Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

;; styles

btn-radius: 4
btn-shadow-normal: [
	0x3 1 -2 0.0.0.204
	0x2 2 0.0.0.220
	0x1 5 0.0.0.224
]
btn-shadow-down: [
	0x3 7 -2 0.0.0.180
	0x2 8 0.0.0.200
	0x1 11 0.0.0.204
]

btn-normal: object [
	background: 255.255.255
	text-color: blue
	border-radius: btn-radius
	shadow: btn-shadow-normal
]

btn-hover: object [
	background: 240.240.240
	border-radius: btn-radius
	shadow: btn-shadow-normal
]

btn-down: object [
	background: 210.210.210
	border-radius: btn-radius
	shadow: btn-shadow-down
]

gob-style!: object [
    state: none     ;-- Internal state info
    on-change*: function [word old new][
        ;-- update field
    ]
    on-deep-change*: function [owner word target action new index part][
        ;-- update field
    ]
]

;; widgets

register-widget 'window make gob! [
	type: 'window flags: 'all-over
]

register-widget 'button make gob! [
	actors: reduce [
		'create func [gob _][]
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

font-A: make font! [
	name: "Comic Sans MS"
	size: 10
	color: blue
	style: [bold italic underline]
	anti-alias?: yes
]

smiley: make image! [23x24 #{
F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2CCCC
CCCCCCCCDEDEDDF2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2
F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F292908F5C5951
444238615E496965515C594B4B494258554C8F8E8CDEDEDDF2F2F2F2F2F2F2F2
F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2999999312D2788
8462D0CB8DFEF9ACFEF9ACFEF9ACFEF9ACF5F0A6D0CB8D949068646253918F8C
E7E7E7F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2E7E7E76B695F6664
4EE8E39DFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACE1
DC9984805A6B695FE7E7E7F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2E7E7E76B695F
949068F5F0A6FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9
ACFEF9ACFEF9ACFEF9ACA29D6E312D27DEDEDDF2F2F2F2F2F2F2F2F2F2F2F275
736B8A865EFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC
FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACB2AE796B695FE7E7E7F2F2F2F2F2
F2B8B7B65A5743F0ECA3FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFE
F9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC84805A8F8E8C
F2F2F2F2F2F249463ECBC78AFEF9ACFEF9ACFEF9AC6E6A4B1714118A865EFEF9
ACFEF9ACFEF9ACFEF9ACFEF9ACA7A37217141144412FF0ECA3FEF9ACFEF9ACE5
E09B5C594BDEDEDDB8B7B6615E49FEF9ACFEF9ACFEF9ACC2BE84171411171411
171411FEF9ACFEF9ACFEF9ACFEF9ACFEF9AC514D38171411171411999966FEF9
ACFEF9ACFEF9AC84805AA2A1A07E7C78A29D6EFEF9ACFEF9ACFEF9ACF0ECA325
211A171411514D38FEF9ACFEF9ACFEF9ACFEF9ACFEF9AC7C795517141125211A
E1DC99FEF9ACFEF9ACFEF9ACC2BE845C59516B695FD0CB8DFEF9ACFEF9ACFEF9
ACFEF9ACF0ECA3C2BE84FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACD3
CF8FE1DC99FEF9ACFEF9ACFEF9ACFEF9ACF5F0A6312D27444238F0ECA3FEF9AC
FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9
ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC3C393225211AFE
F9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC
FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC4743
3A4B4942E5E09BFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFE
F9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC
FEF9AC312D27636159CBC78AFEF9ACFEF9ACFEF9AC25211ADCD896FEF9ACFEF9
ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC333024F0ECA3FE
F9ACFEF9ACE5E09B47433A888685949068FEF9ACFEF9ACFEF9ACBFBA815A5743
E5E09BFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFAF5AA706C4D8480
5AFEF9ACFEF9ACFEF9ACAFAB7775736BD7D6D63C3932FAF5AAFEF9ACFEF9ACFE
F9AC99996644412FE5E09BFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC949068
514D38FEF9ACFEF9ACFEF9ACFEF9AC54503EBBBAB9F2F2F2636159A29D6EFEF9
ACFEF9ACFEF9ACFEF9ACA7A3724C4935928E64DEDA97F0ECA3E8E39DBDB88069
6648706D4FE5E09BFEF9ACFEF9ACFEF9ACCBC78A3C3932F2F2F2F2F2F2DEDEDD
5A5743DEDA97FEF9ACFEF9ACFEF9ACFEF9ACE5E09B8E8A61615E4356523B5652
3B696648B7B37DFAF5AAFEF9ACFEF9ACFEF9ACEEE9A166644EB8B7B6F2F2F2F2
F2F2F2F2F2A6A5A454503EFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC
FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9AC747051817F79F2F2
F2F2F2F2F2F2F2F2F2F2F2F2F286858154503EDCD896FEF9ACFEF9ACFEF9ACFE
F9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACE8E39D706D4F807E76
F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2ABAAA9646253A29D6EF0EC
A3FEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACFEF9ACF5F0A6ACA87569655188
8685F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2CCCCCC
736B6B514D387A7656AFAB77D3CF8FE1DC99D3CF8FB7B37D837F59312D27615E
56CCCCCCF2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2
F2F2F2F2F2F2F2F2E7E7E7A2A1A06361594B4942403C334B4942636159999999
DEDEDDF2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2F2} #{
FFFFFFFFFFFFFFFFFFFF000000FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF0000
0000000000000000FFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000
00FFFFFFFFFFFFFF0000000000000000000000000000000000FFFFFFFFFF0000
0000000000000000000000000000000000FFFFFFFF0000000000000000000000
000000000000000000FFFF000000000000000000000000000000000000000000
FFFF000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000
00000000000000FF000000000000000000000000000000000000000000FFFF00
0000000000000000000000000000000000000000FFFFFF000000000000000000
00000000000000000000FFFFFFFFFF0000000000000000000000000000000000
FFFFFFFFFFFFFF000000000000000000000000000000FFFFFFFFFFFFFFFFFF00
000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF0000000000000000
00FFFFFFFFFFFFFF
}]

view [
	backdrop 102.204.255
	button 80x30 "Click Me" [probe "Hello Red"]
	base silver 300x200 draw [
		image smiley 10x30

		line-cap round
		pen red
		line 10x10 130x190 80x40 150x100
		
		pen blue
		line-width 4
		line-join round
		line 15x190 50x50 190x180
		
		pen green
		line-join miter
		box 10x120 70x160
		
		line-width 1
		pen maroon
		fill-pen orange
		box 150x80 180x120
		
		fill-pen off
		pen red
		triangle 170x10 170x50 195x50
		
		pen yellow fill-pen orange
		line-width 5
		line-join bevel
		polygon 120x130 120x190 180x130 180x190

		line-width 1
		pen purple
		fill-pen purple
		box 220x10 280x70 10
		pen gray
		fill-pen white
		ellipse 240x20 20x40
		
		fill-pen red
		circle 250x150 49.5
		pen gray
		fill-pen white
		circle 250x150 40
		fill-pen red
		circle 250x150 30
		fill-pen blue
		circle 250x150 20
		pen blue
		fill-pen white
		polygon 232x144 245x144 250x130 255x144 268x144
			257x153 260x166 250x158 239x166 243x153

		font font-A
		text 40x6 "Scroll Me with mouse wheel :-)"
		
		arc 100x25 80x80 0 90 closed
		pen red
		arc 100x25 50x80 30 90

		curve 20x150 60x250 200x50
		curve 224x14 220x40 280x40 276x66
	] on-over [probe event/offset]
]

probe "done"