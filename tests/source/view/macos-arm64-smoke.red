Red [
	Title: "macOS ARM64 native View smoke test"
	Needs: View
]

output-dir: get-env "RED_VIEW_TEST_OUTPUT_DIR"
marker: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.ok"]
][%macos-arm64-view-smoke.ok]
error-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.error"]
][%macos-arm64-view-smoke.error]
if exists? marker [delete marker]
if exists? error-file [delete error-file]
stage-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.stages"]
][%macos-arm64-view-smoke.stages]
if exists? stage-file [delete stage-file]

;-- A GUI bundle has no readable stdout, so these files are the whole report:
;-- the error file says what a check measured, the journal says how far the run
;-- got, which is the only evidence left when the process dies before any check
;-- can speak. Both are written through, so a crash still leaves them behind.
mark: func [name [string!]][write/append stage-file rejoin [name newline]]

fail: func [message [string!]][
	print rejoin ["MACOS-ARM64-VIEW-ERROR: " message]
	write error-file message
	unview/all
	quit/return 1
]

mark "screens"
unless system/platform = 'macOS [fail "wrong platform"]
unless all [block? system/view/screens not empty? system/view/screens][
	fail "no screens discovered"
]

screen-face: first system/view/screens
unless all [
	pair? screen-face/size
	screen-face/size/x > 0
	screen-face/size/y > 0
	block? screen-face/state
	handle? screen-face/state/1
][fail "invalid screen face"]

click-count: 0
create-count: 0
time-count: 0
timer-face: none
clicker: none
field-face: none
empty-field-face: none
area-face: none
unicode-face: none
check-face: none
slider-face: none
progress-face: none
drop-face: none
list-face: none
tabs-face: none
left-align-face: none
center-align-face: none
right-align-face: none
plain-styled-face: none
styled-face: none
top-align-face: none
middle-align-face: none
bottom-align-face: none
single-line-base-face: none
multiline-align-face: none
button-align-panel: none
scroll-face: none
calendar-face: none
canvas: none
base-text-face: none
image-text-face: none
radio-on: none
radio-off: none
radio-result: none
rich-box: none
console-font: none
console-metrics-box: none
console-metrics: none
window: none
result: none
secondary: none
snapshot-file: either string? output-dir [
	to file! rejoin [output-dir "/macos-arm64-view-smoke.png"]
][%macos-arm64-view-smoke.png]
unicode-text: rejoin ["View " to char! 937 " " to char! 19990 to char! 30028]
image-background: make image! [160x44 230.235.240]
rich-box: make face! [
	type: 'rich-text
	text: unicode-text
	size: 160x40
	data: make block! 4
]
console-font: make font! [
	name: system/view/fonts/fixed
	size: 11
]
console-metrics-box: make face! [
	type: 'rich-text
	tabs: none
	line-spacing: none
	handles: none
]
console-metrics-box/font: console-font
console-metrics-box/text: "XXXXXXXXXX"

