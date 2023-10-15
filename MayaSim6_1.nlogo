;    MayaSim: An agent-based model of the ancient Maya social-ecological system.
;    Copyright (C) 2013  Scott Heckbert
;
;    scott.heckbert@gmail.com

extensions [ gis ]

;##############       SETUP        ##################         SETUP       ##################

globals[
  mask-dataset
  elevation-dataset
  soils-dataset
  temp-dataset
  precip-dataset
  land-patches
  vacant-lands
  traders
  border
  visited-nodes
  network-start
  failed-cities
  crop1-yield
  climate-cycle-counter
  abandoned-crops
  new-crops
  total-migrant-population
  giant-component-size
  component-size
  giant-start-node
  search-completed
  origin-city
  area
  mx
  mn
  total-migrant-utility
  Rainfall-Change]

patches-own [
  original-rainfall
  rainfall
  temp
  elevation
  soil-prod
  slope
  flow
  pop-gradient
  env-degrade
  npp
  yield
  ag-suit
  BCA-ag
  is-ag
  ag-impact
  forest-state
  succession-counter
  travel-cost
  overland-TC
  freshwater-TC
  cropping-value
  water-value
  forest-food-value
  rain-value
  ecosystem-services-value
  is-vacant
  patch-migrant-utility
  Travel-Cost-ut
  ES-ut
  my-settlement
  is-land-patch
  is-border]

breed [ settlements settlement]

settlements-own [
  birthrate
  trade-strength
  centrality
  cluster-number
  age
  population
  gdp-per-cap
  trade-GDP
  yield-GDP
  ecoserv-GDP
  death-rate
  out-migration
  out-migration-rate
  settlement-yield
  ecoserv-benefit
  my-ag-patches
  my-influence-patches
  rank
  trade-benefit
  explored?
  city-travel-cost  ]

breed [ raindrops raindrop]
raindrops-own[ rain-volume]
breed [ searchers searcher]
searchers-own[ location path-cost ]
links-own [   trade-flow  ]
breed [ migrants migrant ]
migrants-own [
  migrant-population
  mig-TC-pref
  mig-ES-pref
  my-migrant-location
  my-pioneer-patch
  pioneer-set
  my-migrant-utility
  parent]

to startup
  clear-all
  reset-ticks
  setup-gis
  climate-scenario
  rain
  calc-npp
  calc-travel-cost
  reset
end

to setup-gis
  import-pcolors-rgb "Maya.png"
  set elevation-dataset gis:load-dataset "dem.asc"
  set soils-dataset gis:load-dataset "soil.asc"
  set temp-dataset gis:load-dataset "temp.asc"
  set precip-dataset gis:load-dataset "precip.asc"
  gis:set-world-envelope (gis:envelope-union-of
    (gis:envelope-of elevation-dataset)
    (gis:envelope-of soils-dataset)
    (gis:envelope-of temp-dataset)
    (gis:envelope-of precip-dataset)             )
  gis:apply-raster elevation-dataset elevation
  gis:apply-raster soils-dataset soil-prod
  gis:apply-raster temp-dataset temp
  gis:apply-raster precip-dataset original-rainfall
  ask patches [  ifelse (soil-prod <= 0) or (soil-prod >= 0)   [ ] [ set soil-prod 1.5   ] if elevation <= 1 [set soil-prod 1.5]  if soil-prod >= 6 [  set soil-prod 1.5]    ]
  ask patches [  ifelse (elevation <= 0) or (elevation >= 0)  [ set is-land-patch 1] [ set elevation 0 ]  ]
  ask patches [  ifelse (temp <= 0) or (temp >= 0)  [  ] [ set temp 21 * 12 ]  ]
  ask patches [  ifelse (original-rainfall <= 0) or (original-rainfall >= 0)  [ ] [ set original-rainfall 1200 ]  ]
  set land-patches patches with [ is-land-patch  = 1 ]
  set border (land-patches with [ (sum [is-land-patch] of neighbors < 6) ])
  ask border [set is-border 1]
  set area ( 516484  / (count land-patches)) ; Km2
  ask land-patches [
    set rainfall original-rainfall
    set temp temp / 12]
  repeat  max-pxcor / 20 [diffuse  soil-prod 0.9]
  calculate-slope
end

to reset
  clear-all-plots
  reset-ticks
  ask turtles [die]
  setup-patches
  if Humans [ setup-settlements ]
  set climate-cycle-counter 0
  set Rainfall-Change 0
  update-view
end

to setup-patches
  set-default-shape turtles "circle"
  ask land-patches [
    set is-ag 0
    set pop-gradient 0
    set ag-impact 0
    set env-degrade 0
    set succession-counter  random npp / 3
    set forest-state 1  if succession-counter > state-change-s2 [ set forest-state 2 ]  if succession-counter > state-change-s3  [ set forest-state 3  ]]
end

to setup-settlements
  set-default-shape settlements "mayahouse"
  ask n-of num-cities land-patches [
      sprout-settlements 1[
        set color grey
        set rank 4
        set population  1000 + random 1000
        set death-rate  random-float 0.1 + 0.05
        set gdp-per-cap  random-float 5  + 5   ]]
  ask land-patches with [count settlements-here > 0] [ set my-settlement  ( one-of settlements-here)   ]
  ask settlements [  area-of-influence  set my-ag-patches ( my-influence-patches with [my-settlement = myself])  ask my-ag-patches [   set is-ag 1]  ]
end

to calculate-slope
  let horizontal-gradient gis:convolve elevation-dataset 3 3 [ 1 0 -1 2 0 -2 1 0 -1 ] 1 1
  let vertical-gradient gis:convolve elevation-dataset 3 3 [ 1 2 1 0 0 0 -1 -2 -1 ] 1 1
  let gradient gis:create-raster gis:width-of elevation-dataset gis:height-of elevation-dataset gis:envelope-of elevation-dataset
  let x 0
  repeat (gis:width-of gradient)
  [ let y 0
    repeat (gis:height-of gradient)
    [ let gx gis:raster-value horizontal-gradient x y
      let gy gis:raster-value vertical-gradient x y
      if ((gx <= 0) or (gx >= 0)) and ((gy <= 0) or (gy >= 0))
      [ gis:set-raster-value gradient x y sqrt ((gx * gx) + (gy * gy)) ]
      set y y + 1 ]
    set x x + 1 ]
  let min-g gis:minimum-of gradient
  let max-g gis:maximum-of gradient
  gis:apply-raster gradient slope
  ask land-patches [
    ifelse (slope <= 0) or (slope >= 0)  [ ] [ set slope (5 + random 10 ) ]
    set slope log (slope + 1) 2]
end

;##############       RUN        ##################         RUN       ##################

to run-model
  if Nature [
    climate-scenario
    if raining [
      rain]
    calc-npp
    calc-pop-gradient
    forest-succession
    calc-ecosystem-services
    calc-soil-degradation
    calc-BCA-Ag
    Agriculture ]
  if Humans [
    Demographics
    if trade and ticks >= 20 [
      Build-routes
      calc-travel-cost
      trading]
    recalc-gdp ]
  update-view
  tick
  if ticks = 400 [stop] ; %
  if ticks = 1 [clear-all-plots]
end

