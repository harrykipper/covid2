__includes ["DiseaseConfig.nls" "output.nls" "SocialNetwork.nls"
  "layout.nls" "scotland.nls" "work_distribution.nls" "vaccine.nls"]

extensions [csv table]

undirected-link-breed [households household]
undirected-link-breed [relations relation]      ;; Relatives who don't live in the same household
undirected-link-breed [friendships friendship]
undirected-link-breed [tracings tracing]        ;; The contact tracing app
undirected-link-breed [wps wp]        ;; workplaces

globals
[
  rnd                  ;; Random seed

  b
  c
  fq

  use-existing-nw?
  show-layout

  testing-today
  testing-tomorrow

  interval
  intervalReduction            ; reduction of vaccine efficacy as consequence of shorter interval b/w doses
  ;; Behaviour
  compliance-adjustment
  high-prob-isolating
  low-prob-isolating

  ;; Counters
  N-people
  vaccinatedToday
  tests-remaining
  tests-per-day
  tests-performed
  tests-today
  hospital-beds        ;; Number of places in the hospital (currently unused)
  counters             ;; Table containing information on source of infection e.g household, friends...
  populations          ;;
  cumulatives          ;; table of cumulative disease states
  infections           ;; table containing the average number of infections of people recovered or dead in the past week
  all-infections
  placecnt             ;;table of size of neigh and prop of young
  cum-infected
  workplaces                 ;;table of agents by work-id
  transEff
  symptEff
  severeEff

  ;; Reproduction rate
  beta-n               ;; The average number of new secondary infections per infected this tick
  gamma                ;; The average number of new recoveries per infected this tick
  s0                   ;; Initial number of susceptibles
  r0                   ;; The number of secondary infections that arise due to a single infective introduced in a wholly susceptible population
  k0                   ;; K value: clustering of spreading events (variance to mean)

  rtime
  nb-infected          ;; Number of secondary infections caused by an infected person at the end of the tick
  nb-infected-previous
  nb-recovered         ;; Number of recovered people at the end of the tick

  vaccinations         ;; table with initial no. of vaccinated by age by sex
  ;; Interventions

  contact-tracing      ;; If true a contact tracing app exists
  app-initalize?       ;; If the app was distributed to agents
  daily-vaccinations
  have-vaccinations
  wantvax

  howmanyrnd           ;; Number of random people we meet
  howmanyelder         ;; Number of random people (> 67 y.o.) we meet

  ;; agent-sets
  seniors
  schoolkids
  adults
  working-age-agents
  workers              ;;people working in "offices"
  crowd-workers        ;; people working with crowd

  school               ;; Table of classes and pupils
  place                ;; Table of neighbourhoods and their residents             ;;
  work-place           ;list of work place size
  double-t
  flu-symp            ;;number of agents with flu-symptomas that will try to get tested for covid19
  ratio-flu-covid    ;; ration between covid and flu

  tested-positive    ;;number of agents tested as positive

  wardmap              ;; pcode - ward lookup table
]

turtles-own
[
  sex
  age
  age-discount
  gender-discount
  status               ;; Marital status 0 = single 1 = married 2 = divorced 3 = widowed
  novax

  infected             ;; 0 = not infected; n = infecting variant: 1 = base; 2 = beta; 3 = delta
  vaxed                ;; 0 = not vaccinated; 1 = first dose; 2 = second dose
  days-since-dose
  symptomatic?         ;; If true, the person is showing symptoms of infection
  severe-symptoms?     ;; If true, the person is showing severe symptoms
  cured                ;; 0 = never infected, n = variant the agent was infected with
  days-since-cured     ;; for 12 months :-)

  isolated?            ;; If true, the person is isolated at home, unable to infect friends and passer-bys.
  days-isolated        ;; Number of days the agent has spent in self-isolation
  hospitalized?        ;; If true, the person is hospitalized.

  infected-by          ;; Agent who infected me
  spreading-to         ;; Number of agents infected by me

  chance-of-infecting  ;; Probability that the person (when infective) will infect someone he comes close with

  myState             ;;describe the disease state of the agent: "incubation" "asymptomatic" "symptomatic" "severe" "in-hospital" "recovered" "dead"
  state-counter        ;;how long in this disease state
  t-incubation         ;;length of incubatiom
  t-asymptomatic       ;;length of asymtomatic
  t-symptomatic         ;;length of symptomatic
  t-severe             ;;duration untill severe is addmited to hospital
  t-hospital           ;;duration in hospital untill death or recovery
  t-infectious         ;; time in which agent become infectiuos
  t-stopinfecting      ;;time when agent stop infecting

  prob-symptoms        ;; Probability that the person is symptomatic
  isolation-tendency   ;; Chance the person will self-quarantine when symptomatic.
  testing-urgency      ;; When the person will seek to get tested after the onset of symptoms
  probability-of-dying
  probability-of-worsening

  susceptible?         ;; Tracks whether the person was initially susceptible

  ;; Agentsets
  friends
  relatives
  hh                   ;; household
  wide-colleagues
  close-colleagues
  myclass              ;; name of the pupil's class
  my-work              ;;identifier of work site, where  0- is not working
  my-work-sub          ;;identifier of sub work group
  out-grp              ;; instrumental variable to produce workgroups quickly

  office-worker?
  crowd-worker?        ;; if the worker works with crowd
  has-app?             ;; If true the agent carries the contact-tracing app
  tested-today?
  aware?

  neigh
  ward
  hhtype

  days_cont           ;;days of contacts since being infected
  nm_contacts         ;;number of contacts the agents had
]

friendships-own [mean-age]
households-own [ltype]  ; ltype 0 is a spouse; ltype 1 is offspring/sibling
wps-own [wp-id wtype]

tracings-own [day]   ;; links representing the contacts traced by the app

;; ===========================================================================
;;;
;;; SETUP
;;;
;; ==========================================================================

to setup
  ;if new-strain and not useful-run [stop]
  set rnd ifelse-value use-seed? [-1114321144][new-seed]
  random-seed rnd
  ;show rnd ;if behaviorspace-run-number = 0 [output-print (word  "Random seed: " rnd)]

  clear-all

  set show-layout false
  set use-existing-nw? true

