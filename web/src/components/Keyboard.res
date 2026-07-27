let keyboardRows = [
  ["Q", "W", "E", "R", "T", "Y", "U", "I", "O", "P"],
  ["A", "S", "D", "F", "G", "H", "J", "K", "L"],
  ["Z", "X", "C", "V", "B", "N", "M"],
]

// The on-screen QWERTY keyboard. A letter can be tapped to select it or dragged
// onto a tile; a fully placed letter greys out and leaves the board.
@react.component
let make = (~usedUp, ~selected, ~status, ~onSelect) =>
  <div className="keyboard">
    {keyboardRows
    ->Belt.Array.mapWithIndex((ri, row) =>
      <div key={ri->Belt.Int.toString} className="kb-row">
        {row
        ->Belt.Array.map(letter => {
          // a fully placed letter leaves the keyboard for the board
          let isUsed = usedUp->Belt.Array.some(l => l == letter)
          let cls = switch (isUsed, selected == letter) {
          | (true, _) => "key used"
          | (false, true) => "key selected"
          | _ => "key"
          }
          <DndKit.Draggable
            key=letter
            letter
            label=letter
            className=cls
            disabled=isUsed
            dragDisabled={isUsed || status != "playing"}
            onClick={_ => onSelect(letter)}
          />
        })
        ->React.array}
      </div>
    )
    ->React.array}
  </div>
