// The playing board: one row per pair, each with a speaker to pronounce it, the
// prompt word, and the answer tiles. Empty tiles are drop targets that also
// accept a tap; revealed tiles are tinted by the noun's gender.
@react.component
let make = (
  ~pairs: array<Game.pair>,
  ~direction,
  ~selected,
  ~dragging,
  ~shake,
  ~pending: option<Game.pending>,
  ~navMode,
  ~activeTile,
  ~authenticated,
  ~lang,
  ~onPlace,
) => {
  // the speaker pronounces the prompt word in its own language: Italian when
  // spelling English, English when spelling Italian
  let promptLang = direction == "en" ? "en-US" : "it-IT"
  <div className="pairs">
    {pairs
    ->Belt.Array.mapWithIndex((wi, p) =>
      <div key=p.prompt className="pair-row">
        <span className="italian">
          <button
            type_="button"
            className="speak"
            title={I18n.pronounce(lang, p.prompt)}
            ariaLabel={I18n.pronounce(lang, p.prompt)}
            onClick={_ => Speech.speakWord(p.prompt, promptLang, ~authenticated)}>
            <Glyphs.Speaker />
          </button>
          {React.string(p.prompt)}
        </span>
        <div className="english-tiles">
          {p.tiles
          ->Belt.Array.mapWithIndex((i, letter) =>
            switch (letter, pending) {
            // the letter just dropped here, still waiting on the server: shown in
            // place, in the paper's pale ink, and no longer a drop target
            | ("", Some(dropped)) if dropped.wordIndex == wi && dropped.position == i =>
              <div key={i->Belt.Int.toString} className="tile pending">
                {React.string(dropped.letter)}
              </div>
            | ("", _) =>
              let armed = selected != "" || dragging
              <DndKit.Droppable
                key={i->Belt.Int.toString}
                dropId={`${wi->Belt.Int.toString}-${i->Belt.Int.toString}`}
                className={"tile open" ++
                (armed ? " armed" : "") ++
                (shake == Some((wi, i)) ? " shake" : "") ++ (
                  navMode && activeTile == Some((wi, i)) ? " tile-cursor" : ""
                )}
                armed
                onClick={_ => onPlace(selected, wi, i)}
              />
            | _ =>
              <div
                key={i->Belt.Int.toString}
                className="tile revealed"
                style={{backgroundColor: Game.tileColor(p.gender)}}>
                {React.string(letter)}
              </div>
            }
          )
          ->React.array}
        </div>
      </div>
    )
    ->React.array}
  </div>
}