;#############         MODEL FUNCTIONS         ##################         MODEL FUNCTIONS         ##################

to climate-scenario
   if Climate-Cycle [
     set climate-cycle-counter  climate-cycle-counter +  1
     if climate-cycle-counter = Climate-var * 8 [set Rainfall-Change Rainfall-Change - rain-change ]
     if climate-cycle-counter = Climate-var * 7 [set Rainfall-Change Rainfall-Change + rain-change ]
     if climate-cycle-counter = Climate-var * 6 [set Rainfall-Change Rainfall-Change + rain-change ]
     if climate-cycle-counter = Climate-var * 5 [set Rainfall-Change Rainfall-Change + rain-change ]
     if climate-cycle-counter = Climate-var * 4 [set Rainfall-Change Rainfall-Change + rain-change ]
     if climate-cycle-counter = Climate-var * 3 [set Rainfall-Change Rainfall-Change - rain-change]
     if climate-cycle-counter = Climate-var * 2 [set Rainfall-Change Rainfall-Change - rain-change ]
     if climate-cycle-counter = Climate-var * 1 [set Rainfall-Change Rainfall-Change - rain-change ]
     if climate-cycle-counter >= Climate-var * 8 [set climate-cycle-counter 0  ]]
   if Climate-Change [
     ask land-patches [
       let rainfall-multiplier  (1 + Rainfall-Change  ) ; 1 +  max-dist-fulcrum / distance-to-fulcrum *
       let cleared-rainfall-effect (( count (neighbors with [forest-state = 1]  ) * Veg-Rainfall ))
       set rainfall (  original-rainfall  * rainfall-multiplier)  - cleared-rainfall-effect]]
end

to rain
  ask raindrops [die]
  ask land-patches [
    set flow 0]
  ask n-of ((count land-patches) * precip-percent) land-patches [
      sprout-raindrops 1 [
        set color blue
        set rain-volume ( rainfall / 1000000 / precip-percent * 10) ; cubic km2  # conversion
        set size rain-volume * 30  ]]
   repeat rain-steps   [
     ask raindrops [
        if random-float 100 < Infitration [die]
        let target min-one-of neighbors [ elevation + ((sum [rain-volume] of raindrops-here) ) ]
        ifelse [elevation + ((sum [rain-volume] of raindrops-here) )] of target < elevation + ((sum [rain-volume] of raindrops-here) )[
          set color blue
          move-to target
          ask patch-here [ set flow (flow + ([rain-volume] of myself ) )]
          if [is-land-patch] of patch-here = 0 or [is-border] of patch-here = 1 [die] ][
            set color green ]]] ; and don't count flow... ;
  ask raindrops [die]
end

to calc-npp ;
  ask land-patches [
    let npp-rain (  3000 * ( 1 - exp( -0.000664 * rainfall))  )
    let npp-temp (  3000 / ( 1 + exp( 1.315 - (0.119 * temp))))
    ifelse (npp-rain < npp-temp) [  set npp ( npp-rain ) ][ set npp ( npp-temp ) ] if npp < 500 [set npp 500]]
end

to forest-succession
  let mean-npp (mean [npp] of land-patches)
  let interval 4
  repeat interval [
    ask land-patches with [is-ag = 1][  set forest-state 1 set succession-counter 1 ]
    ask land-patches with [is-ag = 0][
      set succession-counter (succession-counter + 1 )
      let npp-multiplier   (npp / mean-npp )
      if random-float 100 < disturb-rate * (pop-gradient * 2 + 1 ) [
        if forest-state = 2 [  set forest-state  1  set succession-counter 1 ]
        if forest-state = 3 [  set forest-state  2  set succession-counter state-change-s2]]
      if forest-state = 1 and state-change-s2 / npp-multiplier <= succession-counter  [  set forest-state 2  set succession-counter state-change-s2 ]
      if forest-state = 2 and state-change-s3 / npp-multiplier <= succession-counter and (count neighbors with [forest-state = 3 ] >= s3num-neigh) [  set forest-state 3  ] ] ]
end

to Agriculture
  set failed-cities 0
  set abandoned-crops 0
  set new-crops 0
  ask land-patches [
    set is-vacant 1
    set my-settlement 0    ]
  ask settlements [
    if count my-ag-patches = 0 [ set failed-cities  failed-cities + 1 die]
    ask my-ag-patches [   set my-settlement myself]]
  let count-ouside count land-patches with [is-ag = 1 and my-settlement = 0 ]
  set abandoned-crops abandoned-crops + count-ouside
  ask land-patches with [is-ag = 1 and my-settlement = 0 ] [set is-ag 0 set yield 0 ]
  ask settlements [    area-of-influence  ]
  ask settlements with [ count my-ag-patches > 0 ][
    let ag-pop-density (population / count my-ag-patches / area)
    if ag-pop-density < 40 and age > 5   [
     repeat  ceiling ( 30 / ag-pop-density  )  [
       ask min-one-of my-ag-patches [    (BCA-ag - (ag-travel-cost * sqrt area * distance myself) /  ([sqrt population] of myself)  )  ] [  ; ^
         set is-ag 0                set my-settlement 0         set yield 0
         set abandoned-crops abandoned-crops + 1  ]]]
  let newest-crops  ( ag-pop-density / 125 )
  repeat floor newest-crops [
    let ag-search-list my-influence-patches with [ is-ag = 0 and  (BCA-ag - (ag-travel-cost * (sqrt area * distance myself)) /  ([sqrt population] of myself)  )  > 0] ; ^
    ifelse count ag-search-list > 0 [
      ask max-one-of ag-search-list [( BCA-ag - (ag-travel-cost * (sqrt area * distance myself)) /  ([sqrt population] of myself)  )  ][; ^
        set my-settlement ( myself )
        set is-ag 1
        set new-crops new-crops + 1   ]][]]]
  ask settlements [ ; abandon crops
    ask my-ag-patches with [ (BCA-ag - (ag-travel-cost * sqrt area * (distance myself)) /  ([sqrt population] of myself ) ) < 0 ] [; ^
      set is-ag 0      set my-settlement 0       set yield 0
      set abandoned-crops abandoned-crops + 1]]
  ask settlements [
    set my-ag-patches ( my-influence-patches with [ my-settlement = myself])
    ask my-influence-patches [set is-vacant 0]]
  ask settlements [
    set settlement-yield 0
    ask my-ag-patches [
      set yield (max-yield * (1 - origin-shift * ( exp (slope-yield * ag-suit)  )))
      if yield <= 0 [set yield 1]   ]]
  ask settlements with [count my-ag-patches > 0] [
    set settlement-yield ( mean [yield] of my-ag-patches )  ]
end

to calc-soil-degradation
  ask settlements [  ask my-ag-patches [  set ag-impact ag-impact + soil-deg-rate ]]
  ask land-patches [  if forest-state >= 3 [  set ag-impact ag-impact - soil-regen-rate ]  if ag-impact < 0 [ set ag-impact 0 ] ]
end

to calc-BCA-Ag
  ask land-patches [
    set ag-suit ( ag-suit-npp * npp  - ag-suit-slope * slope  -  ag-suit-flow * flow  +  ag-suit-soils * soil-prod - ag-impact)
    if ag-suit > 650 [ set ag-suit 650]   ]
  ask land-patches [
    set BCA-ag (max-yield * (1 - origin-shift * ( exp (slope-yield * ag-suit) )) )- estab-cost]
