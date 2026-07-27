// The mistake tracker: one dot per allowed miss, filled as they're spent, with
// a running count.
@react.component
let make = (~label, ~maxMisses, ~missCount) =>
  <div className="tries">
    <span className="tries-label"> {React.string(label)} </span>
    {Belt.Array.makeBy(maxMisses, i =>
      <span key={i->Belt.Int.toString} className={i < missCount ? "try-dot spent" : "try-dot"} />
    )->React.array}
    <span className="tries-count">
      {React.string(`${missCount->Belt.Int.toString} / ${maxMisses->Belt.Int.toString}`)}
    </span>
  </div>
