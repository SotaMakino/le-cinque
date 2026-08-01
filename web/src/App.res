%%raw(`import "./App.css"`)

@react.component
let make = () => {
  let (game, setGame) = React.useState(() => None)
  let (error, setError) = React.useState(() => "")
  let (notice, setNotice) = React.useState(() => "") // rejected letter, transient
  // a guess and a new deal are both actions: each keeps its own pending flag,
  // raised for as long as the request is in flight
  let (placing, startPlacing) = ReactConcurrent.useTransition()
  let (dealing, startDealing) = ReactConcurrent.useTransition()
  // the letter waiting on a ruling, held only for the life of the guess action
  let (pending, showPending) = ReactConcurrent.useOptimistic(None, (_, dropped) => Some(dropped))
  // the rejected letter, kept on its tile through the shake so it is clear which
  // letter was turned down and where
  let (shake, setShake) = React.useState((): option<Game.pending> => None)
  let (account, setAccount) = React.useState(() => None) // fetched player: guest or account
  let (menuOpen, setMenuOpen) = React.useState(() => false)
  let (showAuth, setShowAuth) = React.useState(() => false) // sign-in overlay
  let (uiLang, setUiLang) = React.useState(() => #it) // UI language, toggled by the flags
  let (selected, setSelected) = React.useState(() => "") // letter picked from the keyboard
  let (tileCursor, setTileCursor) = React.useState((): option<(int, int)> => None) // arrow-key cursor
  let (navMode, setNavMode) = React.useState(() => false) // true while navigating tiles by arrow keys
  let (dragging, setDragging) = React.useState(() => false)
  let sensors = DndKit.useDefaultSensors()
  let tr = I18n.strings(uiLang) // localized UI strings

  let loadAccount = async () =>
    switch await GameApi.fetchMe() {
    | Ok(fetched) => setAccount(_ => Some(fetched))
    | Error(_) => ()
    }

  // the flags pick both the UI language and the guessing direction, so keep the
  // UI language in step with whatever direction the round came back with
  let applyGame = (g: Game.game) => {
    // Settle the streak before the render that shows the round, so a lap that
    // is about to start already knows how many cars it is driving. A round the
    // browser has counted before — every reload of a finished one — is left be.
    WinStreak.record(~gameId=g.id, ~status=g.status)
    setGame(_ => Some(g))
    setUiLang(_ => g.direction == "en" ? #en : #it)
  }

  let loadGame = async () => {
    setError(_ => "")
    switch await GameApi.fetchGame() {
    | Ok(fetched) => {
        applyGame(fetched)
        loadAccount()->ignore
      }
    | Error(err) => setError(_ => I18n.failedLoad(uiLang, err.message))
    }
  }

  React.useEffect0(() => {
    loadGame()->ignore
    None
  })

  // initial load failed: auto-retry every 5s instead of asking the user to click
  React.useEffect2(() => {
    switch game {
    | None if error != "" =>
      let id = Js.Global.setTimeout(() => loadGame()->ignore, 5000)
      Some(() => Js.Global.clearTimeout(id))
    | _ => None
    }
  }, (game, error))

  // only signed-in accounts may call the Cloud TTS endpoint; guests fall back to
  // the browser voice (see Speech.speakWord)
  let authenticated = switch account {
  | Some(acc) => !acc.guest
  | None => false
  }

  // Place one letter on one exact tile. The tile takes the letter the moment it
  // lands and the server rules on it afterwards: the guess runs as an action, so
  // the letter sits there for exactly as long as the request does, and the render
  // that clears it is the same one that shows the ruling.
  let placeLetter = (letter, wordIndex, position) =>
    switch game {
    | Some(g) if g.status == "playing" && !placing && !dealing && letter != "" =>
      startPlacing(async () => {
        showPending({Game.letter, wordIndex, position})
        setNotice(_ => "")
        switch await GameApi.guess(~letter, ~word=wordIndex, ~position) {
        | Ok(updated) => {
            // the round this letter just won or lost, counted before it is shown
            WinStreak.record(~gameId=updated.id, ~status=updated.status)
            setGame(_ => Some(updated))
            // drop a letter from the hand once it has left the keyboard
            setSelected(s => Game.isSpent(updated, s) ? "" : s)
            if updated.wrong->Belt.Array.length > g.wrong->Belt.Array.length {
              let left = updated.maxMisses - updated.wrong->Belt.Array.length
              let shown = letter->Js.String2.toLowerCase
              setNotice(_ => I18n.notice(uiLang, shown, left))
              // shake the missed slot, then clear it so it can fire again
              setShake(_ => Some({Game.letter, wordIndex, position}))
              let _ = Js.Global.setTimeout(() => setShake(_ => None), 450)
            }
            if updated.status == "won" {
              loadAccount()->ignore // refresh the tally for the account menu
            }
          }
        | Error(err) if err.status == 400 || err.status == 409 =>
          // the raw server hint ("tile already revealed") reads better in a
          // game notice than the full "HTTP 400: …" string
          setNotice(_ => err.message->Js.String2.replaceByRe(%re("/^HTTP \d+: /"), ""))
        | Error(err) => setError(_ => I18n.failedSubmit(uiLang, err.message))
        }
      })
    | _ => ()
    }

  let startRound = path =>
    startDealing(async () => {
      setNotice(_ => "")
      switch await GameApi.start(path) {
      | Ok(fetched) => {
          applyGame(fetched)
          loadAccount()->ignore // a new round bumps the global play tally (N.)
        }
      | Error(err) => setError(_ => I18n.failedStart(uiLang, err.message))
      }
    })

  let newGame = () => startRound("/game")

  // tapping a flag re-deals the untouched round in that direction (the server
  // rejects it once a letter is placed, but the UI disables the flags by then)
  let setDirection = async dir =>
    switch await GameApi.setDirection(dir) {
    | Ok(fetched) => applyGame(fetched)
    | Error(_) => ()
    }

  // a physical key press picks the letter up; clicking a tile drops it
  let handleKey = k =>
    if k->Js.String2.length == 1 && %re("/^[a-z]$/i")->Js.Re.test_(k) {
      let letter = k->Js.String2.toUpperCase
      switch game {
      | Some(g) if g.status == "playing" && !Game.isSpent(g, letter) =>
        setSelected(s => s == letter ? "" : letter)
      | _ => ()
      }
    }

  // keyboard-only placement: the arrow keys walk a cursor across the open tiles
  // (see TileNav) and Enter/Space drops the selected letter there
  let pairs = switch game {
  | Some(g) => g.pairs
  | None => []
  }
  let activeTile = TileNav.activeTile(pairs, tileCursor)
  let moveTile = dir =>
    switch activeTile {
    | None => ()
    | Some(cur) =>
      switch TileNav.moveTarget(pairs, cur, dir) {
      | Some(t) => setTileCursor(_ => Some(t))
      | None => ()
      }
    }
  let placeAtCursor = () =>
    switch activeTile {
    | Some((wi, pos)) => placeLetter(selected, wi, pos)
    | None => ()
    }
  let handleKeyEvent = e => {
    let target = e->DomBindings.eventTarget
    // never hijack the arrows while typing in a form field
    let editable =
      target->DomBindings.targetTag == "INPUT" ||
      target->DomBindings.targetTag == "TEXTAREA" ||
      target->DomBindings.targetEditable
    if editable {
      ()
    } else {
      switch e->DomBindings.eventKey {
      | "ArrowLeft" | "ArrowRight" | "ArrowUp" | "ArrowDown" =>
        e->DomBindings.preventDefault
        setNavMode(_ => true)
        let dir = switch e->DomBindings.eventKey {
        | "ArrowLeft" => #left
        | "ArrowRight" => #right
        | "ArrowUp" => #up
        | _ => #down
        }
        moveTile(dir)
      | "Enter" | " " =>
        if navMode {
          e->DomBindings.preventDefault
          placeAtCursor()
        }
      | "Escape" => setSelected(_ => "")
      | k => handleKey(k)
      }
    }
  }

  // dnd-kit reports the drop by ids: the dragged letter and the tile's
  // "wordIndex-position". A drag that ends off any tile leaves over null.
  let handleDragEnd = (e: DndKit.dragEndEvent) => {
    setDragging(_ => false)
    switch e.over->Js.Nullable.toOption {
    | Some(over) =>
      switch over.id->Js.String2.split("-") {
      | [ws, ps] =>
        switch (Belt.Int.fromString(ws), Belt.Int.fromString(ps)) {
        | (Some(wi), Some(pos)) => placeLetter(e.active.id, wi, pos)
        | _ => ()
        }
      | _ => ()
      }
    | None => ()
    }
  }

  // the physical keyboard listener mounts once, so route events through a ref
  // that always points at the latest render's handler
  let handleKeyRef = React.useRef(handleKeyEvent)
  handleKeyRef.current = handleKeyEvent

  React.useEffect0(() => {
    let listener = e =>
      if !(e->DomBindings.ctrlKey) && !(e->DomBindings.metaKey) && !(e->DomBindings.altKey) {
        handleKeyRef.current(e)
      }
    DomBindings.addKeyListener("keydown", listener)
    Some(() => DomBindings.removeKeyListener("keydown", listener))
  })

  // a pointer press (click or tap, anywhere) drops the arrow-key cursor so it
  // never lingers once the mouse takes over. A press outside the on-screen
  // keyboard also blurs any focused key, so its focus ring doesn't stick, and
  // drops the picked letter so the key and the armed slots lose their color.
  React.useEffect0(() => {
    let listener = e => {
      setNavMode(_ => false)
      switch e->DomBindings.pointerTarget->DomBindings.closest(".keyboard") {
      | Some(_) => () // inside the keyboard: leave the key focused
      | None =>
        switch DomBindings.activeElement->DomBindings.closest(".key") {
        | Some(key) => key->DomBindings.blur
        | None => ()
        }
        // an open tile keeps the letter (its click places it); anywhere else
        // clears the selection so nothing stays highlighted
        switch e->DomBindings.pointerTarget->DomBindings.closest(".tile.open") {
        | Some(_) => ()
        | None => setSelected(_ => "")
        }
      }
    }
    DomBindings.addPointerListener("pointerdown", listener)
    Some(() => DomBindings.removePointerListener("pointerdown", listener))
  })

  // signing in or out swaps the player identity, so reload the round (now keyed
  // on the account or the guest cookie) and refresh the account panel
  let afterAuthChange = () => {
    setShowAuth(_ => false)
    setMenuOpen(_ => false)
    loadGame()->ignore
  }

  let handleLogout = async () => {
    let _ = await AuthApi.logout()
    afterAuthChange()
  }

  // deleting the account wipes it server-side and drops the browser back to
  // anonymous guest play, so reuse the same reload path as signing out
  let handleDeleteAccount = async () =>
    if DomBindings.confirmDialog(tr.deleteConfirm) {
      let _ = await AuthApi.deleteAccount()
      afterAuthChange()
    }

  // open the account popup and refresh its learned-word count
  let toggleMenu = () => {
    let opening = !menuOpen
    setMenuOpen(_ => opening)
    if opening {
      loadAccount()->ignore
    }
  }

  switch game {
  | None => <LoadingScreen lang=uiLang error />
  | Some(g) =>
    <main className="app">
      <Masthead
        lang=uiLang
        account
        menuOpen
        direction=g.direction
        locked={g.guessed->Belt.Array.length > 0}
        onToggleMenu={() => toggleMenu()}
        onSignIn={() => setShowAuth(_ => true)}
        onSetDirection={dir => setDirection(dir)->ignore}
        onCloseMenu={() => setMenuOpen(_ => false)}
        onLogout={() => handleLogout()->ignore}
        onDelete={() => handleDeleteAccount()->ignore}
      />
      {showAuth
        ? <AuthModal
            lang=uiLang onClose={() => setShowAuth(_ => false)} onSuccess={() => afterAuthChange()}
          />
        : React.null}
      {error == "" ? React.null : <p className="error" role="alert"> {React.string(error)} </p>}
      <DndKit.DndContext
        sensors
        onDragStart={_ => setDragging(_ => true)}
        onDragEnd={handleDragEnd}
        onDragCancel={() => setDragging(_ => false)}>
        <Board
          pairs=g.pairs
          direction=g.direction
          selected
          dragging
          shake
          pending
          navMode
          activeTile
          authenticated
          lang=uiLang
          onPlace={(letter, wi, pos) => placeLetter(letter, wi, pos)}
        />
        // always rendered with reserved height, so guess feedback never shifts
        // the keyboard below it
        <p className="notice" role="alert"> {React.string(notice)} </p>
        <MissDots label=tr.mistakes maxMisses=g.maxMisses missCount={g.wrong->Belt.Array.length} />
        <Keyboard
          usedUp=g.usedUp
          absent=g.absent
          selected
          status=g.status
          onSelect={letter => setSelected(s => s == letter ? "" : letter)}
        />
        <Banner lang=uiLang status=g.status gameId=g.id busy=dealing onNewGame={() => newGame()} />
      </DndKit.DndContext>
      <footer className="app-footer">
        <p className="footer-links">
          <span className="footer-copy"> {React.string(`© 2026 Sota Makino`)} </span>
          <span className="footer-sep"> {React.string("|")} </span>
          <a href="/about.html"> {React.string(tr.about)} </a>
          <span className="footer-sep"> {React.string("|")} </span>
          <a href="/privacy.html"> {React.string(tr.privacy)} </a>
          <span className="footer-sep"> {React.string("|")} </span>
          <a href="/terms.html"> {React.string(tr.terms)} </a>
        </p>
      </footer>
    </main>
  }
}