;  if impossible-run [
;    reset-ticks
;    stop
;  ]

  set-default-shape turtles "circle"

  set have-vaccinations false
  if vaccination-capacity > 0 [set have-vaccinations true]
  ifelse social-distancing? [setSocialDistancing "sd"][setSocialDistancing "no"]

  set app-initalize? false

  read-wards

  ifelse use-existing-nw? [read-agents-sco][create-agents-sco]

  set N-people count turtles
  set-initial-variables

  ifelse use-existing-nw?
  [import-network]
  [
    create-hh-sco
    ask seniors [create-relations]
    create-friendships2
    remove-excess
  ]

  if schools-open? ;[foreach table:keys place [ngh -> create-schools-sco ngh]]
  [foreach remove-duplicates table:values wardmap [ngh -> create-schools-sco ngh]]

  ask turtles [
    reset-variables
    assign-disease-par
  ]

  if show-layout [
    resize-nodes
    repeat 50 [layout]
  ]

  reset-ticks

  populate-vaccination-table
  initialize-infections
  initialise-vaccinations

  set wantvax turtles with [age >= 12 and novax = false]
  set daily-vaccinations vaccination-capacity ;round (N-People * 0.007)
  set interval (dose-interval * 7) + 2

  ifelse use-existing-nw?
      [read-workplaces]
      [create-workplaces]

  set s0 table:get populations "susceptible"
  if behaviorspace-run-number = 0 [

    output-print (word count turtles with [infected > 0]  " agents currently infected " "(" precision (100 * count turtles with [infected > 0] / N-people) 2 "%); "
      count turtles with [cured > 0] " already recovered from the virus (" precision (100 * count turtles with [cured > 0] / N-people) 2 "%)")
    output-print (word count turtles with [vaxed = 1] " agents with ONE vaccine dose; " count turtles with [vaxed = 2] " with TWO doses; " count turtles with [vaxed = 3] " with booster")
    let school-state "open"
    let sd-state "people practice social distancing"
    if schools-open? = false [set school-state "closed"]
    if social-distancing? = false [set sd-state "people do not practice social distancing"]
    output-print  (word "The schools are " school-state ", " sd-state)

    plot-friends
    plot-age
    ;plot-worksites
    set infections table:make
  ]
end

to setSocialDistancing [case]
  (ifelse case = "sd" [ ;; Social distancing
    set b 0.7       ;; reduction factor in probability of infection
    set fq 1        ;; discount in frequency of work/school. Value subtracted from 5 days/week
    set c 0.7       ;; reduction factor in contacts around at work/school/street
    set social-distancing? true
    ]
    case = "ld" [  ; Lockdown
      set b 0.4
      set fq 4
      set c 0.2
    ]
    [ ;; No social distancing
      set b 1
      set fq 0
      set c 1
      set social-distancing? false
    ]
  )
end

to read-wards
  set wardmap table:make
  foreach csv:from-file "Glasgow_wards_lookup.csv" [w ->
    table:put wardmap item 0 w item 1 w
  ]
end

to set-initial-variables
  set intervalReduction setIntervalReduction
  set compliance-adjustment ifelse-value app-compliance = "High" [0.9][0.5]
  ;;initially we start the expirement with no app-----------------------
  ;;ifelse pct-with-tracing-app > 0 [set contact-tracing true][]
  set contact-tracing false
  set high-prob-isolating ["symptomatic-individual" "household-of-symptomatic" "household-of-positive" "relation-of-symptomatic" "relation-of-positive" ]
  set low-prob-isolating ["app-contact-of-symptomatic" "app-contact-of-positive"]

  set counters table:from-list (list ["household" 0]["relations" 0]["friends" 0]["school" 0]["random" 0]["work" 0])
  set populations table:from-list (list ["susceptible" 0]["infected" 0]["recovered" 0]["isolated" 0]["dead" 0]["in-hospital" 0]["incubation" 0]["symptomatic" 0]["asymptomatic" 0]["severe" 0])
  set cumulatives table:from-list (list ["incubation" 0] ["asymptomatic" 0] ["symptomatic" 0] ["severe" 0 ] ["in-hospital" 0]["recovered" 0 ]["dead" 0])
  table:put populations "susceptible" N-people

  ;; initally there will be no tests------------------------------
  ;;set tests-per-day round ((tests-per-100-people / 100) * N-People / 7)
  set tests-per-day 0
  set tests-remaining tests-per-day
  set tests-performed 0
  set flu-symp (0.035 / 7) * N-people * 0.3 ;;3.5% of pop have flu on any given week, for daily we divide by 7, 30% will have cough or fever or sore throat and get tested
  set tested-positive 0
  ;; initially we don't distribute an app
  ;;let adults turtles with [age > 14]
  ;;ask n-of (round count adults * (pct-with-tracing-app / 100)) adults [set has-app? true]

  set all-infections []

  set testing-today []
  set testing-tomorrow []
end

to initialize-infections
  ask n-of (round (N-people / 100) * initially-infected) turtles [

    ; 1/3 incubating, 1/3 symptomatic 1/3 a-symptomatic
    ifelse random-float 1 < 0.33 [change-state "incubation"][
      ifelse random-float 1 < 0.5 [change-state "asymptomatic"][change-state "symptomatic"]
    ]
    ; All infected are in incubation phase
    ;change-state "incubation"

    table:put populations "infected" (table:get populations "infected" + 1)
    set susceptible? false

    ; Base variant only
    ; set infected 1

    ; Three variants
    ;ifelse random-float 1 > 0.25 [set infected 2]
    ;[ifelse random-float 1 > 0.15 [set infected 1][set infected 3]]


    if Delta_variant = true ;; 15% Kent 85% Delta
      [ifelse random-float 1 < 0.15 [set infected 2][set infected 3]]
    if Delta_variant = "incipient" ;; 85% Kent 15% Delta
      [ifelse random-float 1 < 0.15 [set infected 3][set infected 2]]
    if Delta_variant = false ;; 85% Kent 15% Original
      [ifelse random-float 1 < 0.15 [set infected 1][set infected 2]]

  ]

  let circulating remove-duplicates [infected] of turtles with [infected > 0]
  ask n-of (round (N-people / 100) * initially-cured) turtles with [infected = 0] [
    change-state "recovered"
    set cured one-of circulating
    set days-since-cured random (immunityLasts * 30)
    set susceptible? false
  ]
end

to initialise-vaccinations
  ifelse have-vaccinations [vaccinate-initial-people][ask turtles [set vaxed 0]]
  ; ask up-to-n-of (round (N-people / 100) * initially-vaccinated) turtles with [age > 18 and novax = false] [
   ; ifelse age >= 49 [set vaxed 2][
   ;   ifelse random-float 1 >= 0.25 [set vaxed 1][set vaxed 2]
   ;   set days-since-dose random (dose-interval * 7)
   ; ]
  ;]
end


to initial-app
  set contact-tracing ifelse-value pct-with-tracing-app > 0 [true][false]
  set tests-per-day round ((tests-per-100-people / 100) * N-People / 7)
  ask n-of (round count adults * (pct-with-tracing-app / 100)) adults [set has-app? true]
end

