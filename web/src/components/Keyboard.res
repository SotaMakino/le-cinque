let keyboardRows = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["Z", "X", "C", "V", "B", "N", "M"],
]

// The on-screen QWERTY keyboard. A letter can be tapped to select it or dragged
// onto a tile; a letter with nowhere left to go leaves the keyboard. Winning
// hands the emptied keyboard over to the victory lap, which drives the gaps.
@react.component
let make = (~usedUp, ~absent, ~selected, ~status, ~onSelect) =>
  <div className="keyboard">
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