result: try/all [
	window: view/no-wait/options [
		title "Red Apple Silicon View smoke"
		on-created [create-count: create-count + 1]
		below
		timer-face: text "Native controls" font-size 16 rate 20
		on-time [time-count: time-count + 1 face/rate: none]
		across
		clicker: button "Dispatch" 100x28 [click-count: click-count + 1]
		field-face: field "initial" 150x28
		empty-field-face: field 150x28
		check-face: check "Enabled" tri-state
		return
		slider-face: slider 35% 150x24
		progress-face: progress 45% 150x18
		drop-face: drop-list 130x26 data ["One" "Two" "Three"] select 1
		return
		list-face: text-list 170x90 data ["Alpha" "Beta" "Gamma"] select 1
		tabs-face: tab-panel 240x90 [
			"First" [text "First tab"]
			"Second" [base 80x30 230.240.250]
		]
		return
		canvas: base 180x120 white cursor hand draw [
			pen red
			line 5x5 175x115
			fill-pen blue
			box 30x20 150x100 6
			fill-pen yellow
			circle 90x60 22
		]
		unicode-face: text "" 260x24
		area-face: area "" 260x60
		return
		left-align-face: text "ARM64" 120x24 white left font-color black
		center-align-face: text "ARM64" 120x24 white center font-color black
		right-align-face: text "ARM64" 120x24 white right font-color black
		plain-styled-face: text "Styled" 120x24 white font-color black
		styled-face: text "Styled" 120x24 white underline strike font-color black
		return
		top-align-face: text "Vertical" 100x64 white left top font-color black
		middle-align-face: text "Vertical" 100x64 white left middle font-color black
		bottom-align-face: text "Vertical" 100x64 white left bottom font-color black
		single-line-base-face: base "Vertical" 100x64 white left top font-color black
		multiline-align-face: base "Vertical^/Vertical" 100x64 white left top font-color black
		return
		button-align-panel: panel 340x90 [
			across
			button "X" 100x70 left top
			button "X" 100x70 center middle
			button "X" 100x70 right bottom
		]
		return
		base-text-face: base "Base text" 160x44 white font-color black
		image-text-face: image image-background "Image text" 160x44 font-color black
		return
		radio-on: radio "on" [radio-result/text: "on"]
		radio-off: radio "off" [radio-result/text: "off"]
		radio-result: field 170 "????"
		return
		scroll-face: base 140x60 white scrollable draw [
			pen blue
			line 4x4 136x56
		]
		calendar-face: calendar 160x80
	][
		menu: [
			"File" [
				"Smoke item" smoke-item
				"Untagged item"
			]
		]
	]
]
if error? result [fail mold result]
mark "window built"

repeat count 20 [
	do-events/no-wait
	wait 0.01
]

unless create-count = 1 [fail "on-created actor was not dispatched"]
unless time-count = 1 [fail "native time actor was not dispatched"]
;-- What an empty field's text is -- an empty string or none -- belongs to the
;-- backend: measured, Windows native View leaves it none! where the terminal
;-- engine initializes it to "". The field that does carry text is checked after
;-- the facet updates below. All this row owns is that creating the control did
;-- not write a value-shaped thing (a handle, a number) into a text facet.
unless any [string? empty-field-face/text none? empty-field-face/text][
	fail rejoin ["empty field text is not a text value: " mold empty-field-face/text]
]
do-actor clicker none 'click
unless click-count = 1 [fail "click actor was not dispatched"]

radio-on/data: on
show radio-on
do-actor radio-on none 'change
unless all [radio-on/data radio-result/text = "on"][
	fail "radio selection did not dispatch its change actor"
]

mark "facet updates"
field-face/text: "updated"
unicode-face/text: unicode-text
area-face/text: unicode-text
check-face/data: true
slider-face/data: 70%
progress-face/data: 80%
list-face/selected: 2
drop-face/selected: 2
tabs-face/selected: 2
show [
	field-face unicode-face area-face check-face slider-face progress-face
	list-face drop-face tabs-face
]

repeat count 20 [
	do-events/no-wait
	wait 0.01
]

unless all [
	field-face/text = "updated"
	unicode-face/text = unicode-text
	area-face/text = unicode-text
	check-face/data = true
	list-face/selected = 2
	drop-face/selected = 2
	tabs-face/selected = 2
][fail "native facet update failed"]

unless all [block? window/menu not empty? window/menu][fail "native menu was not created"]

mark "rich text caret and metrics"
append canvas/draw reduce ['pen black 'text 4x4 rich-box]
show canvas
repeat count 10 [do-events/no-wait wait 0.01]

caret-before-end: caret-to-offset rich-box (length? rich-box/text)
caret-at-end: caret-to-offset rich-box (1 + (length? rich-box/text))
unless all [
	point2D? caret-before-end
	point2D? caret-at-end
	caret-before-end/x < caret-at-end/x
	caret-before-end/y = caret-at-end/y
][fail "caret moved to a different line before end of text"]

console-metrics: size-text console-metrics-box
unless all [
	point2D? console-metrics
	console-metrics/x > 40.0
	console-metrics/y > 0.0
	console-metrics/x > (console-metrics/y * 3.0)
][fail rejoin ["unconstrained rich-text measurement wrapped: " mold console-metrics]]

measured: size-text/with unicode-face unicode-text
unless all [point2D? measured measured/x > 0.0 measured/y > 0.0][
	fail "Unicode text measurement failed"
]