to reset-variables
  set state-counter 0
  set myState "susceptible"
  set days-since-cured 0
  set has-app? false
  set cured 0
  set isolated? false
  set hospitalized? false
  set infected 0
  set vaxed 0
  set novax false
  set susceptible? true
  set symptomatic? false
  set severe-symptoms? false
  set aware? false
  set spreading-to 0
  set infected-by nobody
  set office-worker? false
  set crowd-worker? false
  ifelse age <= 15 [set age-discount 0.5][set age-discount 1]
  ifelse sex = "F" [set gender-discount 0.8] [set gender-discount 1]
  set days_cont 0
  set nm_contacts 0
end

;=====================================================================================

to go
  ; if new-strain and not useful-run [stop]
  ; if ticks = 0 and impossible-run [stop]

  if table:get populations "infected" = 0 [
    print-final-summary
    stop
  ]

  clear-count

  ;; initial the app once 5% of the population are cured
  if app-initalize? = false [
    if table:get populations "recovered" / N-people > 0.05 [
      initial-app
      set app-initalize? true
    ]
  ]

  ; New tests are available every day
  set tests-remaining tests-remaining + tests-per-day
  set daily-vaccinations vaccination-capacity

  ; vaccinate some people every day
  update-vaccinations

  ask turtles [set tested-today? false]

  ; The contact tracing app keeps memory of contacts for 10 days
  if contact-tracing [
    ask tracings [
      set day day + 1
      if day > 10 [die]
    ]
  ]

  ask turtles with [isolated?] [
    set days-isolated days-isolated + 1
    if ((symptomatic? = false) and (days-isolated = 10)) [unisolate]
  ]

  ask turtles with [cured > 0] [
    set days-since-cured days-since-cured + 1
    if days-since-cured > immunityLasts * 30 [set cured 0]
  ]

  let symp-covid turtles with [infected > 0 and (not hospitalized?) and
    (member? myState ["symptomatic" "severe"]) and
    (should-test?) and
    (state-counter = testing-urgency)
  ]
  let nm-sym-covid count symp-covid  ;; number of covid infected ppl who want to get-tested today
  if nm-sym-covid > 0 [set ratio-flu-covid round (flu-symp / nm-sym-covid)]

  ask turtles with [infected > 0 and (not hospitalized?)] [   ;; we could exclude those still in the incubation phase here. We don't, so that we produce a few false positives in the app
    ; Infected agents (except those in hospital) infect others
    set days_cont days_cont + 1
    infect
    if member? self symp-covid [
      ifelse tests-remaining > 0
        [get-tested "symptomatic-individual"]
        [if not isolated? [maybe-isolate "symptomatic-individual"]]
    ]
  ]

  ;;crowd workers work 5 days and may infect the customers or be infected by them
  ask crowd-workers with [not isolated? and (not hospitalized?)] [if 5 / 7 > random-float 1 [meet-people]]

  ;;non-symptomatic are can get tested in tests are still available- in case of priorty to  testing symptomatic
  if tests-remaining > 0 and (length testing-today) > 0 [test-people]

  ;;after the infection between contactas took place during the day, at the "end of the day" agents change states
  ask turtles with [infected > 0][progression-disease]

  ;; The new strain appears after two months
  if ticks = 60 and new-strain [
    ask n-of round (table:get populations "infected" / 20) turtles with [infected > 0][set infected 4]
  ]

  ifelse behaviorspace-run-number != 0
  [ save-individual ]
  [ show-plots ]
  tick
end

;;;; TODO: Make immunityLasts an individual attribute with a distribution set at the beginning.
to update-vaccinations
  ;; First we administer second doses and boosters. We do it this way to simulate interference between 2nd and 1st doses.
  ;; Uncomment the routine below to administer first doses first.
  ask wantvax with [vaxed > 0][    ;; wantvax is the people who are eligible and willing to get vaccinated
    set days-since-dose days-since-dose + 1
    if vaxed = 1 and daily-vaccinations > 0 and days-since-dose >= interval [receiveVax]
  ]
  ;; If we have doses left we vaccinate those who haven't had the first dose yet or need a booster
  if daily-vaccinations > 0  [
    let vaxingtoday wantvax with [vaxed = 0 or (days-since-dose > (immunityLasts * 30))]
    let vaxingnow ifelse-value count vaxingtoday > daily-vaccinations [daily-vaccinations][count vaxingtoday]
    ask max-n-of vaxingnow vaxingtoday [age] [receiveVax]
  ]
end

;to update-vaccinations
;  ;; First we administer first doses. wantvax is the people who are eligible and willing to get vaccinated
;  let vaxingtoday wantvax with [vaxed = 0]
;  let vaxingnow ifelse-value count vaxingtoday > daily-vaccinations [daily-vaccinations][count vaxingtoday]
;  ask max-n-of vaxingnow vaxingtoday [age] [receiveVax]
;
;  ;; If we have doses left we administer second doses
;  ask wantvax with [vaxed > 0][
;    set days-since-dose days-since-dose + 1
;    ifelse vaxed > 1
;      [if days-since-dose = (immunityLasts * 30)[set vaxed 0]]   ;; People with vax = 2 (or more). Immunity is over, they need a booster
;      [if daily-vaccinations > 0 and days-since-dose >= interval [receiveVax]]  ;; this is people with vax = 1
;  ]
;end

to clear-count
  set nb-infected 0
  set nb-recovered 0
  set tests-today 0
  set tested-positive 0
  set vaccinatedToday 0
  set testing-today testing-tomorrow
  set testing-tomorrow []
end

to change-state [new-state]
  table:put populations myState (table:get populations myState - 1)
  set myState new-state
  table:put populations myState (table:get populations myState + 1)
  table:put cumulatives myState (table:get cumulatives myState + 1)
end

;; =========================================================================
;;                    PROGRESSION OF THE INFECTION
;; =========================================================================

;; After the incubation period the person may become asymptomatic or mild symptomatic or severe symptomatic.
;; Severely ill agents are hospitlized within few days
to progression-disease
  set state-counter state-counter + 1
  ifelse (myState = "incubation") [
    if (state-counter = t-infectious) [set chance-of-infecting (infection-chance * getMutationInfectivity infected * getVaccinatedInfectivity)]
    if (state-counter = t-incubation) [determine-progress]
  ][
    ifelse (myState = "asymptomatic") [
      if (state-counter = t-asymptomatic) [recover]
      if (t-incubation - t-infectious + state-counter > 3) [set chance-of-infecting chance-of-infecting * 0.9] ;; we assume asymptomatic infectiousness declines at 3rd day
      ][ifelse (myState = "symptomatic") and (state-counter = t-symptomatic) [recover][
        ifelse (myState = "severe") and (state-counter = t-severe) [hospitalize][      ;;severe cases are hospitlized within several days
          if (myState = "in-hospital") and (state-counter = t-hospital) [ifelse probability-of-dying * gender-discount > random-float 1  [kill-agent] [recover]]  ;patient either dies in hospital or recover
        ]
      ]
    ]
  ]
  if (member? myState ["symptomatic" "asymptomatic"]) and (state-counter = t-stopinfecting) [set chance-of-infecting 0]  ;;stop being infectious after 7-11 days