end

to calc-crop-yield
   set  crop1-yield []   let crop-counter 1
   repeat 1000 [
     let yield-c1 (max-yield * (1 - origin-shift * ( exp (slope-yield * crop-counter )   )))
     if yield-c1 < 0 [set yield-c1 0]     set  crop1-yield lput yield-c1 crop1-yield     set crop-counter (crop-counter + 1)   ]
 ; set-current-plot "Crop-Production"  clear-plot   set-current-plot-pen "yield-crop1"  foreach sort-by [ ?1 < ?2 ] crop1-yield [  plot ? ] ;; is this necessary in netlogo 6?
end

to calc-ecosystem-services
  ask land-patches [
    set water-value  flow  * flow-value-param
   ; set rain-value (rainfall / 1000 * precip-value-param) this was originally commented out
    set cropping-value crop-value-param * ag-suit
    set forest-food-value  forest-value-param * (forest-state - 1)
   ; set env-degrade pop-gradient  * ES-deg-factor  this was originally commented out
    set ecosystem-services-value (  cropping-value  +  water-value  + forest-food-value   ) ; - env-degrade   ; rain-value  +
       if  ecosystem-services-value > 250 [ set ecosystem-services-value 250 ]   if  ecosystem-services-value < 1 [ set ecosystem-services-value 1 ] ]
end

to Demographics
  ask settlements [
    set birthrate 0.15
    let max-birth-rate 0.15
    let min-birth-rate -0.2
    let shift 0.325
    if population-control and population >= 5000 [ set birthrate ( -((max-birth-rate - min-birth-rate)/ 10000) * population + shift  ) ]
    set age age + 1
    let max-death-rate 0.25
    let min-death-rate 0.005
    set death-rate ( -((max-death-rate - min-death-rate)/ 1) * gdp-per-cap + max-death-rate  )
    set death-rate  ( precision death-rate 3 )
    if death-rate <= min-death-rate [set death-rate min-death-rate]
    if death-rate >= max-death-rate [set death-rate max-death-rate]
    let max-mig-rate 0.15
    let min-mig-rate 0
    set out-migration-rate (-((max-mig-rate - min-mig-rate)/ 1) *  gdp-per-cap + max-mig-rate )
    if out-migration-rate < min-mig-rate [set out-migration-rate min-mig-rate]
    if out-migration-rate > max-mig-rate [set out-migration-rate max-mig-rate]
    set out-migration-rate  ( precision out-migration-rate 3 )
    set out-migration (out-migration-rate * population)
    let pop-change ((birthrate - death-rate )* population )
    set population int(population + pop-change  )   ]
    set vacant-lands ( land-patches with [ BCA-ag > 0 and is-vacant = 1])
    if migration and count vacant-lands > 300 [migrate]
  ask settlements [  if population <= estab-cost * 0.4    [  ask my-ag-patches [  set my-settlement 0  set is-ag 0]  set failed-cities  failed-cities + 1 die] ] ; #
  ask land-patches [  if count settlements-here > 1 [ ask one-of settlements-here  [ set failed-cities  failed-cities + 1 die]]]
end

to migrate
  ask  settlements with [out-migration > 400] [ ;
    if random 100 <= 50 [
    hatch-migrants 1   [
      set parent one-of settlements-here
      set migrant-population [out-migration] of parent
      ask parent [set population population - out-migration]
      set size 0.5
      set color ([color] of myself)
      set mig-TC-pref  TC-pref
      set mig-ES-pref  ES-pref  ]]]
  set total-migrant-population sum [migrant-population] of migrants
  ask migrants [
   ifelse count vacant-lands > 75 [] [ask parent [set population (population + ([migrant-population] of myself)) ] die]
   set pioneer-set (  n-of 75 vacant-lands ) ; # 15
   ask pioneer-set [
     let distance-to-settlement( sqrt area * distance myself)
     set Travel-Cost-ut ( [mig-TC-pref] of myself  * distance-to-settlement )
     set ES-ut ( [mig-ES-pref] of myself * [ecosystem-services-value] of self )
     set patch-migrant-utility ( Travel-Cost-ut + ES-ut)  ]
   set my-migrant-utility (max [ patch-migrant-utility ] of pioneer-set)
   set my-migrant-location (  max-one-of pioneer-set [patch-migrant-utility]  )
  ; show my-migrant-utility  also originally commented out
   if my-migrant-utility > 0 [      move-to my-migrant-location       ]  ]
  set total-migrant-utility sum [my-migrant-utility] of migrants

  ask migrants [
   let neigh-count count turtles-on patches with [sqrt area * (distance myself) <= 7.5]; neighbors
   if neigh-count > 1 [die]
   if count turtles-here > 1 [die]
   if count settlements-here = 0 [
     ask patch-here [
       sprout-settlements 1[
         set rank 4
         set population ([migrant-population] of one-of migrants-here)
         set color [color] of one-of migrants-here
         set color  grey
         ask patch-here [ set my-settlement  ( one-of settlements-here)   ]
         set my-ag-patches ( land-patches with [my-settlement = myself])  ask my-ag-patches [  set is-ag 1]
         set my-influence-patches  land-patches with [sqrt area * distance myself <= 2 ]]]  die  ]]
end

to area-of-influence
  let pop-scaled-dist (population ^ 0.8 ) / 60
  set my-influence-patches ( land-patches with [ sqrt area * distance myself  <= pop-scaled-dist])
end

to calc-pop-gradient
  ask land-patches [set pop-gradient 0]
  ask settlements  [
    ask my-influence-patches [
      let dist sqrt area * distance myself
      set pop-gradient (pop-gradient + [population] of myself / (dist + 1) / 300 )
      if  pop-gradient > 15 [set pop-gradient 15]]] ; #
end

to calc-travel-cost
  ask land-patches [
    set travel-cost 40
    set freshwater-TC 0
    set overland-TC ( slope-TC * slope)
    if flow > 0 [ set freshwater-TC flow-TC *  flow   ]
    set travel-cost  ( travel-cost + overland-TC - freshwater-TC )     if travel-cost > 70 [set travel-cost 70]  if travel-cost < 1 [set travel-cost 1]]
  ask settlements [ set city-travel-cost (mean [travel-cost] of my-influence-patches)     ]
end

to Build-routes ;
  ask settlements [
    let start-rank rank
    set rank 4    set shape "mayahouse"
    if population >= rank-3-pop [  set rank 3  set shape "temple3"  ]
    if population >= rank-2-pop [  set rank 2  set shape "temple2"  ]
    if population >= rank-1-pop [  set rank 1  set shape "temple1"  ]
   if start-rank < rank [  if count my-links > 0 [ask one-of my-links [die]]]] ; lose a road if drop a rank

  ask settlements with [ (rank = 3 and count link-neighbors <= 1 )   ] [ ; #
    let others other settlements with [link-neighbor? myself = false and (sqrt area * (distance myself)) <= 31]
    ifelse count others > 0 [  create-link-with max-one-of others [population]   ][]  ]
  ask settlements with [ ( rank = 2 and count link-neighbors <= 2 )  ] [ ; #
    let others other settlements with [link-neighbor? myself = false and (sqrt area * (distance myself)) <= 31 * (rank-2-pop / rank-3-pop / 2 + 1) ]
    ifelse count others > 0 [  create-link-with max-one-of others [population]   ][]  ]
  ask settlements with [ ( rank = 1 and count link-neighbors <= 3 )  ] [ ; #
    let others other settlements with [link-neighbor? myself = false and (sqrt area * (distance myself)) <= 31 * (rank-1-pop / rank-3-pop / 2  + 1) ]
    ifelse count others > 0 [  create-link-with max-one-of others [population]   ][]  ]
