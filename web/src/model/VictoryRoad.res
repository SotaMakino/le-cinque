// The road a won round leaves behind. Every letter that reaches the board takes
// its key off the keyboard, and so does every letter proved to spell none of the
// words, so the holes left standing spell out a different track after every win.
// The car reads them left to right and changes lane to keep to the empty keys.

// a vacated key, measured in the keyboard box's own coordinates
type gap = {x: float, y: float, halfWidth: float}

// one waypoint of the drive: how far through it is, where the car is, and how
// far the car is nosing over
type stop = {at: float, x: float, y: float, tilt: float}

type drive = {stops: array<stop>, seconds: float}

let sampleStep = 24.0 // how finely the keyboard is read for holes
// How far the car leans, and — because the lean is the slope it is actually on —
// how steeply it is allowed to change lane. Gentler than this and a row of keys
// is more than it can climb in the run between two holes, so it gives up on the
// holes and drives the whole keyboard on a long diagonal instead. The clip is
// bled a few pixels top and bottom to give a car at full lean somewhere to be.
let maxTilt = 28.0
// The keys sit a few pixels apart, so two vacated ones side by side leave a
// hairline of keyboard between them. The car does not fall down that crack: a
// gap reaches this far past the edge of the key that left it.
let kerb = 6.0
// Two gaps this close share a lane. Every key in a row has the same centre line,
// so this only has to survive the rounding, not tell rows apart.
let sameLane = 8.0
let speed = 150.0 // px per second on the flat, whatever the screen is wide
// Eighteen horses did not take a hill quickly. A pixel of climb — or of coming
// back down it — costs the car as much time as a pixel of going along, so it
// labours up the change of lane and picks the pace back up on the straight.
let climb = 1.0
let carAhead = 32.0 // the nose, ahead of the waypoint…
let carBehind = 175.0 // …and the tail of the tricolore, behind it

// the steepest line the car can be drawn on, as a rise per unit of run
let maxSlope = Js.Math.tan(maxTilt *. Js.Math._PI /. 180.0)

let clamp = (v, limit) => v > limit ? limit : v < -.limit ? -.limit : v
let near = (a, b) => Js.Math.abs_float(a -. b) <= sameLane

// the lanes the keyboard leaves open under x, one entry per row that has a hole
// there
let lanesAt = (gaps: array<gap>, ~x) =>
  gaps->Belt.Array.reduce([], (lanes, gap) =>
    Js.Math.abs_float(gap.x -. x) > gap.halfWidth +. kerb ||
      lanes->Belt.Array.some(y => near(y, gap.y))
      ? lanes
      : lanes->Belt.Array.concat([gap.y])
  )

// how many samples running, from this one on, keep that lane open
let holds = (open_: array<array<float>>, ~from, ~lane) => {
  let i = ref(from)
  while (
    switch open_->Belt.Array.get(i.contents) {
    | Some(here) => here->Belt.Array.some(y => near(y, lane))
    | None => false
    }
  ) {
    i := i.contents + 1
  }
  i.contents - from
}

// The lane to aim for at one sample. Holding a lane costs nothing, so the car
// only leaves the one it is in when the keys close it — that alone keeps it off
// the fidgeting the nearest hole would otherwise have it do. When it must move,
// it takes the lane that stays open longest rather than the one that is nearest,
// so a hole one key wide never pulls it across the keyboard and straight back.
let pick = (open_, ~at, ~lane) => {
  let here = open_->Belt.Array.getUnsafe(at)
  switch here->Belt.Array.getBy(y => near(y, lane)) {
  | Some(y) => y // still open: stay in it, and centre on the key while there
  | None =>
    here
    ->Belt.Array.reduce(None, (best, y) =>
      switch best {
      | Some(b) =>
        let (bHolds, yHolds) = (holds(open_, ~from=at, ~lane=b), holds(open_, ~from=at, ~lane=y))
        yHolds > bHolds ||
          (yHolds == bHolds && Js.Math.abs_float(y -. lane) < Js.Math.abs_float(b -. lane))
          ? Some(y)
          : best
      | None => Some(y)
      }
    )
    ->Belt.Option.getWithDefault(lane)
  }
}

