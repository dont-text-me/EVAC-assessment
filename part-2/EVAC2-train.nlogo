extensions [rnd]
breed [sheep a-sheep]
breed [dogs dog]

sheep-own [
  last-x
  last-y
  last-move ;; [0-4], 0, 1, 2, 3, 4 is staying put, north, east, south and west respectively
  move-made-in-this-tick
]

to setup
  clear-all

  ; setup the grass
  ask patches [
    set pcolor green
  ]

  set-default-shape sheep "sheep"
  create-sheep n-sheep [ ; create the sheep, then initialize their variables
    set color white
    setxy random-xcor random-ycor
    set last-move 0 ;; from the assessment brief, when initialised, the last move is to stay put
  ]

  set-default-shape dogs "wolf 2"
  create-dogs n-dogs [  ; create the wolves, then initialize their variables
    set color black
    setxy random-xcor random-ycor
  ]
  reset-ticks
end

to-report herd-score
  let avg-sheep-x mean [xcor] of sheep
  let avg-sheep-y mean [ycor] of sheep

  let sigma-x sum [(xcor - avg-sheep-x) ^ 2] of sheep
  let sigma-y sum [(ycor - avg-sheep-y) ^ 2] of sheep

  report (sigma-x + sigma-y) / n-sheep
end

to go
  ask sheep [tick-sheep]
  ask dogs [tick-dogs]
  tick
end

to tick-dogs
  set heading one-of [0 90 180 270]
  fd 1
  set heading 0
end


to tick-sheep
  set move-made-in-this-tick false
  ;; Action 1
  sheep-action-1
  ;; Action 2
  if not move-made-in-this-tick [
    sheep-action-2
  ]
  if not move-made-in-this-tick [
    sheep-action-3
  ]
  if not move-made-in-this-tick [
    sheep-action-4
  ]
  if not move-made-in-this-tick [
    sheep-action-5
  ]
end

to sheep-action-1
  ifelse count dogs-here = 1 [
    let acceptable-patches neighbors4 with [count dogs-here = 0]
    ifelse count acceptable-patches = 0 [
      set move-made-in-this-tick false ;; no neighboring patches without a dog found
    ]
    [
    ;; about to move: record the current position if action 5 is chosen on the next tick
    set last-x xcor
    set last-y ycor
    move-to one-of acceptable-patches ;; move to a neighboring patch without a dog
    set move-made-in-this-tick true
      if last-x = xcor and last-y > ycor [ ;; moved north
        set last-move 1
      ]
      if last-x > xcor and last-y = ycor [ ;; moved east
        set last-move 2
      ]
      if last-x = xcor and last-y < ycor [ ;; moved south
        set last-move 3
      ]
      if last-x = xcor and last-y < ycor [ ;; moved west
        set last-move 4
      ]
    ]
  ]
  [
    set move-made-in-this-tick false
  ]
end

to sheep-action-2
  ifelse count neighbors4 with [count dogs-here >= 1] >= 1[
  let acceptable-patches neighbors4 with [count dogs-here = 0]
  ifelse count acceptable-patches = 0[
    set move-made-in-this-tick false ;; no neighboring patches without a dog found
  ]
  [
    ;; about to move: record the current position if action 5 is chosen on the next tick
    set last-x xcor
    set last-y ycor
    move-to one-of acceptable-patches ;; move to a neighboring patch without a dog
    set move-made-in-this-tick true
      if last-x = xcor and last-y > ycor [ ;; moved north
        set last-move 1
      ]
      if last-x > xcor and last-y = ycor [ ;; moved east
        set last-move 2
      ]
      if last-x = xcor and last-y < ycor [ ;; moved south
        set last-move 3
      ]
      if last-x = xcor and last-y < ycor [ ;; moved west
        set last-move 4
      ]
  ]
  ]
  [
    set move-made-in-this-tick false
  ]
end

to sheep-action-3
  let acceptable-patches neighbors4 with [count neighbors4 with [count sheep-here >= 1] >= 1]
  ifelse count acceptable-patches = 0 [
    set move-made-in-this-tick false ;; no neighboring patches who themselves neighbor a patch with sheep found
  ]
  [
    ;; about to move: record the current position if action 5 is chosen on the next tick
    set last-x xcor
    set last-y ycor
    move-to one-of acceptable-patches ;; move to a neighboring patch without a dog
    set move-made-in-this-tick true
      if last-x = xcor and last-y > ycor [ ;; moved north
        set last-move 1
      ]
      if last-x > xcor and last-y = ycor [ ;; moved east
        set last-move 2
      ]
      if last-x = xcor and last-y < ycor [ ;; moved south
        set last-move 3
      ]
      if last-x = xcor and last-y < ycor [ ;; moved west
        set last-move 4
      ]
  ]