end

to trading
  ask settlements [ set trade-strength 0 set centrality 0 set cluster-number 0 ]
  ask links [set trade-flow 0]
  set traders (settlements with [ count link-neighbors > 0 ])
  find-all-components
  while [count traders with [ cluster-number = 0] > 0] [
    ask traders with [ cluster-number = 0] [
      set cluster-number max [cluster-number] of link-neighbors
      ask link-neighbors [ set cluster-number max [cluster-number] of link-neighbors     ] ]  ]
  ask traders [
    set visited-nodes []
    set centrality 0
    ask searchers [ die ]
    set search-completed false
    set origin-city one-of settlements-here
    hatch-searchers 1  [
      set size 1
      set color red
      set visited-nodes fput  one-of settlements-here  visited-nodes
      set path-cost [city-travel-cost] of one-of settlements-here
      set location one-of settlements-here  ]
  loop [
    ask origin-city [set centrality centrality + 1]
    ask searchers  [
        expand-paths (searcher who);;;; fixed
      die ]
      ifelse any? searchers   [ ][  set search-completed true  ]
      if search-completed = true [ stop]]]
  ask settlements [ set trade-strength 0]
  let mean-city-travel-cost mean [city-travel-cost] of traders
  ask traders [
    set trade-strength   (  ((1 + (( cluster-number  * 1)    /   (  centrality * 1  ))) ^ 0.9 ) ) / 30 ;/  city-travel-cost ^ 0.5 / 3   ;#
    if trade-strength < 0 [ set trade-strength 0]
    if trade-strength > 1 [ set trade-strength 1]]
end

to find-all-components
  ask traders [ set explored? false set cluster-number 0 ]
  loop  [
    set network-start one-of traders with [ not explored? ]
    if network-start = nobody [ stop ]
    set component-size 0
    ask network-start [ explore (gray + 2) ] ]
end

to explore [new-color]
  if explored? [ stop ]
  set explored? true
  set component-size component-size + 1
  ask network-start [set cluster-number cluster-number + 1]
  ask link-neighbors [ explore new-color ]
end

;;;; start this is the problem part of the code here ;;;

to expand-paths [searcher-agent]
  foreach sort [out-link-neighbors with [count my-links >= 0]] of [location] of searcher-agent [expand-path searcher-agent location]

  ;foreach [location]  [expand-path search-agent]] sort [out-link-neighbors with [count my-links >= 0]]

end

to expand-path [searcher-agent node]
  if not search-completed   [
     if not member? node visited-nodes [
         set visited-nodes fput node visited-nodes
          if count searchers-here > 1 [die]
          hatch-searchers 1  [
           set size 1  set color red  set heading [heading] of searcher-agent  set visited-nodes [visited-nodes] of searcher-agent
            set path-cost [path-cost] of searcher-agent  set location node  move-to location  set path-cost path-cost + [city-travel-cost] of one-of settlements-here]]  ]
 end

;to expand-paths [searcher-agent]

 ; sort [searcher-agent]
  ; sort searcher-agent ; link-neighbors with [count my-links >= 0]]

;end

;to expand-path
;  let node []
;  ask searcher [
;  if not search-completed   [
;      if not member? node visited-nodes [
;          set visited-nodes fput node visited-nodes
;          if count searchers-here > 1 [die]
;;          hatch-searchers 1  [
;           set size 1  set color red  set heading [heading] of searcher-agent  set visited-nodes [visited-nodes] of searcher-agent
;            set path-cost [path-cost] of searcher-agent  set location node  move-to location  set path-cost path-cost + [city-travel-cost] of one-of settlements-here]]  ]]
;end


;;;; end this is the problem part of the code here ;;;


to recalc-gdp
  ask settlements [
    set ecoserv-benefit (mean [ecosystem-services-value] of my-influence-patches )
    set ecoserv-GDP ecoserv-benefit * ecoserv-value
    if trade [
      ifelse count my-links > 0 [
        set trade-benefit trade-strength * trade-value
        ask my-links [
          set trade-flow trade-flow + [trade-benefit] of myself
          set thickness ( trade-flow ) / 10000   ]   ][ ; was 8k
         set trade-benefit 0  ] ]
    set trade-GDP trade-benefit
    set yield-GDP settlement-yield * ag-value
    set gdp-per-cap   ( yield-GDP + trade-GDP + ecoserv-GDP )  / population    ]
end

;##############         INTERFACE         ##################         INTERFACE        ##################

to update-view
  ask patches [set plabel ""]
  if View =  "Soil Degradation" [ set mx 400  set mn -5  ask land-patches [ set pcolor scale-color red ag-impact mx mn ]]
  if View =  "Population Gradient" [ set mx 10  set mn 0  ask land-patches [ set pcolor scale-color blue pop-gradient  mx mn  ]]
  if View =  "Temperature" [ set mx 30  set mn 8  ask land-patches [ set pcolor scale-color blue temp  mx mn  ]]
  if View =  "Soil Productivity" [ set mx  10 set mn 0  ask land-patches [ set pcolor scale-color brown soil-prod  mx mn  ]]
  if View =  "Elevation" [ set mx 1500  set mn -200  ask land-patches [ set pcolor scale-color gray elevation  mx mn  ]]
  if View =  "Precipitation" [ set mx  3000 set mn 0  ask land-patches [ set pcolor scale-color blue rainfall  mx mn  ]]
  if View =  "Ecosystem Services" [ set mx  200 set mn 0  ask land-patches [ set pcolor scale-color green ecosystem-services-value  mx mn  ]]
  if View =  "Net Primary Productivity" [ set mx 3000  set mn -5  ask land-patches [ set pcolor scale-color green npp  mx mn  ]]
  if View =  "Agricultural Suitability" [ set mx  1000 set mn -5  ask land-patches [ set pcolor scale-color brown ag-suit  mx mn ]]
  if View =  "Benefit Cost of Agriculture" [ set mx  300 set mn  0 ask land-patches [ ifelse BCA-ag < 0 [set pcolor red + 2] [ set pcolor scale-color green BCA-ag  mx mn  ]]]
  if View =  "Water Flow" [ set mx  1.5 set mn  -0.15 ask land-patches [ set pcolor scale-color blue flow  mx mn  ]]
  if View =  "Slope" [ set mx  15  set mn  0 ask land-patches [ set pcolor scale-color gray slope  mx mn  ]]
  if View =  "Forest State" [ ask land-patches [ if forest-state = 1 [set pcolor yellow + 1]  if is-ag = 1 [set pcolor gray + 3.5]  if forest-state = 2 [set pcolor green + 2] if forest-state = 3 [set pcolor green - 0.5]]]
  if View =  "Blank" [ ask land-patches [ set pcolor white ]]
  if View =  "Travel Cost" [ set mx 60  set mn -10  ask land-patches [ set pcolor scale-color yellow travel-cost  mx mn ]]
  ;if View =  "Trade Strength" [ set mx 1  set mn 0  ask land-patches [ set pcolor white ]  foreach sort-by [[who] of ?1 > [who] of ?2] settlements [     ask ?[        ask my-influence-patches [set pcolor scale-color red [trade-strength] of myself mx mn ]] ]]  have to figure out previous ? list and what the question mark is poointing to
  if View =  "Imagery" [import-pcolors-rgb "Maya.png"]
  if legend-on [make-legend]
 ; if Influence-view[ if count settlements > 0  [   foreach sort-by [[who] of ?1 < [who] of ?2] settlements [     ask ?[        ask my-influence-patches [set pcolor gray + 1 ]]    ]] ] ; [color] of myself ;; have to figure out previous ? list and what the question mark is poointing to
  if Agric-view [ ask settlements [ ask my-ag-patches [   set pcolor grey + 1     ]]]
  ask links [ set color grey + 1   ]
  ask settlements [   set size log (population) 100 ]
