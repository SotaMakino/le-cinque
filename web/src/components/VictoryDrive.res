// The victory lap. A won round has emptied the keyboard of every letter that
// had somewhere to go, and the holes they left are a road: a little Italian car
// drives it from left to right, towing a tricolore. The route is measured from
// the keys themselves, and the car, its paint and what the tricolore says are
// all drawn at the win, so no two laps are the same one twice.
//
// A round won on the back of others brings them with it: the streak in
// WinStreak — the browser's own count, which no server is told — puts one car on
// the road per win, up to what the road holds. They all drive the one route,
// each further back along it than the last, so the convoy takes the leader's
// line through the same holes. The leader is the one towing the flag.

type drive = {
  width: float,
  height: float,
  seenLeft: float,
  seenRight: float,
  road: VictoryRoad.drive,
}

// One wheel: tyre, body-coloured steel rim, hub cap, and the vents that make the
// spin read at this size. Drawn where it stands rather than translated into
// place, because the CSS that spins it owns the transform.
let wheel = axle => {
  let at = v => Belt.Float.toString(axle +. v)
  <g className="cinque-wheel">
    <circle cx={at(0.0)} cy="37" r="7.9" className="cinque-tyre" />
    <circle cx={at(0.0)} cy="37" r="5.1" className="cinque-rim" />
    <circle cx={at(0.0)} cy="33.6" r="0.75" className="cinque-vent" />
    <circle cx={at(3.4)} cy="37" r="0.75" className="cinque-vent" />
    <circle cx={at(0.0)} cy="40.4" r="0.75" className="cinque-vent" />
    <circle cx={at(-3.4)} cy="37" r="0.75" className="cinque-vent" />
    <circle cx={at(0.0)} cy="37" r="1.8" className="cinque-hub" />
  </g>
}

let strokes = (className, paths) =>
  paths
  ->Belt.Array.mapWithIndex((i, d) => <path key={i->Belt.Int.toString} className d />)
  ->React.array

@react.component
let make = () => {
  let root = React.useRef(Js.Nullable.null)
  let (drive, setDrive) = React.useState(() => None)
  // Dealt once, at the win: the lap keeps the convoy it was given for as long as
  // the round stays won. One car per win in the streak, each with its own shape
  // and its own coat of paint, so five in a row is five different cars.
  let convoy = React.useMemo0(() =>
    Belt.Array.makeBy(WinStreak.cars(WinStreak.current()), _ => (
      VictoryCar.anyOf(VictoryCar.cars),
      VictoryCar.anyOf(VictoryCar.paints),
    ))
  )
  let message = React.useMemo0(() => VictoryCar.anyOf(VictoryCar.messages))

  // the keyboard is the canvas: measure it, then every key that has left it
  let measure = () =>
    switch root.current->Js.Nullable.toOption {
    | None => ()
    | Some(el) =>
      switch el->DomBindings.parentElement {
      | None => ()
      | Some(keyboard) =>
        let box = keyboard->DomBindings.boundingRect
        let gaps =
          keyboard
          ->DomBindings.queryAll(".key.used, .key.absent")
          ->DomBindings.nodeArray
          ->Belt.Array.map(key => {
            let r = key->DomBindings.boundingRect
            {
              VictoryRoad.x: r.left -. box.left +. r.width /. 2.0,
              y: r.top -. box.top +. r.height /. 2.0,
              halfWidth: r.width /. 2.0,
            }
          })
        // how much page is left either side of the keyboard: the car drives on
        // until it is off the screen, not just off the keys
        let seenLeft = box.left
        let seenRight = Belt.Int.toFloat(DomBindings.clientWidth) -. (box.left +. box.width)
        setDrive(_ => Some({
          width: box.width,
          height: box.height,
          seenLeft,
          seenRight,
          road: VictoryRoad.build(
            ~gaps,
            ~width=box.width,
            ~lane=box.height /. 2.0,
            ~seenLeft,
            ~seenRight,
          ),
        }))
      }
    }

  // measure before the browser paints, so the car never flashes at the origin;
  // the keys reflow on a resize, and the road with them
  React.useLayoutEffect0(() => {
    measure()
    let remeasure = () => measure()
    DomBindings.addWindowListener("resize", remeasure)
    Some(() => DomBindings.removeWindowListener("resize", remeasure))
  })

  // the clip reaches the edges of the screen, so nothing is ever cut in half
  // short of leaving it
  let style = switch drive {
  | Some(d) => VictoryRoad.cssVars(d.road, ~seenLeft=d.seenLeft, ~seenRight=d.seenRight)
  | None => Js.Dict.empty()
  }

  // one lane per car: the same drive, started later the further back the car is,
  // and its own paint. The delay is what strings them out along the road; the
  // pixels beside it are where the car stands when the drive is held still.
  let lane = (i, (car: VictoryCar.car, paint: VictoryCar.paint)) => {
    let (rear, front) = car.axles
    let laneStyle = Js.Dict.empty()
    laneStyle->Js.Dict.set("--car-body", paint.body)
    laneStyle->Js.Dict.set("--car-hub", paint.hub)
    laneStyle->Js.Dict.set("--car-delay", `${VictoryRoad.round(VictoryRoad.convoyDelay(i))}s`)
    laneStyle->Js.Dict.set("--car-back", `${VictoryRoad.round(VictoryRoad.convoyBack(i))}px`)
    <div key={i->Belt.Int.toString} className="victory-lane" style={laneStyle->Obj.magic}>
      // the flag is the leader's to tow; the rest of the convoy follows it
      {i == 0 ? <span className="cinque-banner"> {React.string(message)} </span> : React.null}
      <svg className="cinquecento" viewBox="-3 -3 109 51">
        <path className="cinque-body" d=car.body />
        <path className="cinque-glass" d=car.glass />
        {strokes("cinque-seam", car.seams)}
        <path className="cinque-lamp" d=car.lamp />
        <path className="cinque-tail" d=car.tail />
        {strokes("cinque-bumper", car.bumpers)}
        {wheel(rear)}
        {wheel(front)}
      </svg>
    </div>
  }

  <div
    className="victory-drive"
    ariaHidden=true
    style={style->Obj.magic}
    ref={ReactDOM.Ref.domRef(root)}>
    {switch drive {
    | None => React.null
    | Some(d) =>
      <>
        <style dangerouslySetInnerHTML={{"__html": VictoryRoad.keyframes(d.road)}} />
        // the stage is the keyboard box exactly, so the measured route needs no
        // offset
        <div className="victory-stage">
          <svg
            className="victory-track"
            viewBox={`0 0 ${VictoryRoad.round(d.width)} ${VictoryRoad.round(d.height)}`}>
            <polyline points={VictoryRoad.polyline(d.road)} />
          </svg>
          {convoy->Belt.Array.mapWithIndex(lane)->React.array}
        </div>
      </>
    }}
  </div>
}
