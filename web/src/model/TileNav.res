// Keyboard-only tile navigation: the arrow keys move a cursor across the open
// (empty) tiles of the board, snapping to a valid slot as the board fills up.
// Pure over the current pairs, so it stays independent of React state.

// open positions (empty tiles) in a given pair row, as tile indices
let openInRow = (pairs: array<Game.pair>, wi) =>
  switch pairs->Belt.Array.get(wi) {
  | Some(p) =>
    p.tiles
    ->Belt.Array.mapWithIndex((pos, l) => (pos, l))
    ->Belt.Array.keep(((_, l)) => l == "")
    ->Belt.Array.map(((pos, _)) => pos)
  | None => []
  }

let firstOpenTile = (pairs: array<Game.pair>) => {
  let rowCount = pairs->Belt.Array.length
  let rec go = wi =>
    if wi >= rowCount {
      None
    } else {
      switch openInRow(pairs, wi)->Belt.Array.get(0) {
      | Some(pos) => Some((wi, pos))
      | None => go(wi + 1)
      }
    }
  go(0)
}

// the open tile the arrows point at, snapped to a valid slot as the board fills
let activeTile = (pairs, cursor) =>
  switch cursor {
  | Some((wi, pos)) if openInRow(pairs, wi)->Belt.Array.some(p => p == pos) => Some((wi, pos))
  | _ => firstOpenTile(pairs)
  }

// nearest open tile in a row to a reference column, for vertical moves
let nearestOpenInRow = (pairs, wi, refPos) =>
  switch openInRow(pairs, wi)->Belt.Array.get(0) {
  | None => None
  | Some(first) =>
    let best =
      openInRow(pairs, wi)->Belt.Array.reduce(first, (acc, p) =>
        Js.Math.abs_int(p - refPos) < Js.Math.abs_int(acc - refPos) ? p : acc
      )
    Some((wi, best))
  }

let rec adjacentOpenRow = (pairs: array<Game.pair>, wi, refPos, step) =>
  if wi < 0 || wi >= pairs->Belt.Array.length {
    None
  } else {
    switch nearestOpenInRow(pairs, wi, refPos) {
    | Some(t) => Some(t)
    | None => adjacentOpenRow(pairs, wi + step, refPos, step)
    }
  }

// the closest open tile to one side (left/right) within the same row
let closerOnSide = (opens, cpos, keepLeft) =>
  opens->Belt.Array.reduce(None, (acc, p) => {
    let onSide = keepLeft ? p < cpos : p > cpos
    if !onSide {
      acc
    } else {
      switch acc {
      | Some(a) =>
        let closer = keepLeft ? p > a : p < a
        closer ? Some(p) : acc
      | None => Some(p)
      }
    }
  })

// the target tile for an arrow-key move from `current`, or None when the board
// edge blocks it in that direction
let moveTarget = (pairs, (cwi, cpos), dir) =>
  switch dir {
  | #left => closerOnSide(openInRow(pairs, cwi), cpos, true)->Belt.Option.map(p => (cwi, p))
  | #right => closerOnSide(openInRow(pairs, cwi), cpos, false)->Belt.Option.map(p => (cwi, p))
  | #up => adjacentOpenRow(pairs, cwi - 1, cpos, -1)
  | #down => adjacentOpenRow(pairs, cwi + 1, cpos, 1)
  }