;; agents states: "incubation" "asymptomatic" "symptomatic" "severe" "in-hospital" "recovered" "dead"
end

to determine-progress
  ifelse prob-symptoms * getVaccinatedRiskSymptoms > random-float 1 [
    ;show "DEBUG: I have the symptoms!"
    ifelse probability-of-worsening * getVaccinatedRiskSevere * (getMutationAggressiveness infected) > random-float 1 [
      change-state "severe"
      set severe-symptoms? true
      set symptomatic? true
      set state-counter 0
    ]
    [change-state "symptomatic"
      set symptomatic? true
      set state-counter 0
    ]
  ]
  [ change-state "asymptomatic"
    set state-counter 0
  ]
end

to recover
  set state-counter 0
  change-state "recovered"
  table:put populations "infected" (table:get populations "infected" - 1)
  set cured infected
  set infected 0
  set symptomatic? false
  set days-since-cured 1
  set all-infections lput spreading-to all-infections

  if behaviorspace-run-number = 0 [
    ifelse table:has-key? infections ticks
    [table:put infections ticks (lput spreading-to table:get infections ticks)]
    [table:put infections ticks (list spreading-to)]
  ]

  if hospitalized? [
    set hospitalized? false
    set isolated? false
  ]

  if isolated? [unisolate]
  set aware? false
  set nb-recovered (nb-recovered + 1)
end

to kill-agent
  table:put populations myState (table:get populations myState - 1)
  table:put populations "infected" (table:get populations "infected" - 1)
  table:put populations "dead" (table:get populations "dead" + 1)
  table:put cumulatives "dead" (table:get cumulatives "dead" + 1)
  if hospitalized? [set isolated? false]
  if isolated? [table:put populations "isolated" (table:get populations "isolated" - 1)]
  set all-infections lput spreading-to all-infections

  if behaviorspace-run-number = 0 [
    ifelse table:has-key? infections ticks
    [table:put infections ticks lput spreading-to table:get infections ticks ]
    [table:put infections ticks (list spreading-to)]
  ]

  die

  if table:get populations "dead" = 1 [
    if lockdown-at-first-death [lockdown]
    if behaviorspace-run-number = 0 [
      output-print (word "Epidemic day " ticks ": death number 1. Age: " age "; gender: " sex)
      output-print (word "Duration of agent's infection: " t-incubation " days incubation + " (t-severe + t-hospital)  " days of illness")
      print-current-summary
    ]
  ]
end

to test-people
  set testing-today remove-duplicates testing-today
  let to-test length testing-today

  if to-test >= tests-remaining [set to-test tests-remaining]

  repeat to-test [
    ask item 0 testing-today [get-tested "other"]
    set testing-today remove-item 0 testing-today
  ]
end

;; ===============================================================================

to enter-list
  set testing-tomorrow fput self testing-tomorrow
end

to-report should-test?
  if not tested-today? and not aware? and not member? self testing-tomorrow [report true]
  report false
end

to-report should-isolate?
  if not isolated? and not aware? and not tested-today? [report true]
  report false
end

to-report can-be-infected? [variantBeingTransmitted]
  if (infected = 0) and (not aware?) and (cured < variantBeingTransmitted) [report true]
  report false
end

to maybe-isolate [origin]
  let tendency isolation-tendency
  if member? origin low-prob-isolating and not symptomatic? [set tendency tendency * compliance-adjustment]
  if random-float 1 < tendency [
    isolate
    ;;symptomatic ask hh members and relatives to isolate
    if origin = "symptomatic-individual" [
      ask hh with [should-isolate?][maybe-isolate "household-of-symptomatic"]
      if any? relatives [ask relatives with [should-isolate?] [maybe-isolate "relation-of-symptomatic"]]
      ;if has-app? [ask tracing-neighbors with [should-isolate?] [maybe-isolate "app-contact-of-symptomatic"]]
    ]
  ]
end

;; When the agent is isolating all friendhips and relations are frozen. The agent stops going to school or work.
;; household members links stay in place, as it is assumed that one isolates at home
to isolate
  set isolated? true
  table:put populations "isolated" (table:get populations "isolated" + 1)
end

to unisolate  ;; turtle procedure
  set isolated? false
  table:put populations "isolated" (table:get populations "isolated" - 1)
  set days-isolated 0
end

to hospitalize ;; turtle procedure
  set state-counter 0
  change-state "in-hospital"
  set hospitalized? true
  set aware? true

  ;; We assume that hospitals always have tests. If the aget ends up in hospital, the app updates the contacts.
  ask tracing-neighbors with [should-test?] [
    if not isolated? [maybe-isolate "app-contact-of-positive"]
    ifelse prioritize-symptomatics?
    [enter-list]
    [if tests-remaining > 0 [get-tested "other"]]
  ]
  ifelse not isolated? [set isolated? true]                 ;; The agent is isolated, so people won't encounter him around, but we don't count him
  [table:put populations "isolated" table:get populations "isolated" - 1]

  set pcolor black

  if show-layout [
    move-to patch (max-pxcor / 2) 0
    set pcolor white
  ]
end

;=====================================================================================

;; Encounters between 'crowd workers' and the crowd.
;; There's a chance that the worker will get infected and that he will infect someone.
to meet-people
  let here table:get placecnt neigh
  let nmMeet ((lambda * 3) * item 0 here)  ;;contacts with customer are:lambda % of the people in the neigh
  let propelderly  0.5 * (1 - item 1 here) ;;gives 50% of the proportion of the elderly in the neigh
  set howmanyelder round (nmMeet * propelderly)
  set howmanyrnd nmMeet - howmanyelder

  let spreader self
  let chance chance-of-infecting
  let victim self
  let locals other table:get place neigh
  let crowd (turtle-set
    up-to-n-of random-poisson (howmanyrnd ) locals with [ age < 67]
    up-to-n-of random-poisson (howmanyelder) locals with [age > 67])
  ifelse infected > 0 [
    let variantBeingTransmitted infected
    ;; Here the worker is infecting others
    ask crowd [
      let in_contact false
      if random-float 1 < c [
            set in_contact true
            ask myself [set nm_contacts nm_contacts + 1]
      ]
      if (can-be-infected? variantBeingTransmitted) and (not isolated?) and in_contact [
        if has-app? and [has-app?] of spreader [add-contact spreader]

        if random-float 1 < (chance * (age-discount * getVariantAge variantBeingTransmitted) * (getVaccinatedRiskOfInfection variantBeingTransmitted) * prob-rnd-infection * b)
        [newinfection spreader "random"]  ; If the worker infects someone, it counts as random
      ]
    ]
  ]
  [
    ask crowd with [infected > 0 and (not isolated?) and (random-float 1 < c)]   [
      ;; here the worker is being infected by others
      ask myself[set nm_contacts nm_contacts + 1]
      set spreader self
      let variantBeingTransmitted infected
        set chance chance-of-infecting
        ask victim [
          if can-be-infected? variantBeingTransmitted [
            if has-app? and [has-app?] of spreader [add-contact spreader]

            if random-float 1 < (chance * prob-rnd-infection * (getVaccinatedRiskOfInfection variantBeingTransmitted) * b) [newinfection spreader "work"] ; If the worker is infected by someone, it's work.
          ]
        ]
    ]
  ]
