Red/System [
	Title:	"Windows classes handling"
	Author: "Qingtian Xie"
	File: 	%classes.reds
	Tabs: 	4
	Rights: "Copyright (C) 2016 Qingtian Xie. All rights reserved."
	License: {
		Distributed under the Boost Software License, Version 1.0.
		See https://github.com/red/red/blob/master/BSL-License.txt
	}
]

#include %delegates.reds

add-method!: alias function! [class [integer!]]

add-base-handler: func [class [integer!]][
	flipp-coord class
	class_addMethod class sel_getUid "drawRect:" as-integer :draw-rect "v@:{_NSRect=ffff}"
]

add-window-handler: func [class [integer!]][
	class_addMethod class sel_getUid "mouseDown:" as-integer :mouse-down "v@:@"
	class_addMethod class sel_getUid "mouseUp:" as-integer :mouse-up "v@:@"
	class_addMethod class sel_getUid "keyDown:" as-integer :on-key-down "v@:@"
	class_addMethod class sel_getUid "keyUp:" as-integer :on-key-up "v@:@"
	class_addMethod class sel_getUid "windowWillClose:" as-integer :win-will-close "v12@0:4@8"
]

add-button-handler: func [class [integer!]][
	class_addMethod class sel_getUid "button-click:" as-integer :button-click "v@:@"
]

add-slider-handler: func [class [integer!]][
	class_addMethod class sel_getUid "slider-change:" as-integer :slider-change "v@:@"
]

add-text-field-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :text-did-change "v@:@"
	class_addMethod class sel_getUid "textDidEndEditing:" as-integer :text-did-end-editing "v@:@"
	class_addMethod class sel_getUid "becomeFirstResponder" as-integer :get-focus "B@:"
]

add-area-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :area-text-change "v@:@"
]

add-combo-box-handler: func [class [integer!]][
	class_addMethod class sel_getUid "textDidChange:" as-integer :text-did-change "v@:@"
	class_addMethod class sel_getUid "comboBoxSelectionDidChange:" as-integer :selection-change "v@:@"
]

add-table-view-handler: func [class [integer!]][
	class_addMethod class sel_getUid "numberOfRowsInTableView:" as-integer :number-of-rows "l@:@"
	class_addMethod class sel_getUid "tableView:objectValueForTableColumn:row:" as-integer :object-for-table "@20@0:4@8@12l16"
]

add-camera-handler: func [class [integer!]][
	0
]

add-app-delegate: func [class [integer!]][
	class_addMethod class sel_getUid "applicationWillFinishLaunching:" as-integer :will-finish "v12@0:4@8"
	class_addMethod class sel_getUid "applicationShouldTerminateAfterLastWindowClosed:" as-integer :destroy-app "B12@0:4@8"
]

flipp-coord: func [class [integer!]][
	class_addMethod class sel_getUid "isFlipped" as-integer :is-flipped "B@:"
]

make-super-class: func [
	new		[c-string!]
	base	[c-string!]
	method	[integer!]				;-- override functions or add functions
	store?	[logic!]
	return:	[integer!]
	/local
		new-class	[integer!]
		add-method	[add-method!]
][
	new-class: objc_allocateClassPair objc_getClass base new 0
	if store? [						;-- add an instance value to store red-object!
		class_addIvar new-class IVAR_RED_FACE 16 2 "{red-face=iiii}"
	]
	unless zero? method [
		add-method: as add-method! method
		add-method new-class
	]
	objc_registerClassPair new-class
]

register-classes: does [
	make-super-class "RedAppDelegate"	"NSObject"				as-integer :add-app-delegate	no
	make-super-class "RedView"			"NSView"				as-integer :flipp-coord			no
	make-super-class "RedBase"			"NSView"				as-integer :add-base-handler	yes
	make-super-class "RedWindow"		"NSWindow"				as-integer :add-window-handler	yes
	make-super-class "RedButton"		"NSButton"				as-integer :add-button-handler	yes
	make-super-class "RedSlider"		"NSSlider"				as-integer :add-slider-handler	yes
	make-super-class "RedProgress"		"NSProgressIndicator"	0	yes
	make-super-class "RedTextField"		"NSTextField"			as-integer :add-text-field-handler yes
	make-super-class "RedTextView"		"NSTextView"			as-integer :add-area-handler yes
	make-super-class "RedComboBox"		"NSComboBox"			as-integer :add-combo-box-handler yes
	make-super-class "RedTableView"		"NSTableView"			as-integer :add-table-view-handler yes
	make-super-class "RedCamera"		"NSView"				as-integer :add-camera-handler yes
	make-super-class "RedScrollView"	"NSScrollView"			0	yes
	make-super-class "RedBox"			"NSBox"					0	yes
]
