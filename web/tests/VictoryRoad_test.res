open Vitest

// three lanes of 48px keys, the way the keyboard stacks its rows, with the
// keyboard sitting 100px in from either edge of the screen
let topLane = 24.0
let midLane = 78.0
let lowLane = 132.0
let gapsAt = (lane, xs) => xs->Belt.Array.map(x => {VictoryRoad.x, y: lane, halfWidth: 20.0})
let width = 400.0
let seen = 100.0
let drive = gaps => VictoryRoad.build(~gaps, ~width, ~lane=midLane, ~seenLeft=seen, ~seenRight=seen)
let lanes = (d: VictoryRoad.drive) => d.stops->Belt.Array.map((s: VictoryRoad.stop) => s.y)
let stop = (d: VictoryRoad.drive, i) => d.stops->Belt.Array.getExn(i)
let last = (d: VictoryRoad.drive) => d.stops->Belt.Array.length - 1

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

  test("labours up the hill: a change of lane takes longer than the flat before it", t => {
    let d = drive(Belt.Array.concat(gapsAt(topLane, [80.0]), gapsAt(lowLane, [120.0])))
    let ground = i => stop(d, i + 1).x -. stop(d, i).x
    let time = i => stop(d, i + 1).at -. stop(d, i).at
    // the samples sit 40px apart, so any two neighbouring legs cover the same
    // ground: the one that also drops a row is the one that costs more time
    let (flat, hill) = (2, 3)
    t->expect(Js.Math.abs_float(ground(flat) -. ground(hill)) < 0.001)->Expect.toBeTruthy
    t->expect(stop(d, hill).y == stop(d, hill + 1).y)->Expect.toBeFalsy
    t->expect(time(hill) > time(flat) *. 1.5)->Expect.toBeTruthy
    // and the whole lap is longer than the flat ground alone would take
    t
    ->expect(d.seconds *. VictoryRoad.speed > stop(d, last(d)).x -. stop(d, 0).x)
    ->Expect.toBeTruthy
  })

  test("reads the keyboard finely enough to catch a single emptied key", t => {
    let d = drive([])
    let acrossTheKeys = d.stops->Belt.Array.keep(s => s.x >= 0.0 && s.x <= width)
    t
    ->expect(acrossTheKeys->Belt.Array.length > Belt.Float.toInt(width /. 48.0))
    ->Expect.toBeTruthy
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
