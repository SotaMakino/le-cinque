open Vitest

// three lanes of 48px keys, the way the keyboard stacks its rows, with the
// keyboard sitting 100px in from either edge of the screen
let topLane = 24.0
let midLane = 78.0
let lowLane = 132.0
let gapsAt = (lane, xs) => xs->Belt.Array.map(x => {VictoryRoad.x, y: lane, halfWidth: 20.0})
let width = 400.0
let seen = 100.0
// a whole row of keys emptied between two x's, spaced the way the keyboard
// spaces them: 42px wide with 5px of keyboard left standing between
let pitch = 47.0
let rowFrom = (lane, ~from, ~to_) =>
  Belt.Array.makeBy(Belt.Float.toInt((to_ -. from) /. pitch) + 1, i => {
    VictoryRoad.x: from +. pitch *. Belt.Int.toFloat(i),
    y: lane,
    halfWidth: 21.0,
  })
let drive = gaps => VictoryRoad.build(~gaps, ~width, ~lane=midLane, ~seenLeft=seen, ~seenRight=seen)
let lanes = (d: VictoryRoad.drive) => d.stops->Belt.Array.map((s: VictoryRoad.stop) => s.y)
let stop = (d: VictoryRoad.drive, i) => d.stops->Belt.Array.getExn(i)
let last = (d: VictoryRoad.drive) => d.stops->Belt.Array.length - 1
// the stops the car makes on the keyboard itself, run-up and run-out dropped
let onTheKeys = (d: VictoryRoad.drive) =>
  d.stops->Belt.Array.keep((s: VictoryRoad.stop) => s.x >= 0.0 && s.x <= width)

