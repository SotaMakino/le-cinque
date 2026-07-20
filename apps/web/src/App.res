%%raw(`import "./App.css"`)

type pair = {italian: string, english: array<string>} // "" = still hidden

type game = {
  id: int,
  status: string, // "playing" | "won" | "lost"
  pairs: array<pair>,
  guessed: array<string>,
  wrong: array<string>,
  triesLeft: int,
  maxTries: int,
}

// celebration fireworks: staggered bursts of randomized particles
type particle = {
  dx: float,
  dy: float,
  size: float,
  rot: float,
  color: string,
  delay: int,
  duration: int,
  streak: bool, // confetti streak instead of a round spark
}

type burst = {x: int, y: int, key: int, particles: array<particle>}

let burstColors = ["#aa3bff", "#f59e0b", "#ef4444", "#22c55e", "#06b6d4", "#ec4899", "#facc15"]

let makeBurst = (x, y, scale, key) => {
  let count = 24
  let particles = Belt.Array.makeBy(count, i => {
    let angle =
      2.0 *. Js.Math._PI *. Belt.Int.toFloat(i) /. Belt.Int.toFloat(count) +.
        (Js.Math.random() -. 0.5) *. 0.5
    let distance = (55.0 +. Js.Math.random() *. 65.0) *. scale
    {
      dx: Js.Math.cos(angle) *. distance,
      dy: Js.Math.sin(angle) *. distance,
      size: 4.0 +. Js.Math.random() *. 5.0,
      rot: Js.Math.random() *. 360.0,
      color: burstColors->Belt.Array.getExn(mod(i, Belt.Array.length(burstColors))),
      delay: Js.Math.random_int(0, 90),
      duration: 700 + Js.Math.random_int(0, 450),
      streak: mod(i, 3) == 0,
    }
  })
  {x, y, key, particles}
}

@val @scope("window") external innerWidth: int = "innerWidth"
@val @scope("window") external innerHeight: int = "innerHeight"

type keyboardEvent
@get external eventKey: keyboardEvent => string = "key"
@get external ctrlKey: keyboardEvent => bool = "ctrlKey"
@get external metaKey: keyboardEvent => bool = "metaKey"
@get external altKey: keyboardEvent => bool = "altKey"
@val @scope("document")
external addKeyListener: (string, keyboardEvent => unit) => unit = "addEventListener"
@val @scope("document")
external removeKeyListener: (string, keyboardEvent => unit) => unit = "removeEventListener"