end

;to make-movie
;  user-message "Enter name ending with .mov"  let path user-new-file  if not is-string? path [ stop ]
;  reset   movie-start path   while [  ticks <= 300 ] [   vid:start-recorder
;    run-model movie-grab-view ] movie-close
;end

to make-legend
  ask patch (max-pxcor * 0.95) (max-pycor * 0.96) [
    set pcolor [pcolor] of one-of land-patches  with-min[pcolor]
    ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself           ]]]]
    set plabel mx
    set plabel-color white ]
  ask patch (max-pxcor * 0.95) (max-pycor * 0.84) [
    set pcolor [pcolor] of one-of land-patches  with-max[pcolor]
    ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself           ]]]]
    set plabel mn
    set plabel-color black]
  ask patch (max-pxcor * 0.95) (max-pycor * 0.9) [
    set pcolor ([pcolor] of one-of land-patches  with-max [pcolor]  + [pcolor] of one-of land-patches  with-min[pcolor])  / 2
    ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself ask neighbors [ set pcolor [pcolor] of myself           ]]]]
    set plabel (mx + mn) / 2
    set plabel-color white]
end

;    MayaSim: An agent-based model of the ancient Maya social-ecological system.
;    Copyright (C) 2013  Scott Heckbert
;
;    scott.heckbert@gmail.com
;
;    This program is free software: you can redistribute it and/or modify
;    it under the terms of the GNU Affero General Public License as published by
;    the Free Software Foundation, version 3.
;
;    This program is distributed in the hope that it will be useful,
;    but WITHOUT ANY WARRANTY; without even the implied warranty of
;    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;    GNU Affero General Public License for more details.
@#$#@#$#@
GRAPHICS-WINDOW
403
10
1453
1144
-1
-1
2.6
1
10
1
1
1
0
0
0
1
-200
200
-216
216
0
0
1
ticks
30.0

BUTTON
28
49
95
92
START
startup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

CHOOSER
28
124
163
169
View
View
"Precipitation" "Temperature" "Net Primary Productivity" "Soil Productivity" "Elevation" "Slope" "Water Flow" "Forest State" "Agricultural Suitability" "Benefit Cost of Agriculture" "Soil Degradation" "Ecosystem Services" "Population Gradient" "Travel Cost" "Blank" "Imagery" "Trade Strength"
10

BUTTON
118
49
183
92
RUN
run-model
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
163
124
218
157
View
update-view
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
205
49
270
92
Reset
reset
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
147
887
259
920
max-yield
max-yield
0
3000
1100.0
50
1
NIL
HORIZONTAL

SLIDER
148
921
260
954
origin-shift
origin-shift
0
3
1.11
0.01
1
NIL
HORIZONTAL

SLIDER
148
954
260
987
slope-yield
slope-yield
-0.01
0
-0.0052
0.0001
1
NIL
HORIZONTAL

PLOT
1467
260
1798
467
Crop Yield
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"yield-crop1" 1.0 0 -10899396 true "" ""
"Yield" 1.0 0 -955883 true "" "plot  (sum  [settlement-yield] of settlements)/ 1000"
"Area Cropped" 1.0 0 -7500403 true "" "plot count patches with [is-ag = 1] / 2"

SLIDER
147
662
258
695
estab-cost
estab-cost
400
1200
900.0
10
1
NIL
HORIZONTAL

BUTTON
218
124
273
157
Movie
make-movie
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
26
855
119
888
Infitration
Infitration
0
2
0.0
0.2
1
NIL
HORIZONTAL

SLIDER
27
790
120
823
rain-steps
rain-steps
0
20
10.0
1
1
NIL
HORIZONTAL

SWITCH
30
303
165
336
Climate-Cycle
Climate-Cycle
0
1
-1000

PLOT
1467
721
1799
955
Natural Capital
NIL
NIL
0.0
10.0
540.0
1000.0
true
false
"" ""
PENS
"es" 1.0 0 -16777216 true "" "plot sum [ecosystem-services-value ] of patches with [is-land-patch = 1]"

SLIDER
287
852
395
885
crop-value-param
crop-value-param
0
0.3
0.06
0.01
1
NIL
HORIZONTAL

SLIDER
287
885
395
918
forest-value-param
forest-value-param
0
60
45.0
1
1
NIL
HORIZONTAL

SLIDER
26
822
119
855
precip-percent
precip-percent
0
1
0.25
0.05
1
NIL
HORIZONTAL

SLIDER
282
662
387
695
disturb-rate
disturb-rate
0
1
0.3
0.05
1
NIL
HORIZONTAL

SLIDER
283
696
387
729
state-change-s2
state-change-s2
0
150
40.0
5
1
NIL
HORIZONTAL

SLIDER
283
729
387
762
state-change-s3
state-change-s3
0
200
100.0
5
1
NIL
HORIZONTAL

PLOT
1806
954
2303
1159
Forest State
NIL
NIL
0.0
10.0
0.0
0.7
true
true
"" ""
PENS
"Cleared/Cropped    ." 1.0 0 -2674135 true "" "plot (count patches with [forest-state = 1] / (1 +  (count patches with [is-land-patch = 1])))"
"Regrowth" 1.0 0 -6459832 true "" "plot (count patches with [forest-state = 2] / (1 +   (count patches with [is-land-patch = 1])))"
"Climax Forest" 1.0 0 -14835848 true "" "plot (count patches with [forest-state = 3] / (1 +   (count patches with [is-land-patch = 1])))"

SLIDER
283
762
387
795
s3num-neigh
s3num-neigh
0
5
2.0
1
1
NIL
HORIZONTAL

SLIDER
27
665
131
698
rain-change
rain-change
-0.4
0.4
0.06
0.005
1
NIL
HORIZONTAL

SLIDER
26
698
129
731
Veg-Rainfall
Veg-Rainfall
0
50
0.0
1
1
NIL
HORIZONTAL

SLIDER
24
447
129
480
num-cities
num-cities
0
250
135.0
5
1
NIL
HORIZONTAL

