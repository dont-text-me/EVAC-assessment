;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;This file was tested in netlogo 6.4;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;Exam number: Y3892609;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

extensions [rnd]
breed [sheep a-sheep]
breed [dogs dog]
globals [
  current-generation
  num-dog-actions
  num-dog-states
  attention-chromosome-length
  avg-fitness
  avg-displaced-sheep
  lowest-ind-score
  final-gen-herd-score ;; the herd score at the very end of a generation
  input-layer-width
  score-at-gen-start
  score-at-gen-end
  elite-pack
]
sheep-own [
  last-x
  last-y
  last-move ;; [0-4], 0, 1, 2, 3, 4 is staying put, north, east, south and west respectively
  move-made-in-this-tick ;;boolean, for tracking which action to take, if a higher-priority action resulted in a move, do not take any other actions
  next-patch ;; where to go on the next tick
]

dogs-own [
  pack-number ;; which pack this dog belongs to
  role-number ;; which role in the pack this dog has (used for crossover)
  attention-chromosome ;; determines which part of the dog's observation of its surroundings influences its actions the most (see info tab)
  next-patch ;; where to go on the next tick
  fitness
  displaced-sheep ;; how many sheep this dog in particular has scared away
  generation ;; which generation is this dog from
  last-move ;; last move the dog made (encoded same as the sheep)
  f3
]


to setup
  clear-all
  reset-ticks
  set input-layer-width 8

  set attention-chromosome-length ((input-layer-width * hidden-layer-width) + (hidden-layer-width * 5)) ;; number of weights in a flattened neural net

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
  set score-at-gen-start herd-score

  set-default-shape dogs "wolf 2"

  foreach range n-packs [ pack-num -> ;; populate the packs: start each pack at a random coordinate
    let pack-center list random-xcor random-ycor
    foreach range n-dogs-per-pack [ role-num -> ;; create a dog with each role for each pack
      create-dogs 1 [
        set pack-number pack-num
        set role-number role-num
        set fitness herd-score
        set displaced-sheep 0
        set last-move 0
        set generation current-generation
        set color item pack-num remove violet remove green base-colors ;; so that the wolves don't blend with the grass
        setxy ((item 0 pack-center) + random-float 2) ((item 1 pack-center) + random-float 2)
        setup-chromosomes
      ]
    ]
  ]
  set elite-pack nobody

  reset-ticks
end

to-report random-state
  report list (random num-dog-actions) (random num-dog-states)
end

to setup-chromosomes

  set attention-chromosome n-values attention-chromosome-length [random-normal 0 1]
end

to-report herd-score
  let avg-sheep-x mean [xcor] of sheep
  let avg-sheep-y mean [ycor] of sheep

  let sigma-x sum [(xcor - avg-sheep-x) ^ 2] of sheep
  let sigma-y sum [(ycor - avg-sheep-y) ^ 2] of sheep

  report (sigma-x + sigma-y) / n-sheep
end

to go
  if ticks < ticks-per-generation [
  ask sheep [tick-sheep] ;; plan move according to assessment brief
  ask dogs [
      ifelse default-behaviour
      [tick-dogs-default]
      [tick-dogs]
    ] ;; plan move
  ask turtles [move-to next-patch] ;; execute move
  tick
  ]
  if ticks = ticks-per-generation [
    end-of-cycle
    reset-ticks
  ]
end

to conduct-experiment
  let final-gen-herd-scores []
  let current-repetition 0
  repeat experiment-repetitions [
  setup
  while [current-generation != experiment-generations] [go]
  set final-gen-herd-scores lput (score-at-gen-end) final-gen-herd-scores
  show (word "Completed repetition " (current-repetition + 1) " of " experiment-repetitions)
  set current-repetition (current-repetition + 1)
  ]

  show "Experiment finished. Storing results...."
  ;; store results in the file
  file-open experiment-out-file-name
  file-write final-gen-herd-scores
  file-close
  show "Done"
end


