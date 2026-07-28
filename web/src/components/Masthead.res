// The newspaper masthead: the issue dateline (play tally + edition date), the
// account area (name → popup, or a sign-in link), the title, and the flag row
// that picks both the UI language and the guessing direction.
@react.component
let make = (
  ~lang,
  ~account: option<Game.me>,
  ~menuOpen,
  ~direction,
  ~locked,
  ~onToggleMenu,
  ~onSignIn,
  ~onSetDirection,
  ~onCloseMenu,
  ~onLogout,
  ~onDelete,
) => {
  let tr = I18n.strings(lang)
  // the flags lock once a letter is placed — you can only switch on a fresh board
  let flag = (dir, emoji, label) =>
    <button
      type_="button"
      className={direction == dir ? "flag active" : "flag"}
      ariaLabel=label
      disabled=locked
      onClick={_ => onSetDirection(dir)}>
      {React.string(emoji)}
    </button>
  <header className="app-header">
    <div className="dateline">
      <span>
        {React.string(
          switch account {
          | Some(acc) => NumberWords.issueLabel(lang, acc.plays)
          | None => lang == #it ? "N. —" : "No. —"
          },
        )}
      </span>
      <div className="dateline-meta">
        <span className="dateline-date"> {React.string(I18n.editionDate(lang))} </span>
        <span className="dateline-sep"> {React.string("|")} </span>
        {switch account {
        | Some(acc) if !acc.guest =>
          // signed in: name opens a popup with the vocabulary count + log out
          <div className="account">
            <button
              type_="button"
              className="username"
              ariaLabel={tr.account}
              onClick={_ => onToggleMenu()}>
              {React.string(acc.username)}
            </button>
            {!menuOpen
              ? React.null
              : <AccountMenu
                  lang
                  learned=acc.learned
                  activity=acc.activity
                  activityStart=acc.activityStart
                  yearWords=acc.yearWords
                  onClose=onCloseMenu
                  onLogout
                  onDelete
                />}
          </div>
        | _ =>
          // guest: a link to sign in and start tracking learned words
          <div className="account">
            <button type_="button" className="username" onClick={_ => onSignIn()}>
              {React.string(tr.signIn)}
            </button>
          </div>
        }}
      </div>
    </div>
    <h1>
      {React.string("Le ")}
      <span className="cinque"> {React.string("Cinque")} </span>
    </h1>
    <div className="flag-row">
      {flag("it", `🇮🇹`, tr.showItalian)}
      <span className="flag-sep"> {React.string("|")} </span>
      {flag("en", `🇺🇸`, tr.showEnglish)}
    </div>
  </header>
}