SLIDER
148
696
258
729
ag-travel-cost
ag-travel-cost
0
2000
950.0
50
1
NIL
HORIZONTAL

SWITCH
197
384
290
417
migration
migration
0
1
-1000

PLOT
1467
467
1799
721
Net Primary Productivity
NIL
NIL
0.0
10.0
1600.0
1900.0
true
false
"" ""
PENS
"NPP" 1.0 0 -10899396 true "" "plot sum [npp ] of  patches with [is-land-patch = 1] / (1 + count patches with [is-land-patch = 1] )"

PLOT
1466
13
1797
259
Population
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
"Population" 1.0 0 -16777216 true "" "plot sum [population] of turtles"

PLOT
1806
467
2304
721
Settlements [Log 2]
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Rank 1                   ." 1.0 0 -7858858 true "" "plot log (1 + count settlements with [rank = 1])2"
"Rank 2   " 1.0 0 -14070903 true "" "plot  log (1 + count settlements with [rank = 2]) 2"
"Rank 3" 1.0 0 -16777216 true "" "plot log (1 + count settlements with [rank = 3] ) 2"
"Rank 4" 1.0 0 -7500403 true "" "plot log (1 + count settlements with [rank = 4] )2"
"Failed" 1.0 0 -2674135 true "" "plot  log (1 + failed-cities) 2"

PLOT
1806
721
2304
954
Cropping
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Abandoned             ." 1.0 0 -2674135 true "" "plot abandoned-crops"
"Sown" 1.0 0 -14835848 true "" "plot new-crops"

SLIDER
148
795
258
828
ag-suit-soils
ag-suit-soils
0
120
84.0
2
1
NIL
HORIZONTAL

SLIDER
148
729
258
762
ag-suit-npp
ag-suit-npp
0
0.4
0.14
0.01
1
NIL
HORIZONTAL

SLIDER
149
763
259
796
ag-suit-slope
ag-suit-slope
0
30
18.0
2
1
NIL
HORIZONTAL

SWITCH
30
336
165
369
Climate-Change
Climate-Change
0
1
-1000

SLIDER
147
447
240
480
TC-pref
TC-pref
-0.8
0
-0.1
0.01
1
NIL
HORIZONTAL

SLIDER
148
481
241
514
ES-pref
ES-pref
0
1
0.3
0.1
1
NIL
HORIZONTAL

SWITCH
292
384
382
417
trade
trade
0
1
-1000

SWITCH
30
270
125
303
Humans
Humans
1
1
-1000

SLIDER
262
447
393
480
trade-value
trade-value
0
15000
6000.0
100
1
NIL
HORIZONTAL

SWITCH
29
203
124
236
Nature
Nature
0
1
-1000

SLIDER
147
534
242
567
flow-TC
flow-TC
0
50
30.0
5
1
NIL
HORIZONTAL

SLIDER
25
564
130
597
rank-3-pop
rank-3-pop
1500
5000
4000.0
50
1
NIL
HORIZONTAL

SLIDER
25
531
130
564
rank-2-pop
rank-2-pop
0
10000
7000.0
250
1
NIL
HORIZONTAL

SLIDER
24
497
129
530
rank-1-pop
rank-1-pop
0
20000
9500.0
500
1
NIL
HORIZONTAL

PLOT
1806
260
2304
468
Trade Links
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Number Links" 1.0 0 -16777216 true "" "plot count links"
"Mean Cluster Size x 2" 1.0 0 -5298144 true "" "plot 2 * sum [cluster-number] of turtles / (count  turtles with [cluster-number > 0] + 1)"

PLOT
1805
13
2302
259
Real Income
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total Real Income" 1.0 0 -16777216 true "" "plot sum [ecoserv-GDP] of settlements + sum [trade-GDP] of settlements + sum [yield-GDP] of settlements"
"Ecosystem Services" 1.0 0 -10899396 true "" "plot sum [ecoserv-GDP] of settlements"
"Trade" 1.0 0 -2674135 true "" "plot sum [trade-GDP] of settlements"
"Agriculture" 1.0 0 -6459832 true "" "plot sum [yield-GDP] of settlements"

SLIDER
263
481
394
514
ecoserv-value
ecoserv-value
0
20
10.0
1
1
NIL
HORIZONTAL

SLIDER
263
514
394
547
ag-value
ag-value
0
2
1.1
0.1
1
NIL
HORIZONTAL

SWITCH
242
337
360
370
Agric-view
Agric-view
1
1
-1000

SLIDER
148
829
258
862
ag-suit-flow
ag-suit-flow
0
800
400.0
50
1
NIL
HORIZONTAL

SLIDER
22
907
115
940
soil-deg-rate
soil-deg-rate
0
8
5.0
0.05
1
NIL
HORIZONTAL

SLIDER
26
731
129
764
Climate-Var
Climate-Var
0
15
3.0
1
1
NIL
HORIZONTAL

SLIDER
22
941
116
974
soil-regen-rate
soil-regen-rate
0
8
2.5
0.05
1
NIL
HORIZONTAL

PLOT
1467
955
1799
1160
Soil Degradation
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
"ag-impact" 1.0 0 -16777216 true "" "plot sum [ag-impact] of  patches with [is-land-patch = 1]"

SWITCH
242
304
360
337
Influence-view
Influence-view
1
1
-1000

SWITCH
30
237
125
270
Raining
Raining
0
1
-1000

TEXTBOX
27
384
193
417
Anthropogenic
24
0.0
1

TEXTBOX
24
607
164
646
Biophysical
24
0.0
1

SLIDER
287
918
395
951
flow-value-param
flow-value-param
0
200
40.0
10
1
NIL
HORIZONTAL

TEXTBOX
27
642
70
660
Climate
11
0.0
1

TEXTBOX
24
889
53
908
Soils
11
0.0
1

TEXTBOX
284
642
331
660
Forests
11
0.0
1

TEXTBOX
147
642
214
660
Agriculture
11
0.0
1

TEXTBOX
287
832
406
852
Ecosystem Services
11
0.0
1

TEXTBOX
25
773
67
791
Water
11
0.0
1

TEXTBOX
147
519
214
537
Travel Cost
11
0.0
1

TEXTBOX
28
13
225
50
Model Settings
24
0.0
1

TEXTBOX
262
427
349
446
Real Income
11
0.0
1

TEXTBOX
152
427
211
446
Migration
11
0.0
1

MONITOR
285
49
350
94
Cell Area
precision (area) 2
17
1
11

SLIDER
148
568
243
601
slope-TC
slope-TC
0
2
1.1
0.1
1
NIL
HORIZONTAL

BUTTON
170
337
234
371
Rain
climate-scenario\nrain\ncalc-npp\nupdate-view
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
169
302
233
336
Forest
forest-succession\ncalc-ecosystem-services\nupdate-view
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
169
234
233
268
Yield
calc-crop-yield
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
169
268
233
302
Agric
calc-BCA-Ag\nupdate-view
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

TEXTBOX
149
872
209
890
Crop Yield
11
0.0
1

TEXTBOX
27
427
95
445
Settlements
11
0.0
1

TEXTBOX
28
103
251
121
Select and update spatial view
11
0.0
1