@react.component
let make = () => {
  let (authed, setAuthed) = React.useState(() => None) // None = still checking
  let (game, setGame) = React.useState(() => None)
  let (error, setError) = React.useState(() => "")
  let (notice, setNotice) = React.useState(() => "") // rejected letter, transient
  let (busy, setBusy) = React.useState(() => false)
  let (bursts, setBursts) = React.useState(() => [])

  let celebrate = () => {
    let x = innerWidth / 2
    let y = innerHeight / 3
    let base = Js.Date.now()->Belt.Float.toInt
    // a small finale: main burst, then two smaller ones off to the sides
    let fire = (offsetX, offsetY, scale, afterMs, index) => {
      let key = base + index
      let _ = Js.Global.setTimeout(() => {
        setBursts(prev =>
          prev->Belt.Array.concat([makeBurst(x + offsetX, y + offsetY, scale, key)])
        )
        let _ = Js.Global.setTimeout(
          () => setBursts(prev => prev->Belt.Array.keep(b => b.key != key)),
          1400,
        )
      }, afterMs)
    }
    fire(0, 0, 1.2, 0, 0)
    fire(-75, -50, 0.8, 170, 1)
    fire(70, -65, 0.9, 340, 2)
  }

  let loadGame = async () => {
    setError(_ => "")
    switch await ApiClient.request("/game") {
    | Ok(res) => {
        let fetched: game = await ApiClient.json(res)
        setGame(_ => Some(fetched))
        setAuthed(_ => Some(true))
      }
    | Error(err) if err.status == 401 => setAuthed(_ => Some(false))
    | Error(err) => setError(_ => `Failed to load the game: ${err.message}`)
    }
  }

  React.useEffect0(() => {
    loadGame()->ignore
    None
  })

  let submitLetter = async letter => {
    switch game {
    | Some(g) if g.status == "playing" && !busy => {
        setBusy(_ => true)
        setNotice(_ => "")
        switch await ApiClient.request("/game/guess", ~method_="POST", ~body={"guess": letter}) {
        | Ok(res) => {
            let updated: game = await ApiClient.json(res)
            setGame(_ => Some(updated))
            if updated.status == "won" {
              celebrate()
            }
          }
        | Error(err) if err.status == 401 => setAuthed(_ => Some(false))
        | Error(err) if err.status == 400 || err.status == 409 =>
          // the raw server hint ("letter already tried") reads better in a
          // game notice than the full "HTTP 400: …" string
          setNotice(_ => err.message->Js.String2.replaceByRe(%re("/^HTTP \d+: /"), ""))
        | Error(err) => setError(_ => `Failed to submit the letter: ${err.message}`)
        }
        setBusy(_ => false)
      }
    | _ => ()
    }
  }

  let newGame = async () => {
    setBusy(_ => true)
    setNotice(_ => "")
    switch await ApiClient.request("/game", ~method_="POST") {
    | Ok(res) => {
        let fetched: game = await ApiClient.json(res)
        setGame(_ => Some(fetched))
      }
    | Error(err) if err.status == 401 => setAuthed(_ => Some(false))
    | Error(err) => setError(_ => `Failed to start a new game: ${err.message}`)
    }
    setBusy(_ => false)
  }

  let handleKey = k => {
    if k->Js.String2.length == 1 && %re("/^[a-z]$/i")->Js.Re.test_(k) {
      submitLetter(k->Js.String2.toUpperCase)->ignore
    }
  }

  // the physical keyboard listener mounts once, so route events through a ref
  // that always points at the latest render's handler
  let handleKeyRef = React.useRef(handleKey)
  handleKeyRef.current = handleKey

  React.useEffect1(() => {
    switch authed {
    | Some(true) => {
        let listener = e =>
          if !(e->ctrlKey) && !(e->metaKey) && !(e->altKey) {
            handleKeyRef.current(e->eventKey)
          }
        addKeyListener("keydown", listener)
        Some(() => removeKeyListener("keydown", listener))
      }
    | _ => None
    }
  }, [authed])

  let handleLogout = async () => {
    // even if the server is unreachable, drop back to the login screen
    let _ = await AuthApi.logout()
    setAuthed(_ => Some(false))
  }

  switch authed {
  | None =>
    // still checking the session; if the check itself failed, say so
    error == ""
      ? <main className="app">
          <div className="loading-screen">
            <div className="spinner" />
            <p> {React.string("Connecting to server…")} </p>
          </div>
        </main>
      : <main className="app">
          <p className="error" role="alert"> {React.string(error)} </p>
          <button type_="button" className="primary" onClick={_ => loadGame()->ignore}>
            {React.string("Retry")}
          </button>
        </main>
  | Some(false) =>
    <main className="app">
      <AuthForm onSuccess={() => loadGame()->ignore} />
    </main>
  | Some(true) =>
    <main className="app">
      <header className="app-header">
        <div>
          <h1> {React.string("Parole")} </h1>
          <p className="tagline">
            {React.string("Type letters to reveal the English words — 5 misses and it's over")}
          </p>
        </div>
        <button type_="button" className="ghost" onClick={_ => handleLogout()->ignore}>
          {React.string("Log out")}
        </button>
      </header>
      {error == "" ? React.null : <p className="error" role="alert"> {React.string(error)} </p>}
      {switch game {
      | None => React.null
      | Some(g) =>
        <>
          <div className="tries">
            <span className="tries-label"> {React.string("Tries")} </span>
            {Belt.Array.makeBy(g.maxTries, i =>
              <span
                key={i->Belt.Int.toString} className={i < g.triesLeft ? "try-dot" : "try-dot spent"}
              />
            )->React.array}
            {g.wrong->Belt.Array.length == 0
              ? React.null
              : <span className="wrong-letters">
                  {React.string(`Missed: ${g.wrong->Js.Array2.joinWith(" ")}`)}
                </span>}
          </div>
          <div className="pairs">
            {g.pairs
            ->Belt.Array.map(p =>
              <div key=p.italian className="pair-row">
                <span className="italian"> {React.string(p.italian)} </span>
                <div className="english-tiles">
                  {p.english
                  ->Belt.Array.mapWithIndex((i, letter) =>
                    <div
                      key={i->Belt.Int.toString} className={letter == "" ? "tile" : "tile correct"}>
                      {React.string(letter)}
                    </div>
                  )
                  ->React.array}
                </div>
              </div>
            )
            ->React.array}
          </div>
          {notice == ""
            ? React.null
            : <p className="notice" role="alert"> {React.string(notice)} </p>}
          {g.status == "playing"
            ? React.null
            : <div className="banner">
                <p>
                  {React.string(
                    g.status == "won"
                      ? "Bravo! You revealed all five words."
                      : "Out of tries — study the answers above. These words will come back for review.",
                  )}
                </p>
                <button
                  type_="button" className="primary" disabled=busy onClick={_ => newGame()->ignore}>
                  {React.string("New game")}
                </button>
              </div>}
        </>
      }}
      {bursts
      ->Belt.Array.map(b =>
        <div
          key={b.key->Belt.Int.toString}
          className="firework"
          ariaHidden=true
          style={{
            left: `${b.x->Belt.Int.toString}px`,
            top: `${b.y->Belt.Int.toString}px`,
          }}>
          {b.particles
          ->Belt.Array.mapWithIndex((i, p) => {
            let height = p.streak ? p.size *. 2.8 : p.size
            let base: ReactDOM.Style.t = {
              backgroundColor: p.color,
              width: `${p.size->Js.Float.toString}px`,
              height: `${height->Js.Float.toString}px`,
              boxShadow: `0 0 6px ${p.color}`,
              animationDelay: `${p.delay->Belt.Int.toString}ms`,
              animationDuration: `${p.duration->Belt.Int.toString}ms`,
            }
            let style =
              base
              ->ReactDOM.Style.unsafeAddProp("--dx", `${p.dx->Js.Float.toString}px`)
              ->ReactDOM.Style.unsafeAddProp("--dy", `${p.dy->Js.Float.toString}px`)
              ->ReactDOM.Style.unsafeAddProp("--rot", `${p.rot->Js.Float.toString}deg`)
            <span key={i->Belt.Int.toString} className={p.streak ? "streak" : "dot"} style />
          })
          ->React.array}
        </div>
      )
      ->React.array}
    </main>
  }
}
