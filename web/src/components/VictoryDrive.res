// The victory lap. A won round has emptied every letter of the five words off
// the keyboard, and the holes they left are a road: a yellow Cinquecento drives
// it from left to right, towing a tricolore that reads Congratulazioni!. The
// route is measured from the keys themselves, so no two wins drive the same one.

let message = "Congratulazioni!"

type drive = {
  width: float,
  height: float,
  seenLeft: float,
  seenRight: float,
  road: VictoryRoad.drive,
}

// A Fiat 500 seen from the side, drawn over 100 units of its length and 45 of
// its height off the road — near enough the real 2970mm by 1325mm, drawn a
// touch longer and rounder than that, because a car this small on the page
// reads better as an oval than as an accurate stubby box. What is kept from the
// real thing is where the weight sits: the cabin is half the car and it sits
// over the back axle, the roof is a dome with no flat in it, and the nose is
// barely a nose — a short deck off the windscreen that rounds over almost at
// once. The whole upper line from the tail to the windscreen is one continuous
// sweep, broken only where a car has to break: at the screen header and at the
// scuttle. The beltline sits at 15.2 and the sill at 38.0, which leaves the
// flank enough metal that the car does not read as a slim one. The wheels are
// little 12" ones set close under the body, with arches cut to clear them and
// no more, and the front one pushed well out to 84.5 so there is barely any
// wing left between it and the bumper.
let body = "M 5.3,38.0 C 2.8,37.6 1.4,35.8 1.4,33.0 \
C 1.4,28.6 2.5,23.8 4.9,19.6 C 8.9,13.8 14.6,8.4 21.2,4.7 \
C 28.4,1.7 36.8,0.4 45.4,0.4 C 54.0,0.4 60.6,1.5 65.2,3.5 \
C 68.2,7.0 70.6,11.0 72.5,15.2 C 78.0,15.4 83.4,16.0 88.2,17.0 \
C 94.4,18.8 99.0,22.2 101.2,27.4 C 101.6,29.8 101.7,31.8 101.6,33.8 \
C 101.5,36.4 99.9,37.7 97.4,38.0 \
L 92.5,38.0 A 8.2,8.2 0 1,0 76.5,38.0 \
L 28.0,38.0 A 8.2,8.2 0 1,0 12.0,38.0 Z"
// The greenhouse as one pane, running the whole cabin from the windscreen back
// to where the rear screen lies down on the tail. In a true side view the
// pillars between them are edge-on and have no width worth filling, so they are
// drawn as seams over the glass rather than cut out of it — which also keeps
// them from flashing as bright slivers when the car is only 60px long. Along
// the beltline they fall at C 20.0, B 38.6, A 65.2, which leaves the rear
// window a shade under seven tenths of the door window beside it.
let glass = "M 63.4,5.3 C 66.2,8.6 68.4,11.9 70.2,15.2 L 20.0,15.2 \
C 21.8,11.6 24.0,8.2 26.6,5.6 C 36.6,3.2 52.0,3.0 63.4,5.3 Z"
let pillar = "M 58.4,5.1 C 61.2,8.4 63.4,11.7 65.2,15.3" // the windscreen post
// the door, shut line running from the roof rail down past the glass to the sill
let doorSeam = "M 40.0,3.5 C 39.2,7.9 38.8,11.6 38.6,15.3 \
C 38.8,22.0 39.0,27.0 39.2,31.6"

// One wheel: tyre, body-coloured steel rim, hub cap, and the vents that make
// the spin read at this size. Drawn where it stands rather than translated
// into place, because the CSS that spins it owns the transform.
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

@react.component
let make = () => {
  let root = React.useRef(Js.Nullable.null)
  let (drive, setDrive) = React.useState(() => None)

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
              <path className="cinque-body" d=body />
              <path className="cinque-glass" d=glass />
              <path className="cinque-seam" d=pillar />
              <path className="cinque-seam" d=doorSeam />
              <line className="cinque-seam" x1="58" y1="19" x2="62" y2="19" />
              <ellipse className="cinque-lamp" cx="93" cy="23.4" rx="2.5" ry="3" />
              <ellipse className="cinque-tail" cx="4.8" cy="27.6" rx="1.2" ry="1.8" />
              <line className="cinque-bumper" x1="96" y1="33.8" x2="101" y2="33.8" />
              <line className="cinque-bumper" x1="2" y1="33.8" x2="7" y2="33.8" />
              {wheel(20.0)}
              {wheel(84.5)}
            </svg>
          </div>
        </div>
      </>
    }}
  </div>
}
