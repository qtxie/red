Red [
	Title:   "Red/System code emitter base object"
	Author:  "Nenad Rakocevic"
	File:    %target-class.red
	Tabs:    4
	Rights:  "Copyright (C) 2011-2018 Red Foundation. All rights reserved."
	License: "BSD-3 - https://github.com/red/red/blob/master/BSD-3-License.txt"
]

target-class: context [
	#do keep [
		target-body-file: join system/options/path %system/targets/target-class-body.red
		unless exists? target-body-file [
			target-body-file: join system/options/path %targets/target-class-body.red
		]
		target-body-source: either value? 'transcode [
			transcode read/binary target-body-file
		][
			load target-body-file
		]
		copy skip target-body-source 2
	]
]
