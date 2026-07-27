// Deep-dive win celebration. The masthead's bottom rule doubles as the ground
// the diver walks along and the surface of the sea. The diver strolls in level
// along that line and, just before the centre, takes one large jump and dives
// straight down; the page behind stays untouched until he plunges through the
// line, at which point the ocean fills the space below and a small depth gauge
// appears. His depth on that gauge reads the words-learned tally — the seabed is
// a full vocabulary. He stays at that depth, blowing a puff of bubbles now and
// then.

// the full curriculum size: the gauge runs 0 at the surface to this at the
// seabed. Kept in step with the progress bar denominator in AccountMenu.res.
let vocabTotal = 1500

// depthFrac maps the learned tally onto the gauge, 0 at the surface to 1 at the
// seabed. Linear, so the diver's depth reads the tally straight off the scale.
let depthFrac = learned =>
  Js.Math.min_float(1.0, Belt.Int.toFloat(learned) /. Belt.Int.toFloat(vocabTotal))

type phase =
  | Start // off to the side, before the walk begins
  | Enter // walking horizontally in along the surface line
  | Jump // one large jump just before the centre
  | Dive // plunging straight down below the surface
  | Bottom // righting at the reached depth
  | Done // holding at that depth; the summary is shown

// one bubble the diver has blown: a horizontal offset near the diver plus a size
// and rise duration, keyed by id so React can drop it once it has surfaced
type bubble = {id: int, left: float, size: float, dur: int}

type mediaQuery = {matches: bool}
@val @scope("window") external matchMedia: string => mediaQuery = "matchMedia"
@val @scope("window") external innerHeight: float = "innerHeight"

type domRect = {bottom: float}
@val @scope("document")
external querySelector: string => Js.Nullable.t<Dom.element> = "querySelector"
@send external getBoundingClientRect: Dom.element => domRect = "getBoundingClientRect"

// where the masthead rule sits, before it is measured
let defaultSeaLevel = () => innerHeight *. 0.17

