Red/System [
	Title:	"Button widget"
	Author: "Xie Qingtian"
	File: 	%button.reds
	Tabs: 	4
	Rights: "Copyright (C) 2023 Xie Qingtian. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

init-button: func [
	widget		[widget!]
][
	WIDGET_SET_FLAG(widget WIDGET_FLAG_FOCUSABLE)
	widget/render: as render-func! :draw-button
	widget/on-event: as event-handler! :on-button-event
]

on-button-event: func [
	type		[event-type!]
	evt			[widget-event!]
	return:		[integer!]
	/local
		widget	[widget!]
		line	[red-string!]
		cp		[integer!]
][
	widget: evt/widget
	line: as red-string! (get-face-values widget) + FACE_OBJ_TEXT
	cp: 0
	if type = EVT_KEY [
		cp: evt/data
		if SPECIAL_KEY?(cp) [cp: cp and 7FFFFFFFh]
	]

	if zero? cp [return 0]
	screen/redraw
	0
]

draw-button: func [
	widget		[widget!]
	/local
		flags	[integer!]
][
	flags: 0
	if WIDGET_FOCUSED?(widget) [
		flags: flags or PIXEL_INVERTED
	]
	_widget/render-text widget flags
]