to end-of-cycle
  set score-at-gen-end herd-score
  let difference 0
  if score-at-gen-end < score-at-gen-start [set difference score-at-gen-start - score-at-gen-end]

  ask dogs [
    let total-performance difference + (displaced-sheep-reward-multiplier * displaced-sheep)
    set fitness ifelse-value total-performance > 0 [total-performance][0]
    if use-f3-fitness[
    compute-f3
    set fitness f3
    ]
  ]
  ;; pick elite ----------
  let max-median-fitness median [fitness] of dogs with [pack-number = 0]
  let elite-pack-num 0

  foreach range n-packs [ pack-num ->
    let pack-median-fitness median [fitness] of dogs with [pack-number = pack-num]
    if pack-median-fitness > max-median-fitness [
      set elite-pack-num pack-num
      set max-median-fitness pack-median-fitness
    ]
  ]
  ifelse elite-pack = nobody [
    set elite-pack dogs with [pack-number = elite-pack-num] ;; first time the elite is picked
  ][
    if max-median-fitness > median [fitness] of elite-pack [
      ask elite-pack [die]
      set elite-pack dogs with [pack-number = elite-pack-num] ;; new elite
    ]
  ]

  ask elite-pack [set color violet];; royal purple
  ;; ------------------------------
  ;; perform fitness sharing: ask the top performing dog to share some of its fitness with its teammates

  foreach range n-packs [ pack-num ->
    let top-dog-in-pack max-one-of dogs with [pack-number = pack-num] [fitness] ;; find the dog with the highest fitness (i.e. best performance)
    let second-best-dog max-one-of dogs with [pack-number = pack-num and fitness < [fitness] of top-dog-in-pack] [fitness] ;; get second best fitness
    let sharing-portion (0.8 * ([abs fitness] of top-dog-in-pack) - ([abs fitness] of second-best-dog))
    if sharing-portion > 3 [ ;; if the dog can afford to share fitness
    ask top-dog-in-pack [set fitness (fitness - sharing-portion)] ;; top dog sacrificies some of its fitness

    ask dogs with [pack-number = pack-num and role-number != [role-number] of top-dog-in-pack][
      set fitness (fitness + sharing-portion / (n-dogs-per-pack - 1)) ;; teammates receive sacrifice, split among the team
    ]
    ]
  ]


  set final-gen-herd-score herd-score
  set avg-fitness mean [fitness] of dogs
  set avg-displaced-sheep mean [displaced-sheep] of dogs
  hatch-next-generation ;; spawn next set of dogs

  ;; reset herd: Note that it's not necessary to re-hatch sheep as their behaviour is hard-coded, simply reset their
  ;; positions to random coordinates
  ask sheep [setxy random-xcor random-ycor]
  set score-at-gen-start herd-score
end


to tick-dogs
  let next-move perceive-env

  ifelse next-move = 0 [set next-patch patch-here] ;; stay here
  [ifelse next-move = 1 [set next-patch patch-at 0 1] ;; north
  [ifelse next-move = 2 [set next-patch patch-at 1 0] ;; east
  [ifelse next-move = 3 [set next-patch patch-at 0 -1] ;; south
  [set next-patch patch-at -1 0]]]] ;; west
  if next-patch = nobody [;; the next coordinate doesn't exist (won't happen in a wrapping world but could happen when walls are present)
    set next-patch one-of neighbors4 ;; move somewhere else that isnt a wall
  ]
  if count sheep-here >= 1 [ ;; the sheep will move away on the next move - increment the dog's counter
    set displaced-sheep displaced-sheep + count sheep-here
  ]
end