TEXTBOX
29
183
252
201
Turn on / off model functions
11
0.0
1

SWITCH
273
124
382
157
legend-on
legend-on
0
1
-1000

TEXTBOX
170
215
259
233
Run sub-models
11
0.0
1

SWITCH
260
560
396
593
population-control
population-control
1
1
-1000

@#$#@#$#@
## WHAT IS IT?

Heckbert, S., Isendahl, C., Gunn, J., Brewer, S., Scarborough, V., Chase, A.F.,  Chase, D.Z., Costanza, R., Dunning, N., Beach, T., Luzzadder-Beach, S., Lentz, D., Sinclair, P.. (2013). Growing the ancient Maya social-ecological system from the bottom up. In: Isendahl, C., and Stump, D. (eds.), Applied Archaeology, Historical Ecology and the Useable Past. Oxford University Press.

Heckbert, S. (in press) MayaSim: An Agent-Based Model of the Ancient Maya Social-Ecological System. Journal of Artificial Societies and Social Simulation.   


MayaSim is an agent-based, cellular automata and network model, representing settlements and geography of the ancient Maya civilisation. Biophysical processes include climate variation, hydrology, primary productivity, forest succession, soil degradation, and ecosystem service provision. Anthropogenic processes include agriculture, harvesting timber, degrading other ecosystem services, demographics, and trade. The model is meant to represent a simplification of the historical timeline of the ancient Maya civilisation.

One of the projects of the Integrated History and future of People on Earth (IHOPE) initiative (van der Leeuw et al. 2012; Costanza et al. 2012) is developing a simulation model of the ancient Maya civilisation (Heckbert et al. in press; Heckbert 2013).  This model can be used to test hypotheses of societal development, resilience and social-ecological vulnerabilities. The MayaSim model is presented as one possible set of assumptions and hypotheses about how the ancient Maya social-ecological system (SES) might have functioned. The model, like all models, is a simplified representation of the Maya system, and consists of mathematical functions that describe how different aspects of the social-ecological system change over time and in space.  A set of mathematical functions which describe anthropogenic and biophysical processes include parameters which determine how these functions behave. We tested the model by altering parameters, and observing a range of model outputs that could be compared with historical data. In other words, the model can tell us what range of values lead to observed historical patterns. We can then change these settings and see what interventions might have allowed the Maya to survive their crises. 

MayaSim is an integrated model that represents individual settlements as “agents” located in a landscape represented as a grid of cells.  Settlements establish trade with neighbouring settlements, allowing trading networks to emerge. Agents, cells, and networks are programmed to represent elements of the historical Maya civilisation, including demographics, trade, agriculture, soil degradation, provision of ecosystem services, climate variability, hydrology, primary productivity, and forest succession. Simulating these in combination allows patterns to emerge at the landscape level, effectively growing the social-ecological system from the bottom up.  This approach constructs an artificial social-ecological laboratory where different theories can be tested and hypotheses proposed for how the system will perform under different configurations. The MayaSim model is able to reproduce spatial patterns and timelines that mimic relatively well what we know about the ancient Maya’s history. 

The model is constructed using the software Netlogo (Wilenski 1999). The software interface presents the spatial view of the model with graphs tracking model output and a user interface for interacting with the model. The view can be changed to visually observe different spatial data and output layers within the model such as the topography, precipitation, soils, population density, forest condition, and so on. The model operates at a spatial extent of 516,484 km2 with a 5 km2 cell resolution. Imported spatial data include elevation and slope (Farr et al. 2007), soil productivity (FAO 2007), temperature, and precipitation (Hijmans et al. 2005). 

The baseline case is the model configuration that best represents the historical ‘life cycle’ as we understand it for the ancient Maya.  Specifically we adjusted the model parameters to give us results that mimicked as closely as possible the development of and transition between the Maya Preclassic, Classic and Postclassic periods. This baseline scenario is presented in Figure 1, showing spatial outcomes for four indicators, at 80 time step intervals. Each time step represents approximately 10 years. Population density, forest condition, settlement ‘trade strength’, and soil degradation each contain a narrative describing the development and reorganisation of the simulated social-ecological system. 


## HOW IT WORKS

Please see referenced publications and tutorial video. Please contact scott.heckbert@gmail.com for any comments or inquiries.

## HOW TO USE IT

The model automatically loads a series of GIS based raster datasets, which may take one or two minutes. Press Ctrl- to reduce the font in order to view the entire interface. Simulation runs take approximately 1 hour for 250 time steps. Disable 'raining' to run the model faster. Disable 'humans' to examine only 'nature' processes, and vice versa. 

## THINGS TO NOTICE

The model is sensitive to parameter levels. Change the slider variables to examine the effect on the sustainability of the ancient Maya social-ecological system.  
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

chess bishop
false
0
Circle -7500403 true true 135 35 30
Circle -16777216 false false 135 35 30
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 165 180 165 195 255
Polygon -16777216 false false 105 255 120 165 180 165 195 255
Rectangle -7500403 true true 105 165 195 150
Rectangle -16777216 false false 105 150 195 165
Line -16777216 false 137 59 162 59
Polygon -7500403 true true 135 60 120 75 120 105 120 120 105 120 105 90 90 105 90 120 90 135 105 150 195 150 210 135 210 120 210 105 195 90 165 60
Polygon -16777216 false false 135 60 120 75 120 120 105 120 105 90 90 105 90 135 105 150 195 150 210 135 210 105 165 60

chess king
false
0
Polygon -7500403 true true 105 255 120 90 180 90 195 255
Polygon -16777216 false false 105 255 120 90 180 90 195 255
Polygon -7500403 true true 120 85 105 40 195 40 180 85
Polygon -16777216 false false 119 85 104 40 194 40 179 85
Rectangle -7500403 true true 105 105 195 75
Rectangle -16777216 false false 105 75 195 105
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Rectangle -7500403 true true 165 23 134 13
Rectangle -7500403 true true 144 0 154 44
Polygon -16777216 false false 153 0 144 0 144 13 133 13 133 22 144 22 144 41 154 41 154 22 165 22 165 12 153 12

chess pawn
false
0
Circle -7500403 true true 105 65 90
Circle -16777216 false false 105 65 90
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 165 180 165 195 255
Polygon -16777216 false false 105 255 120 165 180 165 195 255
Rectangle -7500403 true true 105 165 195 150
Rectangle -16777216 false false 105 150 195 165

chess queen
false
0
Circle -7500403 true true 140 11 20
Circle -16777216 false false 139 11 20
Circle -7500403 true true 120 22 60
Circle -16777216 false false 119 20 60
Rectangle -7500403 true true 90 255 210 300
Line -16777216 false 75 255 225 255
Rectangle -16777216 false false 90 255 210 300
Polygon -7500403 true true 105 255 120 90 180 90 195 255
Polygon -16777216 false false 105 255 120 90 180 90 195 255
Rectangle -7500403 true true 105 105 195 75
Rectangle -16777216 false false 105 75 195 105
Polygon -7500403 true true 120 75 105 45 195 45 180 75
Polygon -16777216 false false 120 75 105 45 195 45 180 75
Circle -7500403 true true 180 35 20
Circle -16777216 false false 180 35 20
Circle -7500403 true true 140 35 20
Circle -16777216 false false 140 35 20
Circle -7500403 true true 100 35 20
Circle -16777216 false false 99 35 20
Line -16777216 false 105 90 195 90

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