end

;; Infected individuals who are not isolated or hospitalized have a chance of transmitting
;; their disease to their susceptible friends and family.
;; We allow people to meet others even before they are infective so that the app will record these
;; interactions and produce a few false positives

to infect  ;; turtle procedure
  ;; Number of people we meet at random every day: 1 per 1000 people. Elderly goes out 1/2 less than other
  let here table:get placecnt neigh

  let nmMeet (lambda * item 0 here)  ;;random contacts with lambda % of the people in the neigh
  let propelderly  0.5 * (1 - item 1 here) ;;gives 50% of the proportion of the elderly in the neigh
  set howmanyelder round(nmMeet * propelderly)
  set howmanyrnd nmMeet - howmanyelder
  let spreader self
  let variantBeingTransmitted infected
  let chance chance-of-infecting

  ;; Every day an infected person risks infecting all other household members.
  ;; Even if the agent is isolating or there's a lockdown.
  if count hh > 0  [
    let hh-infection-chance chance
    ;; if the person is isolating the people in the household have a reduced risk to get infected
    if isolated? [set hh-infection-chance hh-infection-chance * 0.7]

    ask hh with [can-be-infected? variantBeingTransmitted] [
      if random-float 1 < (hh-infection-chance * (age-discount * getVariantAge variantBeingTransmitted) * getVaccinatedRiskOfInfection variantBeingTransmitted)
      [newinfection spreader "household"]
    ]
  ]

  ;; When we are not isolated, we go out and infect other people.
  if (not isolated?) [

    ;; Infected agents will infect someone at random. The probability is a fraction of the normal infection-chance
    ;; If both parties have the app a link is created to keep track of the meeting
    let random-passersby nobody
    if (age <= 67 or 0.5 > random-float 1) [
      let locals table:get place neigh
      set random-passersby (turtle-set
        up-to-n-of random-poisson howmanyrnd other locals with [age < 65 ]
        up-to-n-of random-poisson howmanyelder other locals with [age > 65 ]
      )
      ;show random-passersby
    ]
    let nm-passby 0
    if random-passersby != nobody [set nm-passby count random-passersby ]
    set nm_contacts nm_contacts + count hh
    let proportion max-prop-friends-met   ;; Change this and the infection probability if we want more superpreading
    if age > 40 [set proportion proportion / 2] ;; older meets less

    ;; The following are schoolkids
    ifelse age > 5 and age < 18 [
      if schools-open? and ((5 / 7) > random-float 1) [  ;; If schools are open children go to school 5 days a week
        ;; Schoolchildren meet their schoolmates every SCHOOLDAY, and can infect them.
        set proportion proportion / 2 ;;school children meet less than younger adults
        let classmates table:get school myclass
        set classmates classmates  with [isolated? = false]
        ask n-of ((count classmates * 0.5) ) other classmates [
          let in_contact false
          if random-float 1 < c [
            set in_contact true
            ask myself[set nm_contacts nm_contacts + 1 ]
          ]
          if can-be-infected? variantBeingTransmitted and in_contact [
            ; We don't rely on the app in school. The classrom is quarantined if a pupil is positive
            ;if has-app? and [has-app?] of spreader [add-contact spreader]
              if random-float 1 < (chance * (age-discount * getVariantAge variantBeingTransmitted) * getVaccinatedRiskOfInfection variantBeingTransmitted)
            [newinfection spreader "school"]
          ]
        ]
      ]
    ]
    ;; People who work in offices
    [
      if office-worker? and (((5 - fq) / 7) > random-float 1) [ ;; People who work in offices go to work 5 days a week
        let todaysvictims (turtle-set n-of (count close-colleagues) close-colleagues one-of wide-colleagues)
        ask todaysvictims [
          let in_contact false
          if random-float 1 < c [
            set in_contact true
            ask myself[set nm_contacts nm_contacts + 1 ] ]
          if can-be-infected? variantBeingTransmitted and (not isolated?) and (in_contact) [
          if has-app? and [has-app?] of spreader [add-contact spreader]
          if random-float 1 < (chance * b * bsens * (getVaccinatedRiskOfInfection variantBeingTransmitted) )
            [newinfection spreader "work"]
          ]
        ]
      ]
    ]

    ;; The following applies to everyone who has friends
    if (age <= 67 or 0.5 > random-float 1) [    ;;; Old people only meet friends  half of the times younger people do.
                                                ;;; Every day the agent meets a certain fraction of her friends.
                                                ;;; If the agent has the contact tracing app, a link is created between she and the friends who also have the app.
                                                ;;; If the agent is infective, with probability infection-chance, he infects the susceptible friends who he's is meeting.
      if count friends > 0 [
        let howmany 1 + random round (count friends * proportion)
   ;;----------------------------------------------------------------------------------------------------
        ;;This is for sensitivity analysis of friends meeting
        if per-dif-friends != 0[
          ;;here we want to increase friends meeting
           if per-dif-friends > 0 [
            repeat howmany [if random-float 1 <= per-dif-friends [set howmany howmany + 1] ]
            set howmany min (list howmany round (count friends))
          ]
          ;;here we decrease meeting
           if per-dif-friends < 0 [ repeat howmany [if random-float 1 <= -1 * per-dif-friends [set howmany howmany - 1] ]
          ]
        ]
;;-------------------------------------------------------------------------------------------------------------
        if howmany > 0[
          ask n-of howmany friends [
            let in_contact false
            if random-float 1 < c [
              set in_contact true
            ask myself[set nm_contacts nm_contacts + 1] ]
            if (not isolated?) and (can-be-infected? variantBeingTransmitted) and (in_contact) [
              if has-app? and [has-app?] of spreader [add-contact spreader]
              if random-float 1 < ((chance * (age-discount * getVariantAge variantBeingTransmitted) * (getVaccinatedRiskOfInfection variantBeingTransmitted) * b * bsens))
              [newinfection spreader "friends"]]
         ]
        ]

      ]
    ]

    ;; Every week we visit granpa twice and risk infecting him
    if count relatives > 0  and (2 / 7) > random-float 1 [
      set nm_contacts nm_contacts + 1
      ask one-of relatives [
        if can-be-infected? variantBeingTransmitted and (not isolated?) [
          if random-float 1 < (chance * (age-discount * getVariantAge variantBeingTransmitted) * (getVaccinatedRiskOfInfection variantBeingTransmitted) * b)
          [newinfection spreader "relations"]
        ]
      ]
    ]

    ;; Here we determine who are the unknown people we encounter. This is the 'random' group.
    ;; If we are isolated or there is a lockdown, this is assumed to be zero.
    ;; Elderly people are assumed to go out half as much as everyone else.
    ;; Currently an individual meets a draw from a poisson distribution with average howmanyrnd or howmanyelder
    if random-passersby != nobody [
      ask random-passersby [
        let in_contact false
        if random-float 1 < c [
            set in_contact true
            ask myself[set nm_contacts nm_contacts + 1] ]
        if (can-be-infected? variantBeingTransmitted) and (not isolated?) and in_contact  [
          if has-app? and [has-app?] of spreader [add-contact spreader]

          if random-float 1 < (chance * (age-discount * getVariantAge variantBeingTransmitted) * (getVaccinatedRiskOfInfection variantBeingTransmitted) * prob-rnd-infection * b)
          [newinfection spreader "random"]
        ]
      ]
    ]
  ]
