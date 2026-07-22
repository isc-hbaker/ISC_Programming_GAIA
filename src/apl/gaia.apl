⎕IO←0
a←⎕CSV 1⊃⎕ARG
s←a[1↓⍳≢a;0]
b←a[1↓⍳≢a;3]
i←s∘.=∪s
x←⌈/¨b[⍸¨i]
y←⌊/¨b[⍸¨i]
p←100×(x-y)÷y
((p≥⍎4⊃⎕ARG)/∪s,x,y,p)⎕CSV 3⊃⎕ARG