to tick-dogs-default ;; default behaviour - pick the next move randomly

  if count sheep-here >= 1 [ ;; the sheep will move away on the next move - increment the dog's counter
    set displaced-sheep (displaced-sheep + count sheep-here)
  ]

  set next-patch one-of (patch-set patch-here neighbors4) ;; choose a random neighbor or stay
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;Dog code (genetic algorithm);;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to-report perceive-env
  ;; calculate features of the environment
  let mean-sheep-around-teammates mean [count sheep in-radius dog-vision-radius] of other dogs with [pack-number = [pack-number] of self]
  let avg-distance-to-team mean [distance myself] of other dogs with [pack-number = [pack-number] of self]
  let dogs-around-me count other dogs in-radius dog-vision-radius

  ;; make the dog spin around and look at the sheep in each of the four directions

  ;; facing north
  let sheep-north count sheep in-cone dog-vision-radius 90
  rt 90 ;; now facing east
  let sheep-east count sheep in-cone dog-vision-radius 90
  rt 90 ;; now south
  let sheep-south count sheep in-cone dog-vision-radius 90
  rt 90 ;; now west
  let sheep-west count sheep in-cone dog-vision-radius 90
  rt 90 ;; now north again, ready for next tick

  ;; ------------------------------------------------------------------------------

  ;; prepare neural network inputs
  let input (
    list
    (last-move * 10)
    sheep-north
    sheep-east
    sheep-south
    sheep-west
    mean-sheep-around-teammates
    avg-distance-to-team
    dogs-around-me
  )
  ;; reshape chromosome into neural network
  let first-layer (chunk input-layer-width (sublist attention-chromosome 0 (input-layer-width * hidden-layer-width))) ;; put first layer into the right shape
  let second-layer (chunk hidden-layer-width (sublist attention-chromosome (input-layer-width * hidden-layer-width) attention-chromosome-length)) ;; put second layer into the right shape
  ;; put input through first layer and activate
  let activated-output relu (matrix-product input first-layer)
  ;; put resulting value through second layer
  let final-output matrix-product activated-output second-layer
  ;; determine which class the output represents and store it as the previous move
  set last-move argmax final-output
  report last-move
end

to compute-f3
  set f3 0                       ; reset f3
  let i 0                        ; gene counter set to 0
  repeat length attention-chromosome [     ; for each locus (aka position) on the chromosome...
  let gene item i attention-chromosome     ; store the value of my i-th gene
    let same-gene-count 1        ; me and how many other turtles have the same allele?
                                 ; (i.e. same value in the same position on the chromosome)
    let tmp fitness               ; to sum up and average fitnesses
    let my-role role-number
    ask other dogs with [(in-tolerance (item i attention-chromosome) gene) and role-number = my-role] [
      set tmp tmp + fitness       ; energy is the fitness of a relevant turle from the other ones
      set same-gene-count same-gene-count + 1
    ]
    set tmp ( tmp / same-gene-count ) ; essentially, computes f2 for that gene
    set i i + 1 ; increment the gene counter
    set f3 f3 + tmp
  ]
  set f3 (f3 / i)
end

to-report dot-product [list1 list2] ;; compute the dot product of two lists. The lists must be of the same length.
  if (length list1) != (length list2) [error (word "Mismatched list dimensions in lists " list1 " and " list2)]
  report reduce [[running-total index] -> running-total + ((item index list1) * (item index list2))] range length list1
end

to-report relu [items] ;; map ReLu to a list of values
  report map [it -> ifelse-value it > 0 [it][0]] items
end

to-report matrix-product [m1 m2]
  report map [row -> dot-product m1 row] m2
end

to-report euclidean-dist [l1 l2]
  report sqrt (sum map [it -> it ^ 2] l1) + (sum map [it -> it ^ 2] l2)
end

to-report in-tolerance [f1 f2]
  report abs (f1 - f2) <= 0.0001
end

to-report chunk [chunk-size values]
  ;; Break list into sublists of size chunk-size
  let result []
  foreach range (floor (length values / chunk-size)) [i ->
    set result lput (sublist values (i * chunk-size) ((i * chunk-size) + chunk-size)) result
  ]
  report result
end

to-report argmax [items] ;; return the index of the largest element in list
  let arg-max 0
  let max-item first items
  let i 0
  foreach items [it ->
    if it > max-item [
      set max-item it
      set arg-max i
    ]
    set i (i + 1)
  ]
  report arg-max
end

to mutate-chromosomes
  set attention-chromosome map [
    it -> ifelse-value attention-mutation-chance < random-float 1 [
      it ;; keep as is
  ] [
      random-normal 0 1
  ]] attention-chromosome
end