describe("VictoryRoad.build", () => {
  test("sets off and pulls up far enough out that nothing is cut in half", t => {
    let d = drive([])
    // the nose clears the screen on the way in, the towed tricolore on the way out
    t->expect(stop(d, 0).x)->Expect.toBe(-.(seen +. VictoryRoad.carAhead))
    t->expect(stop(d, last(d)).x)->Expect.toBe(width +. seen +. VictoryRoad.carBehind)
  })

  test("keeps one speed along the flat: time spent matches ground covered", t => {
    let d = drive([])
    t->expect(stop(d, 0).at)->Expect.toBe(0.0)
    t->expect(stop(d, last(d)).at)->Expect.toBe(100.0)
    let pace = i => (stop(d, i + 1).x -. stop(d, i).x) /. (stop(d, i + 1).at -. stop(d, i).at)
    t->expect(Js.Math.abs_float(pace(0) -. pace(3)) < 0.001)->Expect.toBeTruthy
    t
    ->expect(d.seconds)
    ->Expect.toBe(
      (width +. 2.0 *. seen +. VictoryRoad.carAhead +. VictoryRoad.carBehind) /. VictoryRoad.speed,
    )
  })

  test("labours up the hill: the leg that changes lane costs more than a flat one", t => {
    let d = drive(
      Belt.Array.concat(
        rowFrom(topLane, ~from=0.0, ~to_=160.0),
        rowFrom(lowLane, ~from=280.0, ~to_=width),
      ),
    )
    let ground = i => stop(d, i + 1).x -. stop(d, i).x
    let time = i => stop(d, i + 1).at -. stop(d, i).at
    // the samples across the keys are evenly spaced, so every leg between them
    // covers the same ground: the ones that also change lane cost more time
    let legs = Belt.Array.makeBy(last(d) - 2, i => i + 1)
    let (flat, hill) = legs->Belt.Array.partition(i => stop(d, i).y == stop(d, i + 1).y)
    t->expect(hill->Belt.Array.length > 0)->Expect.toBeTruthy
    t->expect(flat->Belt.Array.length > 0)->Expect.toBeTruthy
    let sameGround = (a, b) => Js.Math.abs_float(ground(a) -. ground(b)) < 0.001
    t
    ->expect(hill->Belt.Array.every(h => flat->Belt.Array.every(f => sameGround(f, h))))
    ->Expect.toBeTruthy
    let slowest = flat->Belt.Array.reduce(0.0, (m, i) => Js.Math.max_float(m, time(i)))
    t->expect(hill->Belt.Array.every(i => time(i) > slowest))->Expect.toBeTruthy
    // and the whole lap is longer than the flat ground alone would take
    t
    ->expect(d.seconds *. VictoryRoad.speed > stop(d, last(d)).x -. stop(d, 0).x)
    ->Expect.toBeTruthy
  })

  test("changes lane no faster than the car can be drawn leaning", t => {
    let d = drive(
      Belt.Array.concat(
        rowFrom(topLane, ~from=0.0, ~to_=160.0),
        rowFrom(lowLane, ~from=280.0, ~to_=width),
      ),
    )
    let steepest = Belt.Array.makeBy(
      last(d),
      i => {
        let run = stop(d, i + 1).x -. stop(d, i).x
        Js.Math.abs_float(stop(d, i + 1).y -. stop(d, i).y) /. run
      },
    )->Belt.Array.reduce(0.0, Js.Math.max_float)
    t->expect(steepest <= VictoryRoad.maxSlope +. 0.001)->Expect.toBeTruthy
    // and it really is changing lane, not just creeping
    t->expect(steepest > VictoryRoad.maxSlope /. 2.0)->Expect.toBeTruthy
  })

  test("arrives in the new lane as the hole opens, not a length past it", t => {
    let d = drive(
      Belt.Array.concat(
        rowFrom(topLane, ~from=0.0, ~to_=100.0),
        rowFrom(lowLane, ~from=260.0, ~to_=width),
      ),
    )
    // the first sample the lower row covers must already find the car in it
    switch onTheKeys(d)->Belt.Array.getBy((s: VictoryRoad.stop) => s.x >= 260.0) {
    | Some(s) => t->expect(s.y)->Expect.toBe(lowLane)
    | None => t->expect("a sample past the second row")->Expect.toBe("none found")
    }
  })

  test("does not fall down the crack between two vacated keys", t => {
    // the top row emptied whole, over a lower row emptied whole as well: the
    // samples that land on the keyboard left standing between two top keys must
    // not read the lane as closed and pitch the car down a row
    let d = drive(
      Belt.Array.concat(
        rowFrom(topLane, ~from=0.0, ~to_=width),
        gapsAt(lowLane, Belt.Array.makeBy(17, i => 100.0 +. 20.0 *. Belt.Int.toFloat(i))),
      ),
    )
    t->expect(lanes(d)->Belt.Array.every(y => y == topLane))->Expect.toBeTruthy
  })

  test("does not lunge at a row it has no run to reach", t => {
    // the top row emptied but for a stretch in the middle, and a short run of
    // holes in the bottom row under that stretch. Two rows is further than the
    // car can drop and climb again in the length it has, so it would only lean
    // at those holes and turn back: better to hold the lane and drive the keys.
    let d = drive(
      Belt.Array.concat(
        Belt.Array.concat(
          rowFrom(topLane, ~from=0.0, ~to_=140.0),
          rowFrom(topLane, ~from=260.0, ~to_=width),
        ),
        gapsAt(lowLane, [180.0, 200.0, 220.0]),
      ),
    )
    t->expect(lanes(d)->Belt.Array.every(y => y == topLane))->Expect.toBeTruthy
  })

  test("keeps the detour it does have the run to make", t => {
    // the same shape with room to do it in: now the car drops to the lower row,
    // spends a while down there, and climbs back for the rest of the top row
    let d = VictoryRoad.build(
      ~gaps=Belt.Array.concat(
        Belt.Array.concat(
          rowFrom(topLane, ~from=0.0, ~to_=100.0),
          rowFrom(topLane, ~from=800.0, ~to_=900.0),
        ),
        rowFrom(lowLane, ~from=300.0, ~to_=600.0),
      ),
      ~width=900.0,
      ~lane=midLane,
      ~seenLeft=seen,
      ~seenRight=seen,
    )
    t->expect(lanes(d))->Expect.toContain(lowLane)
    t->expect(stop(d, 0).y)->Expect.toBe(topLane)
    t->expect(stop(d, last(d)).y)->Expect.toBe(topLane)
  })

  test("takes the lane that lasts over the lane that is near", t => {
    // the middle lane is shut the whole way; just above it a hole opens and
    // closes again, while the lower row stays open all across. Chasing the near
    // one would have the car climb and turn straight back around.
    let nearLane = 60.0
    let d = drive(
      Belt.Array.concat(
        gapsAt(nearLane, [0.0, 40.0, 80.0]),
        rowFrom(lowLane, ~from=0.0, ~to_=width),
      ),
    )
    t->expect(lanes(d)->Belt.Array.every(y => y >= midLane))->Expect.toBeTruthy
    t->expect(stop(d, last(d)).y)->Expect.toBe(lowLane)
  })

  test("reads the keyboard finely enough to catch a single emptied key", t => {
    let d = drive([])
    // a key is 42px wide, so no emptied one can slip between two samples
    t->expect(onTheKeys(d)->Belt.Array.length > Belt.Float.toInt(width /. 42.0))->Expect.toBeTruthy
  })

  test("holds its lane and stays level where the keyboard has no gaps at all", t => {
    let d = drive([])
    t->expect(lanes(d)->Belt.Array.every(y => y == midLane))->Expect.toBeTruthy
    t->expect(d.stops->Belt.Array.every(s => s.tilt == 0.0))->Expect.toBeTruthy
  })

  test("drives the gaps: a clear run of them pulls the car onto that lane", t => {
    let d = drive(
      gapsAt(topLane, [0.0, 40.0, 80.0, 120.0, 160.0, 200.0, 240.0, 280.0, 320.0, 360.0, 400.0]),
    )
    t->expect(lanes(d)->Belt.Array.every(y => y == topLane))->Expect.toBeTruthy
  })

  test("changes lane where the gaps do", t => {
    let d = drive(
      Belt.Array.concat(
        gapsAt(topLane, [0.0, 40.0, 80.0, 120.0]),
        gapsAt(lowLane, [280.0, 320.0, 360.0, 400.0]),
      ),
    )
    t->expect(lanes(d))->Expect.toContain(topLane)
    t->expect(lanes(d))->Expect.toContain(lowLane)
    // the run-up and the run-out are off the keyboard: no swerving into view
    t->expect(stop(d, 0).y)->Expect.toBe(stop(d, 1).y)
    t->expect(stop(d, last(d)).y)->Expect.toBe(stop(d, last(d) - 1).y)
  })

  test("noses over on the change of lane, but never past the tilt limit", t => {
    let d = drive(Belt.Array.concat(gapsAt(topLane, [40.0]), gapsAt(lowLane, [360.0])))
    let tilts = d.stops->Belt.Array.map((s: VictoryRoad.stop) => s.tilt)
    t->expect(tilts->Belt.Array.some(tilt => tilt > 0.0))->Expect.toBeTruthy
    t
    ->expect(tilts->Belt.Array.every(tilt => Js.Math.abs_float(tilt) <= VictoryRoad.maxTilt))
    ->Expect.toBeTruthy
  })
})