end

to add-contact [infected-agent]
  create-tracing-with infected-agent [set day 0]
end

to newinfection [spreader origin]
  set infected [infected] of spreader
  ;;; OMICRON has a lower incubation period. This should be set somewhere else, we put it here ftb
  if infected = 4 [set t-incubation round random-normal 2 1]
  set state-counter 0
  change-state "incubation"
  table:put populations "infected" (table:get populations "infected" + 1)
  set symptomatic? false
  set severe-symptoms? false
  set aware? false
  set nb-infected (nb-infected + 1)
  set chance-of-infecting 0
  set infected-by spreader
  ask spreader [set spreading-to spreading-to + 1]
  table:put counters origin (table:get counters origin + 1)
end

;;  ========= Interventions =============================

to lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Locking down!")
  ]
  setSocialDistancing "ld"
  close-schools
end

to remove-lockdown
  if behaviorspace-run-number = 0 [
    output-print " ================================ "
    output-print (word "Day " ticks ": Removing lockdown!")
  ]
  setSocialDistancing "sd"
  reopen-schools
end

to close-schools
  set schools-open? false
end

to reopen-schools
  set schools-open? true
end

to get-tested [origin]
  ;show (word "  day " ticks ": tested-today?: " tested-today? " - aware?: " aware? "  - now getting tested")
  let depletion 1
  if origin = "symptomatic-individual" [set depletion depletion + ratio-flu-covid]

  set tests-remaining tests-remaining - depletion
  set tests-performed tests-performed + depletion
  set tests-today tests-today + depletion  ; this all tests today including flu symptomatic
                                           ; if tests-remaining = 0 and behaviorspace-run-number = 0 [output-print (word "Day " ticks ": tests finished")]

  ;; If someone is found to be positive they:
  ;; 1. Isolate, 2. Their household decides whether to isolate, 3. The notify relatives
  ;; 4. If they use the app, the contacts are notified and have the option of getting tested or isolate.
  ifelse infected > 0 [
    set tested-positive tested-positive + 1
    if should-isolate? [isolate]
    set tested-today? true
    set aware? true
    ask hh with [should-test?]  ;;notify the hh memebers
      [if not isolated? [maybe-isolate "household-of-positive"]] ;;hh member decides wether to self-isolte

    if any? relatives [
      ask relatives [
        if should-isolate?
            [
              maybe-isolate "relation-of-positive"
              ifelse prioritize-symptomatics?
              [enter-list]
              [if tests-remaining > 0 [get-tested "other"]]
        ]
      ]
    ]
    if age > 5 and age < 18 [ask other table:get school myclass [SCHOOL-ALERT]]
    ;; Following a positive test the app notifies the contacts
    if has-app? [ask tracing-neighbors with [should-test?] [APP-ALERT]]
  ]
  [if isolated? [unisolate]] ;;agent who was isolating and tested negative will unisolate
end

to SCHOOL-ALERT
  if not isolated? [isolate]
  if should-test? [
    ifelse prioritize-symptomatics?
    [enter-list]
    [if tests-remaining > 0 [get-tested "other"]]
  ]
end

to APP-ALERT
  if not isolated? [maybe-isolate "app-contact-of-positive"]
  ifelse prioritize-symptomatics?
  [enter-list]
  [if tests-remaining > 0 [get-tested "other"]]
end

;; =======================================================

to-report impossible-run
  if (pct-with-tracing-app = 0 and app-compliance = "High") OR
  (tests-per-100-people = 0 and prioritize-symptomatics?)
  [report true]
  report false
end

to-report useful-run
  ifelse infectivityVariation > 1.6 [
    if riskInfection_2dose > 0.66 [
      show (word "Warning: infectivity is " infectivityVariation " and vaccine escape is " riskInfection_2dose ". Halting execution")
      report false
    ]
  ][
    if riskInfection_2dose < 0.66 [
      show (word "Warning: infectivity is " infectivityVariation " and vaccine escape is " riskInfection_2dose ". Halting execution")
      report false]
  ]
  report true
end

;;===================== work distribution ==================================
@#$#@#$#@
GRAPHICS-WINDOW
690
980
899
1190
-1
-1
1.0
1
10
1
1
1
0
0
0
1
-100
100
-100
100
1
1
1
day
30.0

BUTTON
180
125
260
158
setup
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
265
125
330
158
go
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

PLOT
0
480
406
672
Populations
days
# people
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot table:get populations \"infected\""
"Dead" 1.0 0 -16777216 true "" "plot table:get populations \"dead\""
"Hospitalized" 1.0 0 -955883 true "" "plot table:get populations \"in-hospital\""
"Self-Isolating" 1.0 0 -13791810 true "" "plot table:get populations \"isolated\""

PLOT
0
675
409
843
Infection and Recovery Rates
days
rate
0.0
10.0
0.0
0.1
true
true
"" ""
PENS
"Infection Rate" 1.0 0 -2674135 true "" "plot (beta-n * nb-infected-previous)"
"Recovery Rate" 1.0 0 -10899396 true "" "plot (gamma * nb-infected-previous)"

SLIDER
5
25
150
58
infection-chance
infection-chance
0
0.2
0.07
0.001
1
NIL
HORIZONTAL

PLOT
5
300
405
475
Prevelance of Susceptible/Infected/Recovered
days
% total pop.
0.0
10.0
0.0
100.0
true
true
"" ""
PENS
"Infected" 1.0 0 -2674135 true "" "plot (table:get populations \"infected\" / N-people) * 100"
"Recovered" 1.0 0 -9276814 true "" "plot (table:get populations \"recovered\" / N-people) * 100"
"Susceptible" 1.0 0 -10899396 true "" "plot (table:get populations \"susceptible\" / N-people) * 100"