mark "window resize"
target-size: window/size + 20x20
window/size: target-size
show window
repeat count 20 [do-events/no-wait wait 0.01]
unless window/size = target-size [
	fail rejoin [
		"native window resize failed: target=" mold target-size
		" actual=" mold window/size
	]
]

backing-scale: func [
	{Retina factor a face capture is reported at, from its pixel height.}
	image	[image!]
	face	[object!]
	return:	[integer!]
][
	either zero? face/size/y [0][to integer! (image/size/y / face/size/y)]
]

capture: func [
	{A face capture that reports its own failure: a bad to-image must not crash.}
	face	[object!]
	return:	[image!]
	/local image pixel
][
	image: try [to-image face]
	if any [
		not image? image
		not pair? image/size
		image/size/x <= 0
		image/size/y <= 0
	][
		fail rejoin [
			"to-image on a " mold face/type " face produced "
			either image? image [rejoin ["size " mold image/size]][mold image]
		]
	]
	;-- Read one pixel before any scan: a Darwin capture is built from a CGImage by
	;-- OS-to-image, which can hand back none! for a face without a native view, so
	;-- a capture that answers no pixels is named here rather than ten thousand
	;-- accessor faults later -- and a script error in a GUI bundle exits 254
	;-- without ever reaching the report files.
	pixel: try [image/(1x1)]
	unless tuple? pixel [
		fail rejoin [
			"to-image on a " mold face/type " face answers no pixels: " mold pixel
		]
	]
	image
]

ink-count: func [
	{How many pixels of an image differ from its top-left one.}
	image	[image!]
	return:	[integer!]
	/local x y base pixel xy changed
][
	base: image/(1x1)
	changed: 0
	repeat y image/size/y [
		repeat x image/size/x [
			xy: as-pair x y
			pixel: image/:xy
			unless all [pixel/1 = base/1 pixel/2 = base/2 pixel/3 = base/3][
				changed: changed + 1
			]
		]
	]
	changed
]

check-control: func [
	{A native control must be laid out where VID put it, and must paint.}
	face	[object!]
	label	[string!]
	/local image scale ink
][
	image: capture face
	scale: backing-scale image face
	ink: ink-count image
	;-- The capture's own size is deliberately not asserted: a native control's
	;-- to-image is not its face's rectangle on every backend -- measured on
	;-- Windows, the three 102x72 buttons of a panel all captured the same 128x90
	;-- image, ink included -- so claiming the geometry here would test the
	;-- capture path, not the control. That it renders is the claim that holds.
	unless all [
		scale >= 1
		ink > (20 * scale * scale)					;-- a bezel paints rows, not a stray pixel
	][
		fail rejoin [
			label " control capture is invalid: image=" mold image/size
			" face=" mold face/size " scale=" scale " ink=" ink
		]
	]
]

;-- AppKit composites a native control in its own layer, not in the face's view,
;-- so to-image on macOS has two measured limits: a container capture carries only
;-- the container's own drawing (a white panel holding three dark-bezel buttons
;-- captures not one pixel that differs from white), and a control's own capture is
;-- its bezel, whose colours track the user's appearance setting. No appearance-
;-- independent pixel of a button title reaches Red here, and para.reds records the
;-- backend's other half: NSButtonCell centers its title vertically whatever Red
;-- asks, and a rounded bezel ignores the cell's alignment. Title placement is
;-- therefore tested where Red draws the glyphs itself, in the text-band groups
;-- below. A native control answers for the layout VID gave it, and for a capture
;-- proving it was created, told how to align -- change-para's button arm runs at
;-- make-view for all three of left, center and right -- and paints.
mark "control layout"
show button-align-panel
repeat count 5 [do-events/no-wait wait 0.01]
pane: button-align-panel/pane
unless all [block? pane 3 = length? pane][
	fail either block? pane [
		rejoin ["button panel pane holds " length? pane " faces, not three"]
	]["button panel has no pane block"]
]
walk: next pane
while [not tail? walk][
	previous: walk/-1
	item: walk/1
	unless all [
		item/offset/y = previous/offset/y					;-- one across row, on one line
		item/offset/x >= (previous/offset/x + previous/size/x)	;-- ordered, not overlapping
	][
		fail rejoin [
			"pane faces are not an across row: "
			mold reduce [previous/offset previous/size item/offset item/size]
		]
	]
	walk: next walk
]
mark "per-control captures"
repeat i 3 [check-control pane/:i rejoin ["pane face " i]]

