Red [
	Title: "Generate hybrid compiler wire constants"
]

do %../../compiler/wire-schema-spec.red
do %../../compiler/wire-schema-generator.red

value: compiler-wire-schema-generator/write-generated
	compiler-wire-schema-spec
	%../../compiler/wire-schema.red
	%../../system/codegen/wire-schema.reds

print ["Generated compiler wire schema fingerprint:" value]
