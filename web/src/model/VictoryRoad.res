// The road a won round leaves behind. Every letter that reaches the board takes
// its key off the keyboard, so the holes left standing spell out a different
// track after every win. The car reads them left to right and changes lane to
// keep to the empty keys.

// a vacated key, measured in the keyboard box's own coordinates
type gap = {x: float, y: float, halfWidth: float}

// one waypoint of the drive: how far through it is, where the car is, and how
// far the car is nosing over
type stop = {at: float, x: float, y: float, tilt: float}

type drive = {stops: array<stop>, seconds: float}

let sampleStep = 40.0 // how finely the keyboard is read for holes
// a Cinquecento is no rally car, and it leans no further than still fits
// between the top and bottom rows of keys
let maxTilt = 15.0
let speed = 150.0 // px per second on the flat, whatever the screen is wide
// Eighteen horses did not take a hill quickly. A pixel of climb — or of coming
// back down it — costs the car as much time as a pixel of going along, so it
// labours up the change of lane and picks the pace back up on the straight.
let climb = 1.0
let carAhead = 32.0 // the nose, ahead of the waypoint…
let carBehind = 175.0 // …and the tail of the tricolore, behind it

// the gap sitting under x that costs the car the smallest change of lane, so it
// stays on a straight run for as long as the holes allow
let laneAt = (gaps: array<gap>, ~x, ~lane) =>
  gaps->Belt.Array.reduce(None, (best, gap) =>
    if Js.Math.abs_float(gap.x -. x) > gap.halfWidth {
      best
    } else {
      switch best {
      | Some(y) if Js.Math.abs_float(y -. lane) <= Js.Math.abs_float(gap.y -. lane) => best
      | _ => Some(gap.y)
      }
    }
  )

let clamp = (v, limit) => v > limit ? limit : v < -.limit ? -.limit : v

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

  let lanes = Belt.Array.make(count, lane)
  let current = ref(lane)
  for i in 1 to count - 2 {
    switch laneAt(gaps, ~x=x(i), ~lane=current.contents) {
    | Some(y) => current := y
    | None => () // no hole here: hold the lane and drive over the keys
    }
    lanes->Belt.Array.setUnsafe(i, current.contents)
  }
  // the two ends are off the keyboard entirely, so level the car there instead
  // of letting it swerve in and out of view
  let laneOf = i => {
    let i = i == 0 ? 1 : i == count - 1 ? count - 2 : i
    lanes->Belt.Array.get(i)->Belt.Option.getWithDefault(lane)
  }

  // the running time price of the drive, climbs included, so a waypoint's share
  // of the animation is the share of the work it takes to reach it
  let spent = Belt.Array.make(count, 0.0)
  for i in 1 to count - 1 {
    let leg = x(i) -. x(i - 1) +. climb *. Js.Math.abs_float(laneOf(i) -. laneOf(i - 1))
    spent->Belt.Array.setUnsafe(i, spent->Belt.Array.getUnsafe(i - 1) +. leg)
  }
  let total = spent->Belt.Array.getUnsafe(count - 1)
  {
    seconds: total /. speed,
    stops: Belt.Array.makeBy(count, i => {
      // tilt follows the slope through the waypoint: the segments either side
      // of it, or the single one an end has
      let back = i == 0 ? i : i - 1
      let ahead = i == count - 1 ? i : i + 1
      let run = x(ahead) -. x(back)
      let tilt =
        run <= 0.0
          ? 0.0
          : clamp(
              Js.Math.atan((laneOf(ahead) -. laneOf(back)) /. run) *. 180.0 /. Js.Math._PI,
              maxTilt,
            )
      {
        at: spent->Belt.Array.getUnsafe(i) /. total *. 100.0,
        x: x(i),
        y: laneOf(i),
        tilt,
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