// Hold the line to a slope the car can be drawn on. Read backwards, each sample
// is pulled no further than a lean's worth from the one after it, which both
// caps the slope everywhere and sets the change of lane going early enough that
// the car arrives as the hole opens rather than a length past it. A hole too far
// off to reach becomes a lean towards it and no more, which is what a driver
// does with a gap they decide against.
let ease = (wanted, ~x, ~count) => {
  let lanes = Belt.Array.copy(wanted)
  let laneOf = i => lanes->Belt.Array.getUnsafe(i)
  for k in 1 to count - 3 {
    let i = count - 2 - k
    let ahead = laneOf(i + 1)
    let reach = maxSlope *. (x(i + 1) -. x(i))
    lanes->Belt.Array.setUnsafe(i, ahead +. clamp(laneOf(i) -. ahead, reach))
  }
  lanes
}

// Strike out the lanes the car aimed at and never made. A run of holes it leans
// towards and turns back from without ever once sitting in is a swerve that
// bought nothing, so it holds the lane it had instead and drives over the keys.
// Whether a run was made is read off the eased line rather than guessed at from
// the distance: two rows of holes close together still weave the car through
// both, and only the lunge that falls short is dropped. Reports whether it
// struck anything out, since dropping one run joins its neighbours and the rest
// have to be judged again against the line that leaves.
let settle = (wanted, ~x, ~count) => {
  let lanes = ease(wanted, ~x, ~count)
  let want = i => wanted->Belt.Array.getUnsafe(i)
  let struck = ref(false)
  let i = ref(1)
  while i.contents <= count - 2 {
    let from = i.contents
    while i.contents <= count - 2 && near(want(i.contents), want(from)) {
      i := i.contents + 1
    }
    let till = i.contents - 1

    // interior runs only — the first and last are how the car comes and goes —
    // and only where it doubles back to the lane it left
    if from > 1 && till < count - 2 && near(want(from - 1), want(till + 1)) {
      let made = Belt.Range.some(from, till, j => near(lanes->Belt.Array.getUnsafe(j), want(from)))
      if !made {
        let held = want(from - 1)
        for j in from to till {
          wanted->Belt.Array.setUnsafe(j, held)
        }
        struck := true
      }
    }
  }
  struck.contents
}