to hatch-next-generation
  let tempSet (dogs with [generation = current-generation])
  let elite-pack-number [pack-number] of one-of elite-pack
  foreach remove elite-pack-number range n-packs [ pack-num -> ;; populate the non-elite packs: start each pack at a random coordinate
    let pack-center list random-xcor random-ycor
    foreach range n-dogs-per-pack [ role-num -> ;; create a dog with each role for each pack
      let median-fitness-of-role median [fitness] of tempSet with [role-number = role-num]
      create-dogs 1 [
        ;; rank-based selection: the likelihood of an dog being picked depends on how much larger its fitness is than the median fitness of that role.
        let parent-dog rnd:weighted-one-of tempSet with [role-number = role-num] [max (list 0.001 (fitness / median-fitness-of-role))]
        set pack-number pack-num
        set role-number role-num
        set fitness [fitness] of parent-dog
        set displaced-sheep 0
        set last-move 0
        set generation current-generation + 1
        set color item pack-num remove violet remove green base-colors
        setxy ((item 0 pack-center) + random-float 2) ((item 1 pack-center) + random-float 2)
        set attention-chromosome [attention-chromosome] of parent-dog
        mutate-chromosomes
      ]
    ]
  ]
  ask tempSet with [(member? self elite-pack) = false] [die] ;; everyone but the elite dies
  ask elite-pack [set generation current-generation + 1] ;; elite gets to continue
  set current-generation current-generation + 1
end

;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;; Sheep code ;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;


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

to move-and-update-last [candidate-patches]
  ;; about to move: record the previous position to be used if this sheep ever needs to execute action 5
    set last-x xcor
    set last-y ycor
    set next-patch one-of candidate-patches ;; if several patches match the conditions, pick randomly
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

end

to sheep-action-1
  ifelse count dogs-here >= 1 [
    let acceptable-patches neighbors4 with [count dogs-here = 0]
    ifelse count acceptable-patches = 0 [
      set move-made-in-this-tick false ;; no neighboring patches without a dog found
    ]
    [
      move-and-update-last acceptable-patches
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
    move-and-update-last acceptable-patches
  ]
  ]
  [
    set move-made-in-this-tick false
  ]
end

to sheep-action-3
  let current patch-here
  let acceptable-patches neighbors4 with [count neighbors4 with [count sheep-here >= 1 and self != current ] >= 1]
  ifelse count acceptable-patches = 0 [
    set move-made-in-this-tick false ;; no neighboring patches who themselves neighbor a patch with sheep found
  ]
  [
    move-and-update-last acceptable-patches
  ]
end

to sheep-action-4
  let acceptable-patches neighbors4 with [count sheep-here < count [sheep-here] of myself]
  ifelse count acceptable-patches = 0 [
    set move-made-in-this-tick false ;; no neighboring patches with less sheep than here found
  ]
  [
    move-and-update-last acceptable-patches
  ]
end

to sheep-action-5
  ;; Note that it's not necessary to track the move-made-in-this-tick variable here
  ;; choose the next action - same as last one with a chance of 0.5 and a different one with a chance of 0.125
  let next-move rnd:weighted-one-of-list [0 1 2 3 4] [it -> ifelse-value it = last-move [0.5] [0.125]]
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
15
790
571
-1
-1
11.164
1
13
1
1
1
0
1
1
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
5
45
60
78
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
65
45
120
78
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
65
45
120
78
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
5
125
205
158
n-dogs-per-pack
n-dogs-per-pack
0
50
5.0
1
1
NIL
HORIZONTAL

SLIDER
5
165
205
198
n-sheep
n-sheep
0
100
50.0
1
1
NIL
HORIZONTAL

MONITOR
990
670
1107
715
Sheep herd score
herd-score
3
1
11

PLOT
810
195
1105
345
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

MONITOR
810
670
942
715
Current generation
current-generation
1
1
11

SLIDER
5
85
205
118
ticks-per-generation
ticks-per-generation
0
10000
1000.0
50
1
NIL
HORIZONTAL

SLIDER
5
205
205
238
n-packs
n-packs
0
10
7.0
1
1
NIL
HORIZONTAL

SLIDER
5
665
215
698
dog-vision-radius
dog-vision-radius
1
20
14.0
1
1
NIL
HORIZONTAL

PLOT
810
510
1105
660
Average fitness of dogs
Generation
Fitness
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plotxy current-generation avg-fitness"

SLIDER
5
710
215
743
displaced-sheep-reward-multiplier
displaced-sheep-reward-multiplier
0
100
2.0
1
1
NIL
HORIZONTAL

PLOT
810
35
1105
185
Average displaced sheep per generation
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
"default" 1.0 0 -16777216 true "" "plotxy current-generation avg-displaced-sheep"

SWITCH
5
805
210
838
default-behaviour
default-behaviour
1
1
-1000

TEXTBOX
815
15
965
33
Environment statistics
11
0.0
1

