Red/System []

node-handle!: alias integer!

identity: func [value [node-handle!] return: [integer!]][value]
main: func [return: [integer!]][identity 42]