describe("VictoryRoad css", () => {
  test("writes the route out as one point per waypoint", t => {
    let d = drive([])
    let points = VictoryRoad.polyline(d)->Js.String2.split(" ")
    t->expect(points->Belt.Array.length)->Expect.toBe(d.stops->Belt.Array.length)
    t->expect(points->Belt.Array.getExn(0))->Expect.toBe("-132.0,78.0")
  })

  test("writes both keyframe rules, one frame per waypoint", t => {
    let d = drive([])
    let css = VictoryRoad.keyframes(d)
    t->expect(css)->Expect.String.toContain("@keyframes cinque-drive")
    t->expect(css)->Expect.String.toContain("@keyframes cinque-tilt")
    t->expect(css)->Expect.String.toContain("0.0% { transform: translate(-132.0px, 78.0px); }")
    t->expect(css)->Expect.String.toContain("100.0% { rotate: 0.0deg; }")
  })

  test("hands the stylesheet the clip, the pace, and the still frame", t => {
    let d = drive([])
    let vars = VictoryRoad.cssVars(d, ~seenLeft=seen, ~seenRight=seen)
    t->expect(vars->Js.Dict.get("--drive-left"))->Expect.toEqual(Some("-100.0px"))
    t->expect(vars->Js.Dict.get("--drive-right"))->Expect.toEqual(Some("-100.0px"))
    t->expect(vars->Js.Dict.get("--drive-secs"))->Expect.toEqual(Some("5.4s"))
    t->expect(vars->Js.Dict.get("--park-y"))->Expect.toEqual(Some("78.0px"))
  })
})