TEXTBOX
10
10
190
36
Simulation/experiment controls
11
0.0
1

TEXTBOX
10
650
160
668
Dog controls
11
0.0
1

TEXTBOX
5
770
210
811
Pick each move with equal probability or optimise using the GA?
11
0.0
1

BUTTON
5
580
205
613
Run experiment
conduct-experiment
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
5
425
207
458
experiment-generations
experiment-generations
0
100
15.0
1
1
NIL
HORIZONTAL

TEXTBOX
10
390
205
416
How many generations to run experiments for?
11
0.0
1

SLIDER
5
245
205
278
attention-mutation-chance
attention-mutation-chance
0
1
0.04
0.01
1
NIL
HORIZONTAL

PLOT
810
350
1105
500
Herd score at the end of each generation
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
"default" 1.0 0 -16777216 true "" "plotxy current-generation final-gen-herd-score"

SLIDER
5
465
210
498
experiment-repetitions
experiment-repetitions
0
100
7.0
1
1
NIL
HORIZONTAL

INPUTBOX
5
505
205
565
experiment-out-file-name
16-layer-net-5-percent-mut-f3-fitness.txt
1
0
String

SLIDER
5
285
205
318
hidden-layer-width
hidden-layer-width
1
32
16.0
1
1
NIL
HORIZONTAL

SWITCH
5
325
205
358
use-f3-fitness
use-f3-fitness
1
1
-1000

@#$#@#$#@
# Exam number: Y3892609, Netlogo version: 6.4.0

## Representation of dogs' behaviour

Each dog's genome is represented by a single chromosome containing floating-point numbers sampled from a gaussian distribution with mean 0 and standard deviation 1. At each tick, the chromosome is reshaped into a small neural network, with a single hidden layer and ReLu activation, the task of which is to assign the state of the world one of five possible next moves. The width of the hidden layer is controlled by a slider in the UI. The neural network takes the following information as the input: 


	* The count of sheep in their field of vision, in a 90 - degree "cone", looking in each of the four cardinal directions
* The mean count of sheep around other members of their team (see following sections)
* The previous move the dog has made
* The average distance to the dog's other team members
* The number of other dogs around

Overall, the network converts the 8 inputs into an integer of range [0-4], where 0 corresponds to staying put and 1-4 correspond to moving north, east, south and west respectively. 

While it would have been less computationally demanding to store the neural network weights in their required shape, storing them as a list allows for easy comparisons between individuals as well as easily mutating and iterating over the list using the built-in netlogo tools.

The neural network, in theory, would allow the dogs to draw complex conclusion after observing their environment and pick the best move to make at each timestep. Using the dogs' previous move as one of the inputs could also allow the dogs to have a short-term memory of their actions, allowing for simple strategies to evolve.

While other methods such as representing the dogs as state machines would allow for potentially smaller search spaces due to their structure, even a relatively narrow neural network could potentially have the capabilities to represent more complex behaviour. Therefore, by finding the right balance of network size and optimization parameters, individuals displaying successful behaviour can be evolved with relatively little computational costs.

## Default behaviour and fitness

### Default behaviour 

The default behaviour of each dog allows it to make 5 moves at random. To represent this in netlogo, at the end of each tick the dogs set their `next-patch` variable to one of 5 possible patches: the four neighbouring patches plus their current one. This is implemented by using netlogo built-ins.

	set next-patch one-of (patch-set patch-here neighbors4)

### Fitness estimation

The main component of each dog's fitness is the "herd score" of the pack of sheep, calculated according to the metric provided in the assessment brief. When the sheep are randomly placed on the field at the start of each generation, their initial score is calculated. Just before the next generation spawns, the difference of scores is used to determine the fitness of the dogs. If the score became larger i.e. worse, the dogs receive a fitness of zero. Otherwise, their fitness is equal to the difference in scores through their lifespan. To identify personal success in the dogs, an additional component of the fitness is represented as the number of sheep displaced by the dog. This has been chosen as a metric after observing the default behaviour of the sheep: after coming in contact with a dog, the sheep first seek a patch without a dog present and afterwards, tend to cluster together. Therefore, a dog coming in contact with a sheep is likely to lead to the sheep seeking other sheep in the next few ticks, leading to an improvement (decrease) in the herd score.

