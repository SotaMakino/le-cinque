// The on-screen QWERTY keyboard. A letter can be tapped to select it or dragged
// onto a tile; a letter with nowhere left to go leaves the keyboard. Winning
// hands the emptied keyboard over to the victory lap, which drives the gaps.
//
// On narrow containers (tiny phones such as the 3" Unihertz Jelly Star, ~240px
// CSS wide) the on-screen rows are hidden by container queries and this same
// component offers the device keyboard instead: a native input that summons
// the OS keyboard. The narrow flow is slot-first — tap an empty tile to pick
// it (it gains the cursor ring), then type the letter, which lands there at
// once and the pick advances to the next empty tile. Typing with no tile
// picked still arms the letter exactly like tapping a key, and the player
// drops it by tapping a tile.
let keyboardRows = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["Z", "X", "C", "V", "B", "N", "M"],
]

@react.component
let make = (
  ~usedUp,
  ~absent,
  ~selected,
  ~status,
  ~lang,
  ~pickedTile: option<(int, int)>,
  ~onSelect,
  ~onClearPick,
) => {
  let tr = I18n.strings(lang)
  // the native input never holds text: every keystroke is forwarded to the
  // board and the field is cleared, so the OS keyboard stays open for the next
  // letter while the field itself never fills up
  let (draft, setDraft) = React.useState(() => "")
  let playing = status == "playing"
  let onDraftChange = v => {
    let len = v->Js.String2.length
    if len > 0 {
      let last = v->Js.String2.slice(~from=len - 1, ~to_=len)
      if %re("/^[a-z]$/i")->Js.Re.test_(last) {
        onSelect(last->Js.String2.toUpperCase)
      }
    }
    // always clear: the letter lives on the tile cursor / selection, not here
    setDraft(_ => "")
  }
  // the narrow instruction line always names the next physical step, so the
  // label never duplicates the input's own placeholder
  let hint = if selected != "" {
    selected ++ " · " ++ tr.tapTile
  } else {
    switch pickedTile {
    | Some((wi, pos)) => I18n.pickedHint(lang, wi, pos)
    | None => tr.pickTile
    }
  }
  let hasClear = selected != "" || pickedTile != None
  <div className="keyboard">
    <div className={"native-type" ++ (pickedTile != None ? " has-pick" : "")}>
      <label className="native-label" htmlFor="native-letter"> {React.string(hint)} </label>
      <div className="native-row">
        <input
          id="native-letter"
          className="native-input"
          value=draft
          placeholder={tr.typeLetter}
          autoComplete="off"
          autoCapitalize="characters"
          spellCheck=false
          maxLength=2
          disabled={!playing}
          onChange={e => {
            let value = ReactEvent.Form.target(e)["value"]
            onDraftChange(value)
          }}
        />
        {hasClear
          ? <button
              type_="button"
              className="ghost native-clear"
              onClick={_ =>
                if selected != "" {
                  onSelect(selected)
                } else {
                  onClearPick()
                }}>
              {React.string(`× ${tr.clearPicked}`)}
            </button>
          : React.null}
      </div>
    </div>
    {keyboardRows
    ->Belt.Array.mapWithIndex((ri, row) =>
      <div key={ri->Belt.Int.toString} className="kb-row">
        {row
        ->Belt.Array.map(letter => {
          // a fully placed letter leaves for the board; one that spells none of
          // the words leaves because there is nowhere left to put it
          let isUsed = usedUp->Belt.Array.some(l => l == letter)
          let isAbsent = absent->Belt.Array.some(l => l == letter)
          let gone = isUsed || isAbsent
          let cls = switch (isUsed, isAbsent, selected == letter) {
          | (true, _, _) => "key used"
          | (_, true, _) => "key absent"
          | (_, _, true) => "key selected"
          | _ => "key"
          }
          <DndKit.Draggable
            key=letter
            letter
            label=letter
            className=cls
            disabled=gone
            dragDisabled={gone || status != "playing"}
            onClick={_ => onSelect(letter)}
          />
        })
        ->React.array}
      </div>
    )
    ->React.array}
    {status == "won" ? <VictoryDrive /> : React.null}
  </div>
}
