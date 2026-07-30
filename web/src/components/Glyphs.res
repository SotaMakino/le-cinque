// The drawn glyphs: the two flags that pick the language and the speaker that
// pronounces a word. All three are drawn in the same hand as the victory car —
// flat colour under an ink outline, nothing straight that a drawn line would
// have curved.
//
// Both flags are cut from the same piece of cloth, and no pole: the flag is the
// whole glyph, so it can be as big as the box. `wave` is the top edge, and every
// band, stripe and star below is placed against those same numbers, so the
// flutter runs through the whole flag and not just its outline.

let at = v => Js.Float.toFixedWithPrecision(v, ~digits=1)

// the top edge of the cloth, dropped `dy` down the flag: three curves whose
// ends fall on the thirds, which is where the tricolore wants its seams
let wave = dy => {
  let y = v => at(v +. dy)
  `M1.4 ${y(2.4)} Q4.6 ${y(1.6)} 7.8 ${y(2.3)} Q11 ${y(3.0)} 14.2 ${y(2.4)} Q17.4 ${y(
      1.9,
    )} 20.6 ${y(2.1)}`
}

// the edge of the cloth: the wave along the top, down the fly, then the same
// wave 11.6 lower walked back the other way, and up the hoist to close
let cloth = wave(0.0) ++ " L20.6 13.7 Q17.4 13.5 14.2 14 Q11 14.6 7.8 13.9 Q4.6 13.2 1.4 14 Z"

// the outline, drawn last so it covers where the colours meet the edge
let hem = <path className="glyph-cloth" d=cloth />

module Tricolore = {
  // green, white and red, one band per third of the cloth
  @react.component
  let make = () =>
    <svg className="glyph glyph-flag" viewBox="0 0 22 16" ariaHidden=true>
      <path
        className="glyph-band"
        fill="#008c45"
        d="M1.4 2.4 Q4.6 1.6 7.8 2.3 L7.8 13.9 Q4.6 13.2 1.4 14 Z"
      />
      <path
        className="glyph-band"
        fill="#f4f5f0"
        d="M7.8 2.3 Q11 3 14.2 2.4 L14.2 14 Q11 14.6 7.8 13.9 Z"
      />
      <path
        className="glyph-band"
        fill="#cd212a"
        d="M14.2 2.4 Q17.4 1.9 20.6 2.1 L20.6 13.7 Q17.4 13.5 14.2 14 Z"
      />
      {hem}
    </svg>
}

module StarsAndStripes = {
  // Four stripes at this size, not thirteen: any more and they close up into a
  // pink smudge. They are the same wave stroked thick, so they flutter with the
  // cloth, and the white ground between them makes the seven bands.
  let stripes = [0.8, 4.1, 7.5, 10.8]

  // the canton, over the first half of the second curve — its right edge is
  // that curve split in two, so the corner sits on the wave and not beside it
  let canton = "M1.4 2.4 Q4.6 1.6 7.8 2.3 Q9.4 2.7 11 2.7 L11 8.9 L1.4 8.6 Z"
  let stars = [(3.3, 4.4), (6.1, 4.3), (8.9, 4.3), (3.4, 7.0), (6.2, 6.9), (9.0, 6.9)]

  @react.component
  let make = () =>
    <svg className="glyph glyph-flag" viewBox="0 0 22 16" ariaHidden=true>
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
          key={i->Belt.Int.toString} className="glyph-star" cx={at(cx)} cy={at(cy)} r="0.68"
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
