// The game's shared data model: the shapes the API returns, plus the tile
// coloring derived from a noun's gender.

// prompt = the word shown in full; tiles = the answer being spelled ("" = hidden).
// Which language is which depends on the round's direction.
type pair = {prompt: string, tiles: array<string>, gender: string} // gender: "m" | "f" | ""

// guest = true means anonymous play; a signed-in account shows its name + count.
// plays is the global tally of rounds dealt (all players), shown as the issue N.
type me = {
  username: string,
  learned: int,
  guest: bool,
  plays: int,
  activity: array<int>, // dense daily retrieval counts, oldest first (a Sunday)
  activityStart: string, // ISO date of activity[0], so each cell can be dated
  yearWords: int, // total genuine retrievals since 1 January (year-to-date)
}

type game = {
  id: int,
  status: string, // "playing" | "won" | "lost" ("lost" = flagged for review)
  direction: string, // "it" = spell the English word; "en" = spell the Italian one
  pairs: array<pair>,
  guessed: array<string>,
  results: array<bool>, // parallel to guessed: true = correct placement
  wrong: array<string>,
  usedUp: array<string>, // letters whose every occurrence is on the board
  maxMisses: int, // wrong placements allowed before the round is lost
}

// revealed letters wear the Italian flag by the word's gender: il verde for
// masculine nouns, il rosso for feminine ones (official tricolore values); any
// other word stays neutral gray
let masculineColor = "#008c45" // flag green
let feminineColor = "#cd212a" // flag red
let neutralColor = "#7a7a7a" // gray — not a gendered noun

// a pair's tiles are all tinted by its Italian noun gender: "m" green,
// "f" red, anything else (non-noun, or missing) neutral gray
let tileColor = gender =>
  switch gender {
  | "m" => masculineColor
  | "f" => feminineColor
  | _ => neutralColor
  }
