⎕IO←0
a←⎕CSV 1⊃⎕ARG
P←{t←(';'≠s)⊆s←⍵~'[] "' ⋄ v←⍎¨t/⍨'NaN'≢¨t ⋄ 0=⍴v:0 0⋄(⌊/v)(⌈/v)}
C←{m←⊃⍵⋄(m>0)×100×((1⊃⍵)-m)÷m+m=0}
n←1↓⍳≢a⋄B←P¨a[n;3]⋄G←P¨a[n;4]⋄p←(C¨B)⌈C¨G
k←p≥⍎3⊃⎕ARG⋄r←k/n⋄b←k/B⋄g←k/G⋄pf←k/p
(2⊃⎕ARG)⎕CSV⍉↑(a[r;0])(a[r;1])(a[r;2])(⍕¨⊃¨b)(⍕¨1⊃¨b)(⍕¨⊃¨g)(⍕¨1⊃¨g)(⍕¨pf)