At the end of each tick, the number of sheep scared away by each dog is added to the herd score and set as the dog's fitness. All dogs benefit from a tighter flock, and all dogs are penalised for a poor score. The degree to which personal success affects fitness can be controlled by a slider in the simulation UI.


## Adaptation design and implementation

The following sections will outline the evolutionary algorithm whose aim is minimising the total herd score.

### Niching

To encourage cooperation and the evolution of specialised behaviours, the dogs are split into several "packs" and are assigned distinct roles within the pack. This is done by modifying the `pack-number` and `role-number` variables owned by each dog. 

The number of packs and roles within a pack are controlled by UI sliders, though it is recommended to keep the number of roles to 5 such that entire teams can be loaded to the test file.

At the start of each generation, each team is placed in a randomly chosen location, with each individual in the team placed within 2 squares of the pack "center". The dogs are then free to spread out as much as they deem necessary.

To keep the behaviours distinct, each "role" goes through a separate selection process: when a new generation of teams is spawned, selection for each role is done purely from the subset of the past generation with that role. This allows the dogs to evolve on different "tracks" and develop different behaviours.

To encourage cooperation, the success of each team is boosted by the individual success of its members, through a simple "altruism" procedure. At the end of each generation, the top performing individual of a team sacrifices some of its fitness and spreads it among its teammates. This way, the teams are rewarded for their members' success, which has the potential of evovling collaborating behaviours.
The amount shared by the top performing individual is 80% of the difference between it and the next best individual in a team, ensuring that even after sharing the individual does not lose its position in the ranking of its teammates.

### Selection

A rank-based selection algorithm is implemented to increase the individuals' chance of continuing to the next generation based on their performance. To achieve this in netlogo, the `weighted-one-of` function from the `rnd` extension is used.

At the end of each generation, a new set of teams is spawned, with blank chromosomes. To fill the chromosome of each new individual with a given role, an individual from the past generation with the same role is selected. The probability with which the individuals are selected is calculated by dividing the median fitness of dogs with that role by the current individual's fitness. Therefore, an individual with fitness twice the size of the median is twice as likely to be selected as an individual with median fitness. This ensures that the top performers are the most likely to make it to the next generation while still allowing a small probability of less performant individuals to continue on, ensuring a good variety in the genomes on the field.

### Crossover

Since the chromosomes represent a neural network, the changes brought along by crossover were deemed too extreme for the relatively sensitive structure of neural networks. Furthermore, swapping the positions of weights in a neural network is likely to completely change the individuals' perception of their surroundings, slowing down optimisation. Because of this, no crossover takes place and individuals evolve by mutation and selection alone, mirroring the approach to evolving neural networks seen in the first half of the module.

### Mutation

After a new generation is spawned, each individual undergoes mutation. To mutate the chromosome, each item of the chromosome is changed to a random float, sampled from a gaussian distribution with the same mean and standard deviation as the one used to initialise the weights. The probability of each individual gene mutating can be set using a slider in the simulation UI and is expected to work best with a value in range of 0.03 - 0.1

### Fitness sharing

Alongside sharing fitness among their teams, the dogs also receive additional boosts to their fitness via the "extended fitness" algorithm. To encourage faster convergence and boost the fitness of individuals that exhibit genes that contribute to a good score, a fitness sharing technique is employed. At the end of every generation, the f3 fitness of individuals is calculated. In this algorithm, individuals receive a portion of the fitness of individuals they are genetically close with. A small modification was made to the algorithm to support floating-point genes, where instead of checking that the genes are exactly equal, they are checked to be within a tolerance instead. Given the scale of the input variables and the network weights, a tolerance of 0.0001 is used for the algorithm. To further encourage specialisation, the f3 fitness function only compares the closeness of individuals sharing the same role across different teams.

## Evaluation design

### Automated experiment setup

The UI provides facilities for conducting experiments with a given dog/algorithm configuration. It allows for running the algorithm a chosen number of times, for a certain number of generation each time. The results displayed here used 7 repetitions of 15 generations in order to keep the runtime of each experiment manageable while still allowing enough time for successful individuals to emerge. The result of each experiment is the score of the herd at the end of the last generation. Storing the distribution of scores over the experiment repetitions ensures the interpretability of the results in the context of the assessment brief without it being affected by the definition of fitness used.

