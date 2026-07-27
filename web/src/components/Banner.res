// The end-of-round banner. A loss shows a varied message plus a Southern
// Italian saying; a win shows the Bravo line. Both offer a New game button.
// Rendered as React.null while the round is still "playing".
@react.component
let make = (~lang, ~status, ~gameId, ~busy, ~onNewGame) => {
  let tr = I18n.strings(lang)
  let newGameButton =
    <div className="banner-actions">
      <button type_="button" className="primary" disabled=busy onClick={_ => onNewGame()}>
        {React.string(tr.newGame)}
      </button>
    </div>
  switch status {
  | "lost" =>
    // stable per round (keyed on the game id), varied across rounds
    let message = switch tr.lostBanner->Belt.Array.get(
      mod(gameId, Belt.Array.length(tr.lostBanner)),
    ) {
    | Some(m) => m
    | None => ""
    }
    let saying = switch tr.sayings->Belt.Array.get(mod(gameId, Belt.Array.length(tr.sayings))) {
    | Some(s) => "“" ++ s ++ "”"
    | None => ""
    }
    <div className="banner">
      <p> {React.string(message)} </p>
      <p className="saying"> {React.string(saying)} </p>
      {newGameButton}
    </div>
  | "won" =>
    <div className="banner">
      <p> {React.string(tr.wonBanner)} </p>
      {newGameButton}
    </div>
  | _ => React.null
  }
}
