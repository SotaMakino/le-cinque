// localized "24 Jul 2026" for a heatmap cell's tooltip; timeZone UTC keeps the
// date matching the calendar day regardless of the viewer's zone
@send
external toLocaleDate: (
  Js.Date.t,
  string,
  {"day": string, "month": string, "year": string, "timeZone": string},
) => string = "toLocaleDateString"

// YYYY-MM-DD in the viewer's local timezone — the day the player is living
// in, which can differ from the server's UTC date around midnight.
let localDay = (): string =>
  %raw(`(() => { const d = new Date(); const m = String(d.getMonth() + 1).padStart(2, "0"); const day = String(d.getDate()).padStart(2, "0"); return d.getFullYear() + "-" + m + "-" + day })()`)

// The grid must end on the viewer's local today. A window that still ends on
// the server's UTC date leaves players east of UTC with no cell for today —
// Oct 7 in Rome is still Oct 6 in UTC — and players west of UTC with an empty
// future cell. So pad missing days with zeros or trim future ones. Capped at
// two days: timezone offsets max out at 14h, so anything more is a broken
// clock, and the server's window is the safer thing to show.
let toLocalToday = (activity: array<int>, activityStart: string): array<int> => {
  let n = Belt.Array.length(activity)
  if n == 0 || Js.String2.length(activityStart) != 10 {
    activity
  } else {
    let startMs = Js.Date.fromString(activityStart ++ "T00:00:00Z")->Js.Date.getTime
    let today = localDay()
    let todayMs = Js.Date.fromString(today ++ "T00:00:00Z")->Js.Date.getTime
    if Js.Float.isNaN(startMs) || Js.Float.isNaN(todayMs) {
      activity
    } else {
      let endMs = startMs +. (n - 1)->Belt.Int.toFloat *. 86400000.
      let raw = (todayMs -. endMs) /. 86400000.
      // round half away from zero to whole days (both ends are UTC midnights)
      let diff = raw >= 0. ? Belt.Float.toInt(raw +. 0.5) : -Belt.Float.toInt(-.raw +. 0.5)
      if diff > 0 && diff <= 2 {
        Belt.Array.concat(activity, Belt.Array.make(diff, 0))
      } else if diff < 0 && diff >= -2 {
        Belt.Array.slice(activity, ~offset=0, ~len=n + diff)
      } else {
        activity
      }
    }
  }
}
// Fixed cut-offs flatten the calendar out as soon as one keen day dwarfs the
// rest — 6, 10 and 40 words all landed on the darkest square. So the four
// shades follow the quartiles of the days actually practised: the busiest day
// is always darkest, and the quieter ones spread over the shades below it.
let shades = (activity: array<int>) => {
  let busy = activity->Belt.Array.keep(c => c > 0)->Belt.SortArray.stableSortBy((a, b) => a - b)
  let n = Belt.Array.length(busy)
  let quartile = q =>
    switch Belt.Array.get(busy, n * q / 4) {
    | Some(v) => v
    | None => 1
    }
  let (q1, q2, q3) = (quartile(1), quartile(2), quartile(3))
  c => c <= 0 ? "0" : c < q1 ? "1" : c < q2 ? "2" : c < q3 ? "3" : "4"
}

// the signed-in account popup: vocabulary count, progress bar, activity calendar,
// and the log-out / delete actions. The parent owns the open/closed state and
// mounts this only while the menu is open.
@react.component
let make = (
  ~lang,
  ~learned: int,
  ~activity: array<int>,
  ~activityStart: string,
  ~yearWords: int,
  ~onClose: unit => unit,
  ~onLogout: unit => unit,
  ~onDelete: unit => unit,
) => {
  let tr = I18n.strings(lang)
  <>
    <div className="menu-backdrop" onClick={_ => onClose()} />
    <div className="account-menu" role="dialog">
      <div className="menu-stat">
        <span className="menu-count"> {React.string(learned->Belt.Int.toString)} </span>
        <span className="menu-label"> {React.string(tr.wordsLearned)} </span>
      </div>
      {
        // progress toward the 1,500-word course, capped at 100%
        let pct = learned * 100 / 1500
        let pct = pct > 100 ? 100 : pct
        <div className="menu-progress-wrap">
          <div className="menu-progress">
            <span style={{width: pct->Belt.Int.toString ++ "%"}} />
          </div>
          <p className="menu-progress-label">
            {React.string(
              learned->Belt.Int.toString ++
              " / " ++
              tr.wordGoal ++
              " · " ++
              pct->Belt.Int.toString ++ "%",
            )}
          </p>
        </div>
      }
      <div className="menu-cal-wrap">
        <span className="menu-label"> {React.string(tr.recentActivity)} </span>
        <div className="menu-cal">
          {
            // dense daily counts starting on a Sunday: chunk into
            // week columns, one cell per weekday (Sun→Sat). The window is
            // stretched to the viewer's local today so there is always a cell
            // for the day being lived in, even if the server's UTC window ends
            // a day early.
            let days = toLocalToday(activity, activityStart)
            let cols = (Belt.Array.length(days) + 6) / 7
            let shadeOf = shades(days)
            let locale = lang == #it ? "it-IT" : "en-US"
            let startMs = Js.Date.fromString(activityStart ++ "T00:00:00Z")->Js.Date.getTime
            Belt.Array.makeBy(cols, col =>
              <div className="cal-week" key={col->Belt.Int.toString}>
                {Belt.Array.makeBy(7, row => {
                  let i = col * 7 + row
                  switch Belt.Array.get(days, i) {
                  | Some(c) =>
                    let lvl = shadeOf(c)
                    // "3 words · 24 Jul 2026" — the day's tally and date
                    let date = Js.Date.fromFloat(startMs +. i->Belt.Int.toFloat *. 86400000.)
                    let dateStr = date->toLocaleDate(
                      locale,
                      {
                        "day": "numeric",
                        "month": "short",
                        "year": "numeric",
                        "timeZone": "UTC",
                      },
                    )
                    let word = c == 1 ? tr.dayWord : tr.dayWords
                    let title = c->Belt.Int.toString ++ " " ++ word ++ " · " ++ dateStr
                    <div key={row->Belt.Int.toString} className={"cal-day l" ++ lvl} title />
                  | None => <div key={row->Belt.Int.toString} className="cal-day cal-empty" />
                  }
                })->React.array}
              </div>
            )->React.array
          }
        </div>
        <p className="menu-cal-total">
          <span className="menu-cal-total-n"> {React.string(yearWords->Belt.Int.toString)} </span>
          {React.string(
            // "14 words practiced in 2026" — noun and adjective both agree
            // with the count (it: parola praticata / parole praticate)
            " " ++
            (yearWords == 1 ? tr.dayWord : tr.dayWords) ++
            " " ++
            (yearWords == 1 ? tr.practicedOne : tr.practicedMany) ++
            " " ++
            tr.inYear ++
            " " ++
            Js.Date.make()->Js.Date.getFullYear->Belt.Float.toInt->Belt.Int.toString,
          )}
        </p>
      </div>
      <div className="menu-actions">
        <button type_="button" className="link menu-logout" onClick={_ => onLogout()}>
          {React.string(tr.logOut)}
        </button>
        <button type_="button" className="link menu-delete" onClick={_ => onDelete()}>
          {React.string(tr.deleteAccount)}
        </button>
      </div>
    </div>
  </>
}