In each experiment, the population consists of 7 packs with 5 individuals each. This was chosen as a compromise between computational costs, diversity and crowding of the field: a lower number of packs would limit the diversity of genomes for each of the pack roles, while a higher number of packs would require a larger number of sheep, larger field or both, leading to an increased runtime of the algorithm as well as not matching the testing conditions. Furthermore, a larger number of packs could lead to 

The results of each experiment are exported into a `txt` file, which can then be processed further. The tools used for this task were jupyter notebooks, numpy, scipy and matplotlib, allowing for a range of statistical tests to be ran on the data.

### Statistical test choice

The main purpose of statistical tests throughout the development of the algorithm was to investigate whether or not introducing a certain feature to the algorithm leads to statistically significant results. Therefore, each solution was first compared to the random dog behaviour in terms of the final fitness after 15 generations. Since the experiment setup described above produced a distribution of results, a Mann-whitney U test was used to see if the distributions are statistically significant. This test was chosen due to the fact that the two samples could be safely assumed to be independent: the dogs cannot be controlled both by their random behaviour and their chromosome.

If more than two samples were compared, a Kruskal-wallis test was used to investigate whether the medians of each sample are equal. This, along with the Mann-whitney test were chosen due to the assumed non-parametric nature of the evolved dog behaviour.

## Experimental evaluation

### Experiment scenarios

The following scenarios were tested:

	* Random behaviour
* Neural network with 8 hidden neurons, 0.05 mutation chance, 7 packs
* Neural network with 8 hidden neurons, 0.1 mutation chance, 7 packs
* Neural network with 8 hidden neurons, 0.15 mutation chance, 7 packs
* Neural network with 16 hidden neurons, 0.05 mutation chance, 7 packs
* Neural network with 16 hidden neurons, 0.1 mutation chance, 7 packs
* Neural network with 16 hidden neurons, 0.15 mutation chance, 7 packs
* Neural network with 8 hidden neurons, 0.05 mutation chance, f3 fitness
* Neural network with 16 hidden neurons, 0.05 mutation chance, f3 fitness

### Results

To visually examine the results of each experiment and provide a basic way to compare them, boxplots for the distribution of final herd scores were created.
The plot suggests that genetic algorithm led to little improvement over random behaviour, with only certain experiments showing relative success.

![](experiment-hists.png)

From the above plot, the configurations with a mutation chance of 0.05 (5%) show the most potential, with relatively narrow interquartile ranges and low minimum herd scores. To investigate the statistical difference between random behaviour and the above algorithms, a Mann-Whitney U test was conducted on the two samples, resulting in p values of **0.128** and **0.165** for the 16 and 8 wide hidden layer networks respectively. While this is a relatively poor score which would normally not allow rejecting the null hypothesis of the samples coming from the same distribution, it is significantly lower than the same test conducted for other samples, suggesting that the above configurations have the most potential. The p value for other configurations and random dog behaviour is snown on the below plot.

![](mann-whitney-results.png)

The plot above suggests that most results are highly likely to come from the same distribution as the random behaviour.

To test the null hypothesis of the scores in all samples having the same population median, a Kruskal-Wallis test was used, returning a p value of **0.59**. This suggests that there is not enough evidence to reject the null hypothesis of each experiment leading to a distribution of scores with a different mean, showing a lack of evidence for the genetic algorithm leading to an improvement in scores over random behaviour.

### Conclusion

While the Kruskal-Wallis test does not allow the assumption of the genetic algorithms having a statistically significant difference over random behaviour, examining the pairwise scores provides limited support for certain configurations to lead to more significant changes than others. Specifically, the configurations with a 5% mutation rate and no f3 fitness, with p values significantly lower than other configurations. A comparison between the two samples, however, shows little to no evidence over different hidden layer widths leading to a statistically significant difference, with a Mann-Whitney score of **0.8**.

The above results suggest a need for significant improvements to the genetic algorithm. This could come in form of expanding the dogs' perception of their field, evolving larger populations on larger fields or making the dogs' task simpler with tools such as walls or increased herding behaviour in the sheep themselves. Overall, the investigations done here have led to limited success. Despite this, the fact that the 16 neuron dogs have achieved one of the lowest minimum scores while displaying the most statistically significant results over random behaviour suggests that this configuration is the most successful of the ones tested here, making it the choice for the final algorithm. 
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
