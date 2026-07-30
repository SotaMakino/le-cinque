// How many rounds have been won in a row. It is kept in the browser and nowhere
// else: the API is neither told about it nor asked for it, so a streak is a
// private thing between a player and the machine they play on. The victory lap
// reads it to decide how long a convoy comes down the road — one car for the win
// itself, and one more for every win standing behind it.
//
// Two values are kept: the streak, and the id of the last round it counted. The
// second is what makes the first honest — a finished round arrives again on every
// reload, and a round already counted must not be counted twice.

type storage
@val @scope("window") @return(nullable) external localStorage: option<storage> = "localStorage"
@send @return(nullable) external getItem: (storage, string) => option<string> = "getItem"
@send external setItem: (storage, string, string) => unit = "setItem"

let streakKey = "cinque:streak"
let roundKey = "cinque:streak-round"

let longest = 5 // as many cars as the road will hold at once, tricolore and all

// Storage is a privilege, not a given: a browser with it turned off throws on the
// first touch of window.localStorage rather than handing back a null, and a
// player who has just won five in a row should not be shown a stack trace for it.
// So every read and write is allowed to fail, and a failed read is no streak.
let read = key =>
  try {
    switch localStorage {
    | Some(s) => s->getItem(key)->Belt.Option.flatMap(Belt.Int.fromString)
    | None => None
    }
  } catch {
  | _ => None
  }

let write = (key, value) =>
  try {
    switch localStorage {
    | Some(s) => s->setItem(key, value->Belt.Int.toString)
    | None => ()
    }
  } catch {
  | _ => ()
  }

// the streak as it stands
let current = () => read(streakKey)->Belt.Option.getWithDefault(0)

// Every round the API hands back passes through here. A won round adds to the
// streak and a lost one ends it, both exactly once: the same round coming round
// again — a reload, a refetch, a letter dropped on a board already won — is a
// round this has seen, and it is left alone.
let record = (~gameId, ~status) =>
  if read(roundKey) != Some(gameId) {
    switch status {
    | "won" => {
        write(roundKey, gameId)
        write(streakKey, current() + 1)
      }
    | "lost" => {
        write(roundKey, gameId)
        write(streakKey, 0)
      }
    | _ => () // still playing: nothing is settled yet
    }
  }

// the cars a streak puts on the road. A win is always worth one, whatever the
// storage did or did not remember.
let cars = streak =>
  if streak < 1 {
    1
  } else if streak > longest {
    longest
  } else {
    streak
  }