BUTTON
565
265
645
298
LOCKDOWN
lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

MONITOR
260
210
330
255
Deaths
table:get populations \"dead\"
0
1
11

SWITCH
345
170
515
203
lockdown-at-first-death
lockdown-at-first-death
1
1
-1000

OUTPUT
520
10
1025
265
12

SLIDER
5
60
150
93
initially-infected
initially-infected
0
5
1.6
0.1
1
%
HORIZONTAL

PLOT
1045
535
1385
730
Infections per agent
# agents infected
# agents
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

SLIDER
345
100
510
133
pct-with-tracing-app
pct-with-tracing-app
0
100
25.0
1
1
%
HORIZONTAL

SLIDER
345
134
512
167
tests-per-100-people
tests-per-100-people
0
20
100.0
0.01
1
NIL
HORIZONTAL

SWITCH
180
160
330
193
use-seed?
use-seed?
1
1
-1000

MONITOR
185
210
255
255
Available
tests-remaining
0
1
11

MONITOR
1035
250
1092
299
Rt
rtime
3
1
12

PLOT
410
300
695
495
Source of infection
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
"Hshold" 1.0 0 -16777216 true "" "plot table:get counters \"household\""
"Social" 1.0 0 -13791810 true "" "plot table:get counters \"friends\""
"School" 1.0 0 -2674135 true "" "plot table:get counters \"school\""
"Strangers" 1.0 0 -955883 true "" "plot table:get counters \"random\""
"Relations" 1.0 0 -7500403 true "" "plot table:get counters \"relations\""
"Wkplace" 1.0 0 -13840069 true "" "plot table:get counters \"work\""

SWITCH
345
33
510
66
schools-open?
schools-open?
0
1
-1000

TEXTBOX
10
10
170
28
Disease Configuration 
12
0.0
1

TEXTBOX
280
105
330
123
Runtime
12
0.0
1

BUTTON
650
265
740
298
END LCKDWN
remove-lockdown
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
185
255
255
300
Performed
tests-performed
1
1
11

TEXTBOX
185
195
230
213
Tests
11
0.0
1

PLOT
905
980
1260
1195
Age distribution
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
"default" 1.0 1 -16777216 false "" ""

TEXTBOX
170
10
320
36
Behaviour configuration
12
0.0
1

CHOOSER
165
25
330
70
app-compliance
app-compliance
"High" "Low"
0

SLIDER
5
95
150
128
initially-cured
initially-cured
0
100
20.0
0.1
1
%
HORIZONTAL

BUTTON
365
265
455
298
NIL
close-schools
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
459
265
559
298
NIL
reopen-schools
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

