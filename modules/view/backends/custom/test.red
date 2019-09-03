Red [
	Needs: View
	Config: [GUI-engine: 'custom]
]

probe "abc"

win: make gob! [type: 'window size: 800x800 color: red]
?? win
probe length? win
loop 10000 [append win make gob! compose [size: (random 50x50) offset: (random 800x800) color: (random 255.255.255)]]

probe "fjdksafjldsjfklsdafj"
view win
probe "done"