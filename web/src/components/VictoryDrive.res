// The victory lap. A won round has emptied the keyboard of every letter that
// had somewhere to go, and the holes they left are a road: a little Italian car
// drives it from left to right, towing a tricolore. The route is measured from
// the keys themselves, and the car, its paint and what the tricolore says are
// all drawn at the win, so no two laps are the same one twice.

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
  // drawn once, at the win: the lap keeps the car it was dealt for as long as
  // the round stays won
  let car = React.useMemo0(() => VictoryCar.anyOf(VictoryCar.cars))
  let paint = React.useMemo0(() => VictoryCar.anyOf(VictoryCar.paints))
  let message = React.useMemo0(() => VictoryCar.anyOf(VictoryCar.messages))
  let (rear, front) = car.axles

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
  style->Js.Dict.set("--car-body", paint.body)
  style->Js.Dict.set("--car-hub", paint.hub)

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
          <div className="victory-lane">
            <span className="cinque-banner"> {React.string(message)} </span>
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
        </div>
      </>
    }}
  </div>
}