snapshot: capture canvas

corner: snapshot/(1x1)
center: snapshot/(as-pair (snapshot/size/x / 2) (snapshot/size/y / 2))
if corner = center [fail "Draw capture appears blank"]

text-visible?: func [
	face	[object!]
	return:	[logic!]
	/local image
][
	image: capture face
	(ink-count image) > 10
]
unless text-visible? base-text-face [fail "base face text was not rendered"]
unless text-visible? image-text-face [fail "image face text was not rendered"]

ink-band: function [
	{Extents of the glyph ink in a face capture, in the face's own coordinates.}
	image	[image!]
	scale	[integer!]	"Retina factor the capture is reported at"
	return: [block!] "top bottom left right, ink, then the dark rows that explain neither and the capture size"
	/local min-width top bottom left right ink unexplained xy row-left row-right count x y pixel
][
	min-width: to integer! (3 * scale)
	;-- AppKit leaves one- and two-pixel dark corners at the edge of the drawn
	;-- rectangle; a glyph row is wider than that by a margin.
	top: 0
	bottom: 0
	left: image/size/x
	right: 0
	ink: 0
	unexplained: copy []
	repeat y image/size/y [
		count: 0
		row-left: 0
		row-right: 0
		repeat x image/size/x [
			xy: as-pair x y
			pixel: image/:xy
			if all [pixel/1 < 128 pixel/2 < 128 pixel/3 < 128][
				count: count + 1
				if zero? row-left [row-left: x]
				row-right: x
			]
		]
		either all [count >= min-width count < image/size/x][
			if zero? top [top: y]
			bottom: y
			left: min left row-left
			right: max right row-right
			ink: ink + count
		][
			;-- a row carrying dark pixels that no glyph explains is either a
			;-- speck at the edge of the rectangle (count below `min-width`) or a
			;-- band the capture never painted (count = the whole width, which
			;-- flattens to black). Either way it is kept out of the band and
			;-- reported with it, so a red run says what the ink looked like.
			if all [count > 0 (length? unexplained) < 24][
				append unexplained reduce [y count]
			]
		]
	]
	if zero? bottom [return reduce [0 0 0 0 0 unexplained image/size]]
	reduce [
		to integer! ((top - 1) / scale)
		to integer! (bottom / scale)
		to integer! ((left - 1) / scale)
		to integer! (right / scale)
		ink
		unexplained
		image/size
	]
]

text-band: function [
	{Extents of the glyphs a face draws, in that face's own coordinates.}
	face [object!]
	return: [block!]
	/local image scale
][
	image: capture face
	scale: backing-scale image face
	ink-band image either zero? scale [1][scale]
]

report-bands: func [
	{The bands that were measured, and whatever dark rows they did not explain.}
	bands [block!]
	return: [string!]
	/local out walk band
][
	out: copy ""
	walk: bands
	while [not tail? walk][
		band: walk/1
		append out rejoin [newline "  " mold copy/part band 5]
		if not empty? band/6 [
			append out rejoin [" -- unexplained dark rows [y count] " mold band/6
				" of a " mold band/7 " capture"]
		]
		walk: next walk
	]
	out
]

band-height: func [band [block!] return: [integer!]][band/2 - band/1]
band-width: func [band [block!] return: [integer!]][band/4 - band/3]
within?: func [
	"Whether two measurements agree to within a number of rows or columns."
	a [integer!]
	b [integer!]
	tolerance [integer!]
	return: [logic!]
	/local delta
][
	delta: a - b
	if delta < 0 [delta: negate delta]
	delta <= tolerance
]

mark "text bands shown"
show [
	left-align-face center-align-face right-align-face
	plain-styled-face styled-face
	top-align-face middle-align-face bottom-align-face
	single-line-base-face multiline-align-face
]
repeat count 5 [do-events/no-wait wait 0.01]

mark "v-align bands"
face-height: top-align-face/size/y
centre: face-height / 2
quarter: face-height / 4
top-band: text-band top-align-face
middle-band: text-band middle-align-face
bottom-band: text-band bottom-align-face
top-height: band-height top-band
middle-height: band-height middle-band
bottom-height: band-height bottom-band
unless all [
	top-height > 0
	middle-height > 0
	bottom-height > 0							;-- an unmeasured face is an unrendered one
	top-band/1 < quarter							;-- `top` holds the band against the upper edge
	middle-band/1 < centre
	middle-band/2 > centre						;-- `middle` straddles the vertical centre
	(face-height - bottom-band/2) < quarter		;-- `bottom` holds it against the lower edge
	within? top-height middle-height 1
	within? middle-height bottom-height 1		;-- same glyphs: shifted, not stretched
	within? top-band/3 middle-band/3 1
	within? middle-band/3 bottom-band/3 1		;-- `left` puts all three at one column
][
	fail rejoin [
		"vertical text alignment is invalid in a " mold face-height " face: "
		report-bands reduce [top-band middle-band bottom-band]
	]
]

mark "h-align bands"
face-width: left-align-face/size/x
edge: face-width / 4
left-band: text-band left-align-face
center-band: text-band center-align-face
right-band: text-band right-align-face
left-span: band-width left-band
center-span: band-width center-band
right-span: band-width right-band
unless all [
	left-span > 0
	center-span > 0
	right-span > 0
	left-band/3 < center-band/3
	center-band/3 < right-band/3
	within? left-span center-span 2				;-- same glyphs: shifted, not stretched
	within? center-span right-span 2
	left-band/3 < edge							;-- `left` starts at the left edge
	(face-width - right-band/4) < edge			;-- `right` ends at the right edge
][
	fail rejoin [
		"horizontal text alignment is invalid in a " mold face-width " wide face: "
		report-bands reduce [left-band center-band right-band]
	]
]

mark "styled bands"
plain-band: text-band plain-styled-face
styled-band: text-band styled-face
unless all [
	(band-height plain-band) > 0
	;-- an underline and a strike add ink around the same glyphs, they never
	;-- take any away, so a face that ignores both measures exactly its plain twin
	styled-band/5 > plain-band/5
	styled-band/3 <= plain-band/3
	styled-band/4 >= plain-band/4
][
	fail rejoin [
		"underline and strike were not rendered: "
		report-bands reduce [plain-band styled-band]
	]
]

mark "multiline bands"
single-band: text-band single-line-base-face
multi-band: text-band multiline-align-face
single-height: band-height single-band
multi-height: band-height multi-band
unless all [
	single-height > 0
	multi-height > single-height					;-- two lines are taller than one
	within? multi-band/1 single-band/1 1			;-- their first lines share the `top` anchor
	multi-band/2 > single-band/2					;-- and the second line falls below the first
	within? multi-band/3 single-band/3 1
][
	fail rejoin [
		"multiline text layout is invalid: "
		report-bands reduce [single-band multi-band]
	]
]

mark "png encoding"
if system/build/date/year = 1970 [fail "compiler build date is still the Unix epoch"]

if exists? snapshot-file [delete snapshot-file]
;-- A codec that raises here would leave nothing but an exit code, so let it speak.
;-- The trailing logic! is not decoration: `save/as` produces no value, and
;-- assigning an unset! to a word leaves that word unset, so reading it right back
;-- would raise `result needs a value` -- the guard would be the new failure.
result: try [save/as snapshot-file snapshot 'png true]
if error? result [fail rejoin ["PNG encoding failed: " mold result]]
unless all [exists? snapshot-file not empty? read/binary snapshot-file][
	fail "PNG encoding produced no data"
]
delete snapshot-file

mark "window stress"
repeat count 5 [
	secondary: view/no-wait [
		title "Red Apple Silicon window stress"
		base 48x32 20.80.140
	]
	repeat event-count 5 [do-events/no-wait wait 0.01]
	unless all [block? secondary/state handle? secondary/state/1][
		fail "secondary window has no native handle"
	]
	unview/only secondary
	repeat event-count 5 [do-events/no-wait wait 0.01]
	secondary: none
	recycle
]

mark "teardown"
unview/all
repeat count 20 [do-events/no-wait]

write marker "MACOS-ARM64-VIEW-OK"
print "MACOS-ARM64-VIEW-OK"