PLOT
415
760
683
971
Degree distribution (log-log)
log(degree)
log(# of nodes)
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

PLOT
685
760
953
975
Degree distribution
degree
# of nodes
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

PLOT
695
300
1040
495
Type of infection
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
"Symptomatic" 1.0 0 -955883 true "" "plot table:get cumulatives \"symptomatic\""
"Asymptomatic" 1.0 0 -13840069 true "" "plot table:get cumulatives \"asymptomatic\""
"Severe" 1.0 0 -2674135 true "" "plot table:get cumulatives \"severe\""

PLOT
415
975
685
1190
work-sites
# of workers on site
# of work  sites
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -14070903 true "" ""

SWITCH
345
70
510
103
social-distancing?
social-distancing?
1
1
-1000

SLIDER
165
70
330
103
average-isolation-tendency
average-isolation-tendency
0
1
0.7
0.01
1
NIL
HORIZONTAL

SWITCH
345
205
515
238
prioritize-symptomatics?
prioritize-symptomatics?
0
1
-1000

PLOT
0
845
410
1106
Number of contacts per day of infected
NIL
NIL
0.0
50.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 1 -16777216 true "" ""

MONITOR
1095
250
1220
299
prop infected by top 20% spreaders
k0
3
1
12

PLOT
965
745
1306
975
Infection distribution (log-log)
NIL
NIL
0.0
0.3
0.0
0.3
true
false
"" ""
PENS
"default" 1.0 2 -16777216 true "" ""

TEXTBOX
415
735
615
760
Friendship network
16
0.0
1

TEXTBOX
345
10
430
31
Mitigations
14
0.0
1

SLIDER
1205
65
1360
98
lambda
lambda
0.0020
0.01
0.008
0.001
1
NIL
HORIZONTAL

SLIDER
1205
100
1360
133
prob-rnd-infection
prob-rnd-infection
0.01
0.2
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
1205
30
1360
63
max-prop-friends-met
max-prop-friends-met
0
1
0.1
0.05
1
NIL
HORIZONTAL

TEXTBOX
1205
10
1390
28
Sensitivity analysis
14
0.0
1

SLIDER
1205
135
1360
168
per-dif-friends
per-dif-friends
-1
1
0.0
0.1
1
NIL
HORIZONTAL

SLIDER
1205
170
1360
203
bsens
bsens
0.50
1.50
1.0
0.25
1
NIL
HORIZONTAL

SLIDER
5
230
175
263
dose-interval
dose-interval
4
12
4.0
4
1
weeks
HORIZONTAL

PLOT
410
500
745
730
Vaccinations
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"None" 1.0 0 -16777216 true "" "plot count turtles with [vaxed = 0] / N-People"
"One dose" 1.0 0 -7500403 true "" "plot count turtles with [vaxed = 1] / N-People"
"Two doses" 1.0 0 -2674135 true "" "plot count turtles with [vaxed = 2] / N-People"
"Boosted" 1.0 0 -955883 true "" "plot count turtles with [vaxed > 2] / N-People"

PLOT
745
500
1040
730
Infections and mutations
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Base" 1.0 0 -16777216 true "" "plot count turtles with [infected = 1] / count turtles with [infected > 0]"
"Alpha" 1.0 0 -7500403 true "" "plot count turtles with [infected = 2] / count turtles with [infected > 0]"
"Delta" 1.0 0 -2674135 true "" "plot count turtles with [infected = 3] / count turtles with [infected > 0]"
"Omicron" 1.0 0 -14070903 true "" "plot count turtles with [infected = 4] / count turtles with [infected > 0]"

TEXTBOX
10
175
95
195
Vaccination
14
0.0
1

SLIDER
5
195
175
228
vaccination-capacity
vaccination-capacity
0
1000
800.0
1
1
/day
HORIZONTAL

MONITOR
260
255
360
300
NIL
vaccinatedToday
0
1
11

BUTTON
745
265
842
298
Social Dist
setSocialDistancing \"sd\"
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
845
265
967
298
End social dist
setSocialDistancing \"no\"
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
265
175
298
immunityLasts
immunityLasts
0
100
6.0
1
1
months
HORIZONTAL

SWITCH
1030
35
1145
68
new-strain
new-strain
0
1
-1000

SLIDER
1030
70
1195
103
aggressiveness
aggressiveness
0
10
1.0
0.01
1
NIL
HORIZONTAL

TEXTBOX
1030
10
1180
28
New strain
14
0.0
1

SLIDER
1030
105
1195
138
infectivityVariation
infectivityVariation
0
10
1.9
0.01
1
NIL
HORIZONTAL

SLIDER
1030
140
1195
173
riskInfection_1dose
riskInfection_1dose
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
1030
175
1195
208
riskInfection_2dose
riskInfection_2dose
0
riskInfection_1dose
1.0
0.01
1
NIL
HORIZONTAL

CHOOSER
5
130
143
175
Delta_variant
Delta_variant
true false "incipient"
1

MONITOR
1225
255
1275
300
Transmission
transEff
2
1
11

MONITOR
1275
255
1325
300
Symptom
symptEff
2
1
11

MONITOR
1325
255
1382
300
Severe
severeEFF
2
1
11

TEXTBOX
1225
235
1375
253
Vaccine efficacy ========
12
0.0
1

PLOT
1045
305
1380
530
Vaccine efficacy
NIL
NIL
12.0
200.0
45.0
100.0
false
true
"" ""
PENS
"Transmission" 1.0 0 -16777216 true "" "plot transEff * 100"
"Symptomatic" 1.0 0 -11221820 true "" "plot symptEff * 100"
"Severe" 1.0 0 -2674135 true "" "plot severeEff * 100"

SLIDER
1030
210
1195
243
riskInfection_boosted
riskInfection_boosted
0
1
0.5
0.01
1
NIL
HORIZONTAL

@#$#@#$#@
todo: extend vaccinations to 12+
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

person lefty
false
0
Circle -7500403 true true 170 5 80
Polygon -7500403 true true 165 90 180 195 150 285 165 300 195 300 210 225 225 300 255 300 270 285 240 195 255 90
Rectangle -7500403 true true 187 79 232 94
Polygon -7500403 true true 255 90 300 150 285 180 225 105
Polygon -7500403 true true 165 90 120 150 135 180 195 105

person righty
false
0
Circle -7500403 true true 50 5 80
Polygon -7500403 true true 45 90 60 195 30 285 45 300 75 300 90 225 105 300 135 300 150 285 120 195 135 90
Rectangle -7500403 true true 67 79 112 94
Polygon -7500403 true true 135 90 180 150 165 180 105 105
Polygon -7500403 true true 45 90 0 150 15 180 75 105

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

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.2.2
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="lotsofrandom" repetitions="20" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="0"/>
      <value value="0.5"/>
      <value value="1"/>
      <value value="1.5"/>
      <value value="3"/>
      <value value="6"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
      <value value="&quot;Low&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity-l" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="1.5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.005"/>
      <value value="0.0075"/>
      <value value="0.0125"/>
      <value value="0.015"/>
      <value value="0.02"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="per-dif-friends">
      <value value="&quot;0&quot;"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity-b" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="1.5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="per-dif-friends">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bsens">
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1.25"/>
      <value value="1.5"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity-p" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="1.5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.05"/>
      <value value="0.075"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="per-dif-friends">
      <value value="0"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="sensitivity-f2" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="0.3"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="1.5"/>
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="0"/>
      <value value="20"/>
      <value value="40"/>
      <value value="60"/>
      <value value="80"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.08"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.01"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="per-dif-friends">
      <value value="0.25"/>
      <value value="0.5"/>
      <value value="0.75"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Massive" repetitions="15" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.07"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dose-interval">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freak-variant">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Delta_variant">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aggressiveness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infectivityVariation">
      <value value="1"/>
      <value value="1.1"/>
      <value value="1.2"/>
      <value value="1.3"/>
      <value value="1.4"/>
      <value value="1.5"/>
      <value value="1.6"/>
      <value value="1.7"/>
      <value value="1.8"/>
      <value value="1.9"/>
      <value value="2"/>
      <value value="2.1"/>
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_1dose">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_2dose">
      <value value="0.1"/>
      <value value="0.2"/>
      <value value="0.3"/>
      <value value="0.4"/>
      <value value="0.5"/>
      <value value="0.66"/>
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Delta" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.07"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dose-interval">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freak-variant">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aggressiveness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infectivityVariation">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_1dose">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_2dose">
      <value value="0.66"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="Interval" repetitions="20" runMetricsEveryStep="true">
    <setup>setup</setup>
    <go>go</go>
    <metric>count turtles</metric>
    <enumeratedValueSet variable="lambda">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="immunityLasts">
      <value value="9"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="bsens">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="Delta_variant">
      <value value="false"/>
      <value value="&quot;incipient&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="vaccination-capacity">
      <value value="800"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infectivityVariation">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="per-dif-friends">
      <value value="0"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dose-interval">
      <value value="4"/>
      <value value="8"/>
      <value value="12"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aggressiveness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_2dose">
      <value value="0.82"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_1dose">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freak-variant">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.07"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="missingRuns1" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.07"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dose-interval">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freak-variant">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aggressiveness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infectivityVariation">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_1dose">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_2dose">
      <value value="0.7"/>
      <value value="0.8"/>
      <value value="0.9"/>
      <value value="1"/>
    </enumeratedValueSet>
  </experiment>
  <experiment name="missingRuns2" repetitions="10" sequentialRunOrder="false" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
    <enumeratedValueSet variable="show-layout">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-cured">
      <value value="20"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="average-isolation-tendency">
      <value value="0.7"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-existing-nw?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="social-distancing?">
      <value value="true"/>
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="initially-infected">
      <value value="1.6"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lockdown-at-first-death">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="tests-per-100-people">
      <value value="100"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="app-compliance">
      <value value="&quot;High&quot;"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="pct-with-tracing-app">
      <value value="25"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infection-chance">
      <value value="0.07"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="use-seed?">
      <value value="false"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="schools-open?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prioritize-symptomatics?">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="lambda">
      <value value="0.008"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="prob-rnd-infection">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="max-prop-friends-met">
      <value value="0.1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="dose-interval">
      <value value="8"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="freak-variant">
      <value value="true"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="aggressiveness">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="infectivityVariation">
      <value value="1.7"/>
      <value value="1.8"/>
      <value value="1.9"/>
      <value value="2"/>
      <value value="2.1"/>
      <value value="2.2"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_1dose">
      <value value="1"/>
    </enumeratedValueSet>
    <enumeratedValueSet variable="riskInfection_2dose">
      <value value="0.66"/>
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
@#$#@#$#@
1
@#$#@#$#@
