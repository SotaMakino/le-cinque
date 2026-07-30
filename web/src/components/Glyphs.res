// The drawn glyphs: the two flags that pick the language and the speaker that
// pronounces a word. All three are drawn in the same hand as the victory car —
// flat colour under an ink outline, nothing straight that a drawn line would
// have curved.
//
// Both flags are cut from the same piece of cloth. `wave` is its top edge, and
// every band, stripe and star below is placed against those same numbers, so
// the flutter runs through the whole flag and not just its outline.

let at = v => Js.Float.toFixedWithPrecision(v, ~digits=1)

// the top edge of the cloth, dropped `dy` down the flag: three curves whose
// ends fall on the thirds, which is where the tricolore wants its seams
let wave = dy => {
  let y = v => at(v +. dy)
  `M4.6 ${y(4.4)} Q7.3 ${y(3.5)} 10 ${y(4.2)} Q12.7 ${y(4.9)} 15.4 ${y(4.3)} Q18 ${y(3.8)} 20.8 ${y(
      4.0,
    )}`
}

// the edge of the cloth: the wave along the top, down the fly, then the same
// wave 9.8 lower walked back the other way, and up the hoist to close
let cloth = wave(0.0) ++ " L20.8 13.8 Q18 13.6 15.4 14.1 Q12.7 14.7 10 14 Q7.3 13.3 4.6 14.2 Z"

// the pole the cloth hangs from, a touch proud of it at both ends
let pole = <path className="glyph-pole" d="M3.5 2.9 V21.1" />

// the outline, drawn last so it covers where the colours meet the edge
let hem = <path className="glyph-cloth" d=cloth />

module Tricolore = {
  // green, white and red, one band per third of the cloth
  @react.component
  let make = () =>
    <svg className="glyph glyph-flag" viewBox="0 0 24 24" ariaHidden=true>
      {pole}
      <path
        className="glyph-band"
        fill="#008c45"
        d="M4.6 4.4 Q7.3 3.5 10 4.2 L10 14 Q7.3 13.3 4.6 14.2 Z"
      />
      <path
        className="glyph-band"
        fill="#f4f5f0"
        d="M10 4.2 Q12.7 4.9 15.4 4.3 L15.4 14.1 Q12.7 14.7 10 14 Z"
      />
      <path
        className="glyph-band"
        fill="#cd212a"
        d="M15.4 4.3 Q18 3.8 20.8 4 L20.8 13.8 Q18 13.6 15.4 14.1 Z"
      />
      {hem}
    </svg>
}

module StarsAndStripes = {
  // Four stripes at this size, not thirteen: any more and they close up into a
  // pink smudge. They are the same wave stroked thick, so they flutter with the
  // cloth, and the union with the white beneath them makes the seven bands.
  let stripes = [0.7, 3.5, 6.3, 9.1]

  // the canton, over the first half of the second curve — its right edge is
  // that curve split in two, so the corner sits on the wave and not beside it
  let canton = "M4.6 4.4 Q7.3 3.5 10 4.2 Q11.4 4.6 12.7 4.6 L12.7 9.5 L4.6 9.3 Z"
  let stars = [(6.2, 6.0), (8.7, 5.9), (11.2, 5.8), (6.3, 8.0), (8.8, 7.9), (11.3, 7.8)]

  @react.component
  let make = () =>
    <svg className="glyph glyph-flag" viewBox="0 0 24 24" ariaHidden=true>
      {pole}
      <path className="glyph-band" fill="#f4f5f0" d=cloth />
      {stripes
      ->Belt.Array.mapWithIndex((i, dy) =>
        <path key={i->Belt.Int.toString} className="glyph-stripe" d={wave(dy)} />
      )
      ->React.array}
      <path className="glyph-band" fill="#2c3268" d=canton />
      {stars
      ->Belt.Array.mapWithIndex((i, (cx, cy)) =>
        <circle
          key={i->Belt.Int.toString} className="glyph-star" cx={at(cx)} cy={at(cy)} r="0.62"
        />
      )
      ->React.array}
      {hem}
    </svg>
}

module Speaker = {
  // A speaker: the box, the cone it opens into, and two waves coming off it.
  @react.component
  let make = () =>
    <svg className="glyph glyph-speaker" viewBox="0 0 24 24" ariaHidden=true>
      <path className="glyph-horn" d="M4 9.4 H7.6 L12.8 5 V19 L7.6 14.6 H4 Z" />
      <path className="glyph-sound" d="M15.6 9.4 Q17.6 12 15.6 14.6" />
      <path className="glyph-sound" d="M18.6 7 Q22 12 18.6 17" />
    </svg>
}
