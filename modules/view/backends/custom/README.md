## Example of GOB-based widget
![gob2020-3-302](https://user-images.githubusercontent.com/1673525/77898390-a4527f00-72ad-11ea-92e8-009efd754630.gif)
```
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

btn-normal: make gob-style! [
    background: 255.255.255
    border-radius: btn-radius
    shadow: btn-shadow-normal
]

btn-hover: make gob-style! [
    background: 240.240.240
    border-radius: btn-radius
    shadow: btn-shadow-normal
]

btn-down: make gob-style! [
    background: 210.210.210
    border-radius: btn-radius
    shadow: btn-shadow-down
]

;; widgets

register-widget 'button make gob! [
    actors: reduce [
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

register-widget 'base make gob! []

view [
    backdrop 102.204.255
    button 80x30 "Click Me" [probe "Hello Red"]
    base 100x100 all-over on-over [probe event/offset]
]
```

## Extend Face! Object
The face! object is extended to have a `gob` facet, which does the actual job.
```
face!: object [
	type:		'face
	offset:		none
	size:		none
	text:		none
	image:		none
	color:		none
	menu:		none
	data:		none
	enabled?:	yes
	visible?:	yes
	selected:	none
	flags:		none
	options:	none
	parent:		none
	pane:		none
	state:		none
	rate:		none
	edge:		none
	para:		none
	font:		none
	actors:		none
	extra:		none
	draw:		none
	gob:		none     ;@@
]
```
## Event flow
All the events (mouse events, keyboard events, etc.) are passed to the face first, then to the gob. The face event handler could return `stop` to prevent the event from passing to the gob.

## Graphic Object (GOB)
A GOB is very lightweight (96 bytes now) compare to face. Complex UI components can be built by composing many gobs.

List of available fields of gob:
| Field | Datatype | Description | Available |
|:-:|:-:|:-:|:-:|
| offset  | pair!  | the x-y coordinate relative to parent  | √ |
| size  | pair  | width and height of gob (note below)  | √ |
| pane  | block!  | a block of child gobs  | √ |
| parent  | gob!  | the parent gob  | √ |
| data  | any-type!  | normally used to reference data related to the gob  | √ |
| face  | face!  | the face object the gob linked with  | √ |
| draw  | block!  | a block of draw commands  | √ |
| color  | tuple!  | background color of the gob in R.G.B or R.G.B.A format  | √ |
| text  | string!  | text displayed in the gob  | √ |
| image  | image!  | image displayed in the face background | √ |
| enabled? | logic!  | enable or disable events on the gob  | |
| visible?  | logic!  | display or hide the gob  | |
| flags  | block!  | ?? Do we need it?  | |
| actors  | block!  | User-provided events handlers  | √ |
| styles  | object!  | gob-style! object, styling the gob  | √ |
| ...  | ...  | ...  | ... |

**_Note:_**  The gob uses a box model. Every box is composed of three parts (or areas), defined by their respective edges: the content edge, padding edge and border edge.

![image](https://user-images.githubusercontent.com/1673525/77910740-395f7300-72c2-11ea-85e1-9464a61794da.png)

If you set an gob's width to 100 pixels, that 100 pixels will include any border or padding you added, and the content box will shrink to absorb that extra width. 
The draw commands in `gob/draw` will be draw in the content box.

## Gob style
Gob-style objects are clones of gob-style! template object.
```
gob-style!: object [
    state: none     ;-- Internal state info
    on-change*: function [word old new][
        ;-- update field
    ]
    on-deep-change*: function [owner word target action new index part][
        ;-- update field
    ]
]
```
When link a gob-style! object to a gob, the following fields will be processed by the gob. Other fields will be ignored.

√ Implemented

TBD
```
√ background:
background-clip:		
background-size:		
background-color:		
background-image:		
background-repeat:		
background-origin:		
background-position:	
background-attachment:	
background-blend-mode:	

√ border:					
border-style:			
√ border-width:			
√ border-color:			
border-image:			
√ border-radius:			
border-bottom:			
border-bottom-color:	
border-bottom-style:	
border-bottom-width:	
border-bottom-radius:	
border-top:				
border-top-color:		
border-top-style:		
border-top-width:		
border-top-radius:		
border-left:			
border-left-color:		
border-left-style:		
border-left-width:		
border-right:			
border-right-color:		
border-right-style:		
border-right-width:		

padding:				
padding-left:			
padding-top:			
padding-right:			
padding-bottom:			

font: 					
√ font-family:			
√ font-size:				
√ font-style:				
font-weight:			

tab-size:				
√ text-align:				
text-indent:			
text-overflow:			
text-shadow:			
text-transform:			
text-decoration:		
text-decoration-color:	
text-decoration-line:	
text-decoration-style:	
letter-spacing:			
line-height:			

transform:				
transform-origin:		
transform-style:		

√ transition:				
transition-delay:		
transition-duration:	
transition-property:	
transition-timing-function:

opacity:				
√ shadow:					
caret-color:			
√ text-color:				
cursor:					
direction:				
white-space:			
word-break:				
word-spacing:			
word-wrap:				
writing-mode:			

blend-mode:				
outline:				

;-- filter
drop-shadow:			
blur:					
grayscale:				
hue-rotate:				
brightness:				
contrast:				
saturate:				
sepia:					

solid:					
```

## Development Notes
All the source codes are in `red-repo\modules\view\backends\custom`.
```
|;-- platform independent code
│  animation.reds
│  definitions.reds
│  events.reds
│  gob.reds			;-- red-gob!
│  gui.reds
│  matrix2d.reds
│  para.reds
│  README.md
│  rs-gob.reds		;-- low-level gob!
│  styles.reds
│  ui-manager.reds	;-- manage all the windows
│  utils.reds
│  widgets.red		;-- high-level widgets
│  widgets.reds		;-- native gob widgets
│
|;-- platform specific code
├─host-win
│      definitions.reds
│      direct2d.reds
│      draw.reds
│      events.reds
│      font.reds
│      gfx.reds
│      host.reds
│      text-box.reds
|─host-mac
|─host-gdk
│
│;-- unit tests
├─tests
│      custom-view.red
│      gob-vid.red
│
│;-- native gob widgets, those are a few very basic widgets hard to implemented in high level
└─widgets
        base.reds
        field.reds
```
Compiles the CLI console and run the `custom-view.red` and `gob-vid.red` to have a taste.
[Ballots Demo](https://github.com/red/code/tree/master/Showcase/ballots) also works.