dot
false
0
Circle -7500403 true true 90 90 120

emblem
false
0
Polygon -7500403 true true 300 210 285 180 15 180 0 210
Polygon -7500403 true true 270 165 255 135 45 135 30 165
Polygon -7500403 true true 240 120 225 90 75 90 60 120
Polygon -7500403 true true 150 15 285 255 15 255
Polygon -16777216 true false 225 225 150 90 75 225

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

house two story
false
0
Polygon -7500403 true true 2 180 227 180 152 150 32 150
Rectangle -7500403 true true 270 75 285 255
Rectangle -7500403 true true 75 135 270 255
Rectangle -16777216 true false 124 195 187 256
Rectangle -16777216 true false 210 195 255 240
Rectangle -16777216 true false 90 150 135 180
Rectangle -16777216 true false 210 150 255 180
Line -16777216 false 270 135 270 255
Rectangle -7500403 true true 15 180 75 255
Polygon -7500403 true true 60 135 285 135 240 90 105 90
Line -16777216 false 75 135 75 180
Rectangle -16777216 true false 30 195 93 240
Line -16777216 false 60 135 285 135
Line -16777216 false 255 105 285 135
Line -16777216 false 0 180 75 180
Line -7500403 true 60 195 60 240
Line -7500403 true 154 195 154 255

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

mayahouse
false
0
Rectangle -7500403 true true 105 165 195 195
Polygon -7500403 true true 60 225 75 195 225 195 240 225
Polygon -7500403 true true 105 165 150 150 195 165
Polygon -16777216 true false 120 172 180 172 180 195 120 195
Line -16777216 false 90 210 210 210
Line -16777216 false 90 217 210 217

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

sailboat side
false
0
Line -16777216 false 0 240 120 210
Polygon -7500403 true true 0 239 270 254 270 269 240 284 225 299 60 299 15 254
Polygon -1 true false 15 240 30 195 75 120 105 90 105 225
Polygon -1 true false 135 75 165 180 150 240 255 240 285 225 255 150 210 105
Line -16777216 false 105 90 120 60
Line -16777216 false 120 45 120 240
Line -16777216 false 150 240 120 240
Line -16777216 false 135 75 120 60
Polygon -7500403 true true 120 60 75 45 120 30
Polygon -16777216 false false 105 90 75 120 30 195 15 240 105 225
Polygon -16777216 false false 135 75 165 180 150 240 255 240 285 225 255 150 210 105
Polygon -16777216 false false 0 239 60 299 225 299 240 284 270 269 270 254

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

temple1
false
0
Circle -1184463 true false 88 -32 122
Polygon -7500403 true true 0 300 31 241 46 241 61 181 76 181 91 121 106 121 121 61 181 61 196 121 211 121 226 181 241 181 256 241 271 241 300 300 0 300
Rectangle -7500403 true true 120 30 180 60
Rectangle -7500403 true true 135 15 165 30
Rectangle -11221820 true false 135 45 165 90
Polygon -16777216 false false 135 75 165 75 165 90 135 90 135 105 165 105 165 120 135 120 135 135 165 135 165 150 135 150 135 165 165 165 165 180 135 180 135 195
Polygon -16777216 false false 165 240 165 195 165 210 135 210 135 225 165 225 165 240 135 240 135 75 165 75
Polygon -16777216 false false 135 210 165 210 165 195 135 195
Polygon -16777216 false false 135 240 135 255 165 255 165 270 135 270 135 285 165 285 165 300 135 300
Line -16777216 false 165 240 165 300
Polygon -16777216 false false 129 75 170 75 178 299 120 299

temple2
false
0
Polygon -7500403 true true 30 255 45 195 60 195 75 135 90 135 105 75 120 75 165 75 180 75 195 135 210 135 225 195 240 195 255 255 45 255
Rectangle -7500403 true true 120 45 165 75
Rectangle -7500403 true true 128 30 158 45
Rectangle -11221820 true false 135 60 150 75
Polygon -16777216 false false 115 75 169 75 178 239 107 239
Polygon -16777216 false false 120 90 165 90 165 105 120 105 120 120 165 120 165 135 120 135 120 150 165 150 165 165 120 165 120 180 165 180 165 195 120 195 120 210 165 210 165 225 120 225 120 240 165 240 165 90 120 90 120 240

temple3
false
0
Polygon -7500403 true true 15 210 45 165 60 165 75 135 90 135 105 105 195 105 210 135 225 135 240 165 255 165 285 210
Rectangle -7500403 true true 120 75 180 105
Rectangle -13840069 true false 135 90 165 105
Polygon -16777216 false false 135 105 165 105 165 120 135 120 135 135 165 135 165 150 135 150 135 165 165 165 165 180 135 180 135 195 165 195 165 210 135 210 135 105 165 105 165 210 135 210
Polygon -16777216 false false 132 105 168 105 175 209 124 209

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.3.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="experiment" repetitions="1" runMetricsEveryStep="true">
    <setup>startup</setup>
    <go>run-model</go>
    <metric>sum [population] of turtles</metric>
    <enumeratedValueSet variable="Climate-Cycle">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Infitration">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="estab-cost">
      <value value="900"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Humans">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="View">
      <value value="&quot;Soil Degradation&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="migration">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Nature">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flow-value-param">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="crop-value-param">
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Agric-view">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Climate-Var">
      <value value="3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="state-change-s2">
      <value value="40"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trade">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="state-change-s3">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rank-3-pop">
      <value value="4000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Raining">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="flow-TC">
      <value value="30"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rank-1-pop">
      <value value="9500"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="legend-on">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-suit-flow">
      <value value="400"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="precip-percent">
      <value value="0.25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="disturb-rate">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="origin-shift">
      <value value="1.11"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Veg-Rainfall">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="forest-value-param">
      <value value="45"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="s3num-neigh">
      <value value="2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Climate-Change">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Influence-view">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-suit-npp">
      <value value="0.14"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slope-yield">
      <value value="-0.0052"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ES-pref">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rain-steps">
      <value value="10"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="slope-TC">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rain-change">
      <value value="0.06"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-suit-soils">
      <value value="84"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-suit-slope">
      <value value="18"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="TC-pref">
      <value value="-0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-yield">
      <value value="1100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="population-control">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-value">
      <value value="1.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="soil-deg-rate">
      <value value="5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="rank-2-pop">
      <value value="7000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ag-travel-cost">
      <value value="950"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="num-cities">
      <value value="135"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="trade-value">
      <value value="6000"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="soil-regen-rate">
      <value value="2.5"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="ecoserv-value">
      <value value="10"/>
    </enumeratedValueSet>
  </experiment>
</experiments>
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

try
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
Rectangle -7500403 false true 90 90 255 150
Polygon -7500403 false true 75 75 105 135 165 180 195 135 165 90 120 90 105 120 120 150 150 180 195 225 225 195 210 135 180 90 135 105 75 90 75 75
Rectangle -2674135 true false 90 90 120 150
Circle -13840069 false false 75 30 60
@#$#@#$#@
0
@#$#@#$#@
