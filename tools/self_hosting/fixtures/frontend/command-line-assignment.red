Red [Title: "Compiled command-line assignment fixture"]

args: system/options/args
print ["assigned type:" type? :args]
probe args
print ["first:" mold pick args 1]