end

to sheep-action-4
  let acceptable-patches neighbors4 with [count sheep-here < count [sheep-here] of myself]
  ifelse count acceptable-patches = 0 [
    set move-made-in-this-tick false ;; no neighboring patches with less sheep than here found
  ]
  [
    ;; about to move: record the current position if action 5 is chosen on the next tick
    set last-x xcor
    set last-y ycor
    move-to one-of acceptable-patches ;; move to a neighboring patch without a dog
    set move-made-in-this-tick true
      if last-x = xcor and last-y > ycor [ ;; moved north
        set last-move 1
      ]
      if last-x > xcor and last-y = ycor [ ;; moved east
        set last-move 2
      ]
      if last-x = xcor and last-y < ycor [ ;; moved south
        set last-move 3
      ]
      if last-x = xcor and last-y < ycor [ ;; moved west
        set last-move 4
      ]
  ]
end

to sheep-action-5
  ;; choose the next action - same as last one with a chance of 0.5 and a different one with a chance of 0.125
  let next-move rnd:weighted-one-of-list [0 1 2 3 4 5] [it -> ifelse-value it = last-move [0.5] [0.125]]
  if next-move != 0 [
  set heading item (next-move - 1) [0 90 180 270] ;; if next-move is 1, go north etc.
  fd 1
  set heading 0 ;; face north again for the next time this action happens
  ]
  set last-move next-move ;; update last move even if this action didnt lead to a change of position
end
@#$#@#$#@
GRAPHICS-WINDOW
235
10
778
554
-1
-1
10.92
1
13
1
1
1
0
0
0
1
-24
24
-24
24
1
1
1
ticks
30.0

BUTTON
60
40
115
73
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
131
40
186
73
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
131
40
186
73
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

SLIDER
20
115
192
148
n-dogs
n-dogs
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
20
165
192
198
n-sheep
n-sheep
0
50
50.0
1
1
NIL
HORIZONTAL

MONITOR
25
225
142
270
Sheep herd score
herd-score
3
1
11

PLOT
10
290
210
440
Herd score
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot herd-score"

@#$#@#$#@
## WHAT IS IT?

This code example is a simple demo of a NetLogo simulation with patches containing food and turtles that move, eat, spend energy, reproduce (asexually) and can share food/energy with the nearest other turtle. 

A monitor keeps track of how many turtles have the message by reporting:

    count turtles 

The plot helps you visualize the overall energy of the whole population of turtles at any one time. Another plot shows how much food there is in the environment (patches).

Note that if you call a procedure inside:

    ask turtles [ ... ]

then everything in that procedure will be executed by all of the turtles.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dog
false
0
Polygon -7500403 true true 300 165 300 195 270 210 183 204 180 240 165 270 165 300 120 300 0 240 45 165 75 90 75 45 105 15 135 45 165 45 180 15 225 15 255 30 225 30 210 60 225 90 225 105
Polygon -16777216 true false 0 240 120 300 165 300 165 285 120 285 10 221
Line -16777216 false 210 60 180 45
Line -16777216 false 90 45 90 90
Line -16777216 false 90 90 105 105
Line -16777216 false 105 105 135 60
Line -16777216 false 90 45 135 60
Line -16777216 false 135 60 135 45
Line -16777216 false 181 203 151 203
Line -16777216 false 150 201 105 171
Circle -16777216 true false 171 88 34
Circle -16777216 false false 261 162 30

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf 2
false
0
Rectangle -7500403 true true 195 106 285 150
Rectangle -7500403 true true 195 90 255 105
Polygon -7500403 true true 240 90 217 44 196 90
Polygon -16777216 true false 234 89 218 59 203 89
Rectangle -1 true false 240 93 252 105
Rectangle -16777216 true false 242 96 249 104
Rectangle -16777216 true false 241 125 285 139
Polygon -1 true false 285 125 277 138 269 125
Polygon -1 true false 269 140 262 125 256 140
Rectangle -7500403 true true 45 120 195 195
Rectangle -7500403 true true 45 114 185 120
Rectangle -7500403 true true 165 195 180 270
Rectangle -7500403 true true 60 195 75 270
Polygon -7500403 true true 45 105 15 30 15 75 45 150 60 120

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@