// The waypoints, sampled across the keyboard and bookended by a run-up and a
// run-out. `seen` is how much of the page is still on screen either side of the
// keyboard: the car sets off from beyond that and only stops once everything it
// tows has left, so it is never cut in half on its way in or out. `lane` is
// where it sits until the first hole claims it.
let build = (~gaps, ~width, ~lane, ~seenLeft, ~seenRight) => {
  let runUp = seenLeft +. carAhead
  let runOut = seenRight +. carBehind
  let steps = Js.Math.max_int(1, Js.Math.ceil_int(width /. sampleStep))
  let step = width /. Belt.Int.toFloat(steps)
  let count = steps + 3 // the samples across the keyboard, plus the two ends
  let x = i =>
    switch i {
    | 0 => -.runUp
    | i if i == count - 1 => width +. runOut
    | i => step *. Belt.Int.toFloat(i - 1)
    }

  // what the keyboard has open at each sample. The two ends are off it, so they
  // offer nothing and the car keeps whatever lane it has.
  let open_ = Belt.Array.makeBy(count, i => i == 0 || i == count - 1 ? [] : lanesAt(gaps, ~x=x(i)))

  // the lane the car would sit in at each sample if it could be in two places at
  // once, before it is asked whether it can get there
  let wanted = Belt.Array.make(count, lane)
  let current = ref(lane)
  for i in 1 to count - 2 {
    current := pick(open_, ~at=i, ~lane=current.contents)
    wanted->Belt.Array.setUnsafe(i, current.contents)
  }

  // Drop the detours the car cannot make, until a pass finds nothing left to
  // drop. Each pass strikes out at least one run, so `count` of them is more than
  // it can ever need — the bound is there to make that plain, not to be reached.
  let struck = ref(true)
  let passes = ref(0)
  while struck.contents && passes.contents < count {
    struck := settle(wanted, ~x, ~count)
    passes := passes.contents + 1
  }
  // then lay the line down over what is left of the plan
  let lanes = ease(wanted, ~x, ~count)
  let laneOf = i => lanes->Belt.Array.getUnsafe(i)
  // the two ends are off the keyboard entirely, so level the car there instead
  // of letting it swerve in and out of view
  lanes->Belt.Array.setUnsafe(0, laneOf(1))
  lanes->Belt.Array.setUnsafe(count - 1, laneOf(count - 2))

  // the running time price of the drive, climbs included, so a waypoint's share
  // of the animation is the share of the work it takes to reach it
  let spent = Belt.Array.make(count, 0.0)
  for i in 1 to count - 1 {
    let leg = x(i) -. x(i - 1) +. climb *. Js.Math.abs_float(laneOf(i) -. laneOf(i - 1))
    spent->Belt.Array.setUnsafe(i, spent->Belt.Array.getUnsafe(i - 1) +. leg)
  }
  let total = spent->Belt.Array.getUnsafe(count - 1)

  // how steeply the road runs out of a waypoint, in degrees
  let slope = i => {
    let run = x(i + 1) -. x(i)
    run <= 0.0 ? 0.0 : Js.Math.atan((laneOf(i + 1) -. laneOf(i)) /. run) *. 180.0 /. Js.Math._PI
  }
  {
    seconds: total /. speed,
    // the car sits on the corner it is turning: halfway between the slope it
    // comes in on and the one it leaves on, so it leans into a change of lane
    // over the sample before it and comes level over the sample after
    stops: Belt.Array.makeBy(count, i => {
      let into = slope(i == 0 ? 0 : i - 1)
      let outOf = slope(i == count - 1 ? count - 2 : i)
      {
        at: spent->Belt.Array.getUnsafe(i) /. total *. 100.0,
        x: x(i),
        y: laneOf(i),
        tilt: clamp((into +. outOf) /. 2.0, maxTilt),
      }
    }),
  }
}

let round = v => Js.Float.toFixedWithPrecision(v, ~digits=1)

// "x,y x,y …", the road inked in under the car
let polyline = drive =>
  drive.stops->Belt.Array.map(s => round(s.x) ++ "," ++ round(s.y))->Js.Array2.joinWith(" ")

// The drive, written out as CSS. The route is measured, so the keyframes are
// too: each is timed by the work it takes to reach it, so the car holds one
// speed along the flat and drags itself over the changes of lane. The tilt
// rides a second animation of the same length, so that what the car tows can
// stay level while the car itself leans.
let keyframes = drive => {
  let frames = (property, value) =>
    drive.stops
    ->Belt.Array.map(s => `  ${round(s.at)}% { ${property}: ${value(s)}; }`)
    ->Js.Array2.joinWith("\n")
  let move = frames("transform", s => `translate(${round(s.x)}px, ${round(s.y)}px)`)
  let tilt = frames("rotate", s => `${round(s.tilt)}deg`)
  `@keyframes cinque-drive {\n${move}\n}\n@keyframes cinque-tilt {\n${tilt}\n}\n`
}

// what the drive needs from the measurement: how wide to open the clip either
// side of the keyboard, how long a lap takes, and the still frame that reduced
// motion parks on
let cssVars = (drive, ~seenLeft, ~seenRight) => {
  let vars = Js.Dict.empty()
  vars->Js.Dict.set("--drive-left", round(-.seenLeft) ++ "px")
  vars->Js.Dict.set("--drive-right", round(-.seenRight) ++ "px")
  vars->Js.Dict.set("--drive-secs", round(drive.seconds) ++ "s")
  switch drive.stops->Belt.Array.get(drive.stops->Belt.Array.length / 2) {
  | Some(parked) => {
      vars->Js.Dict.set("--park-x", round(parked.x) ++ "px")
      vars->Js.Dict.set("--park-y", round(parked.y) ++ "px")
      vars->Js.Dict.set("--park-tilt", round(parked.tilt) ++ "deg")
    }
  | None => ()
  }
  vars
}