@react.component
let make = (
  ~learned: int,
  ~message: string,
  ~countLabel: string,
  ~newGameLabel: string,
  ~busy: bool,
  ~onNewGame: unit => unit,
) => {
  let (phase, setPhase) = React.useState(() => Start)
  let (displayCount, setDisplayCount) = React.useState(() => 0)
  let (depth, setDepth) = React.useState(() => depthFrac(learned))
  let (seaLevel, setSeaLevel) = React.useState(() => defaultSeaLevel())
  // live bubbles the diver has blown; each is removed once it has risen
  let (bubbles, setBubbles) = React.useState(() => [])

  // the learned tally can land a moment after this overlay mounts (the win
  // handler refetches /me), so read it through a ref at the instant the dive
  // starts rather than latching a possibly-stale value on mount.
  let learnedRef = React.useRef(learned)
  React.useEffect1(() => {
    learnedRef.current = learned
    None
  }, [learned])

  // the surface line = the masthead's bottom rule. Measure it before paint so the
  // diver's feet land on the real line rather than a guess.
  React.useLayoutEffect0(() => {
    switch querySelector(".app-header")->Js.Nullable.toOption {
    | Some(el) => setSeaLevel(_ => getBoundingClientRect(el).bottom)
    | None => ()
    }
    None
  })

  React.useEffect0(() => {
    let reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    if reduced {
      // no choreography: settle straight onto the resolved figure
      let t = learnedRef.current
      setDisplayCount(_ => t)
      setDepth(_ => depthFrac(t))
      setPhase(_ => Done)
      None
    } else {
      let timers = []
      let after = (ms, cb) => Js.Array2.push(timers, Js.Global.setTimeout(cb, ms))->ignore

      // walk horizontally along the line, then spring up to the jump apex
      after(30, () => setPhase(_ => Enter))
      after(1550, () => setPhase(_ => Jump))

      // plunge: continues straight down from the apex through the surface without
      // touching back down, so the diver never pauses at the waterline
      after(1870, () => {
        let t = learnedRef.current
        let d = depthFrac(t)
        setDepth(_ => d)
        setPhase(_ => Dive)

        let diveDur = 1400.0 +. d *. 1500.0

        // tick the tally up as the diver sinks, finishing as it reaches depth
        if t > 0 {
          let ticks = Js.Math.max_float(1.0, diveDur /. 40.0)
          let inc = Js.Math.ceil_int(Belt.Int.toFloat(t) /. ticks)
          let id = Js.Global.setInterval(
            () => {
              setDisplayCount(
                prev => {
                  let next = prev + inc
                  next >= t ? t : next
                },
              )
            },
            40,
          )
          Js.Array2.push(
            timers,
            Js.Global.setTimeout(() => Js.Global.clearInterval(id), Belt.Float.toInt(diveDur) + 80),
          )->ignore
        }

        // reach the depth, right the diver, then stay there with the summary
        let diveMs = Belt.Float.toInt(diveDur)
        Js.Array2.push(timers, Js.Global.setTimeout(() => setPhase(_ => Bottom), diveMs))->ignore
        Js.Array2.push(
          timers,
          Js.Global.setTimeout(
            () => {
              setDisplayCount(_ => learnedRef.current)
              setPhase(_ => Done)
            },
            diveMs + 700,
          ),
        )->ignore
      })

      Some(() => timers->Belt.Array.forEach(Js.Global.clearTimeout))
    }
  })

  let seabed = innerHeight -. 26.0
  let span = seabed -. seaLevel
  let surfaceCenter = seaLevel -. 30.0 // feet resting on the line
  // just below the surface at depth 0 (so the plunge always reads as a dive),
  // down to just above the seabed at depth 1
  let diveCenter = surfaceCenter +. 70.0 +. depth *. (span -. 88.0)
  let diveDurMs = Belt.Float.toInt(1400.0 +. depth *. 1500.0)

  // per phase: diver centre y (px), horizontal position (%), move duration (ms).
  // The walk runs level along the line to just shy of centre; the single jump
  // carries the diver onto the centre; the dive drops straight down to depth,
  // where the diver stays.
  let (centerY, leftPct, moveMs) = switch phase {
  // 0ms so the one-off sea-level measurement snaps into place without animating
  // into a stray vertical hop before the walk
  | Start => (surfaceCenter, 3.0, 0)
  | Enter => (surfaceCenter, 44.0, 1500)
  // the jump is a real leap: rise to an apex above the line, then the dive falls
  // straight down from there through the surface — one continuous arc, no pause
  | Jump => (surfaceCenter -. 52.0, 50.0, 320)
  | Dive => (diveCenter, 50.0, diveDurMs)
  | Bottom => (diveCenter, 50.0, 600)
  | Done => (diveCenter, 50.0, 600)
  }

  // the gauge badge reads the diver's depth; it and the diver both hold there
  let markerY = switch phase {
  | Start | Enter | Jump => surfaceCenter
  | Dive | Bottom | Done => diveCenter
  }

  let phaseClass = switch phase {
  | Start | Enter => "is-walking"
  | Jump => "is-jumping"
  | Dive => "is-diving"
  | Bottom | Done => "is-floating"
  }

  // the sea background arrives with the jump; the gauge and bubbles wait until
  // the diver is actually underwater
  let seaVisible = switch phase {
  | Start | Enter => false
  | Jump | Dive | Bottom | Done => true
  }
  let underwater = switch phase {
  | Start | Enter | Jump => false
  | Dive | Bottom | Done => true
  }

  // blow a puff of bubbles from time to time while the diver rests at depth
  React.useEffect1(() => {
    if underwater {
      let puff = () => {
        let stamp = Js.Date.now()->Belt.Float.toInt
        let n = 2 + Js.Math.random_int(0, 3)
        let fresh = Belt.Array.makeBy(n, i => {
          id: stamp + i * 131 + Js.Math.random_int(0, 90),
          left: 45.0 +. Js.Math.random() *. 10.0,
          size: 5.0 +. Js.Math.random() *. 6.0,
          dur: 2000 + Js.Math.random_int(0, 1400),
        })
        setBubbles(prev => Belt.Array.concat(prev, fresh))
        let ids = fresh->Belt.Array.map(b => b.id)
        let _ = Js.Global.setTimeout(
          () =>
            setBubbles(prev => prev->Belt.Array.keep(b => !(ids->Belt.Array.some(x => x == b.id)))),
          3600,
        )
      }
      puff()
      let id = Js.Global.setInterval(puff, 1900)
      Some(() => Js.Global.clearInterval(id))
    } else {
      setBubbles(_ => [])
      None
    }
  }, [underwater])

  let px = v => `${v->Js.Float.toString}px`

  let diverStyle: ReactDOM.Style.t = {
    top: px(centerY),
    left: `${leftPct->Js.Float.toString}%`,
    transitionDuration: `${moveMs->Belt.Int.toString}ms`,
  }
  let oceanStyle: ReactDOM.Style.t = {top: px(seaLevel)}

  let overlayClass =
    "dd-overlay" ++ (seaVisible ? " is-sea" : "") ++ (underwater ? " is-underwater" : "")

  <div className=overlayClass role="dialog" ariaLabel=message>
    <div className="dd-ocean" style=oceanStyle />
    <div className="dd-surface" style=oceanStyle />
    <div className="dd-seabed">
      {[0, 1, 2, 3, 4]
      ->Belt.Array.map(i =>
        <span
          key={i->Belt.Int.toString}
          className="dd-weed"
          style={{left: `${(8 + i * 20)->Belt.Int.toString}%`}}
        />
      )
      ->React.array}
    </div>
    {underwater
      ? bubbles
        ->Belt.Array.map(b => {
          let base: ReactDOM.Style.t = {
            top: px(diveCenter -. 18.0),
            left: `${b.left->Js.Float.toString}%`,
            animationDuration: `${b.dur->Belt.Int.toString}ms`,
          }
          let style =
            base
            ->ReactDOM.Style.unsafeAddProp("--sz", px(b.size))
            ->ReactDOM.Style.unsafeAddProp("--rise", px(diveCenter -. seaLevel))
          <span key={b.id->Belt.Int.toString} className="dd-bubble" style />
        })
        ->React.array
      : React.null}
    // depth gauge: the scale runs 0 at the surface to a full vocabulary at the
    // seabed. The badge sinks with the diver, then stays pinned at the reached
    // depth reading the words-learned tally. Always mounted (faded out until the
    // dive) so the badge can transition down rather than pop in at depth.
    <div className="dd-gauge" ariaHidden=true>
      <div className="dd-gauge-line" style={{top: px(seaLevel), height: px(span)}} />
      {[0.0, 0.25, 0.5, 0.75, 1.0]
      ->Belt.Array.map(f => {
        let label = Belt.Float.toInt(f *. Belt.Int.toFloat(vocabTotal))
        <div
          key={f->Js.Float.toString}
          className="dd-gauge-tick"
          style={{top: px(seaLevel +. f *. span)}}>
          <span className="dd-gauge-tick-num"> {React.string(label->Belt.Int.toString)} </span>
          <span className="dd-gauge-tick-dash" />
        </div>
      })
      ->React.array}
      <div
        className="dd-gauge-marker"
        style={{top: px(markerY), transitionDuration: `${moveMs->Belt.Int.toString}ms`}}>
        <span className="dd-gauge-num"> {React.string(displayCount->Belt.Int.toString)} </span>
        <span className="dd-gauge-cap"> {React.string(countLabel)} </span>
      </div>
    </div>
    <div className={`dd-diver ${phaseClass}`} style=diverStyle ariaHidden=true>
      <div className="dd-diver-body">
        <span className="dd-fin dd-fin-l" />
        <span className="dd-fin dd-fin-r" />
        <span className="dd-leg dd-leg-l" />
        <span className="dd-leg dd-leg-r" />
        <span className="dd-arm dd-arm-l" />
        <span className="dd-arm dd-arm-r" />
        <span className="dd-torso" />
        <span className="dd-tank" />
        <span className="dd-head">
          <span className="dd-mask" />
          <span className="dd-snorkel" />
        </span>
      </div>
    </div>
    <div className={phase == Done ? "dd-summary is-shown" : "dd-summary"}>
      <p className="dd-message"> {React.string(message)} </p>
      <button type_="button" className="primary dd-new" disabled=busy onClick={_ => onNewGame()}>
        {React.string(newGameLabel)}
      </button>
    </div>
  </div>
}
