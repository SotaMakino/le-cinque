open Vitest

// a round as an API older than `absent` sends it: the field is not empty, it is
// simply not there. Built as raw JSON and read as a record, which is exactly what
// the client does to a response body.
let olderRound: Game.game = %raw(`{
  id: 1,
  status: "playing",
  direction: "it",
  pairs: [],
  guessed: ["Z"],
  results: [false],
  wrong: ["Z"],
  usedUp: ["A"],
  maxMisses: 5
}`)

describe("Game.received", () => {
  test("fills in the lists a service older than this build never sent", t => {
    let g = Game.received(olderRound)
    t->expect(g.absent)->Expect.toEqual([])
    // and asking about a letter no longer throws on the way through
    t->expect(Game.isSpent(g, "A"))->Expect.toBeTruthy
    t->expect(Game.isSpent(g, "Z"))->Expect.toBeFalsy
  })

  test("leaves a round that already carries them alone", t => {
    let g = Game.received({...olderRound, absent: ["Z"]})
    t->expect(g.absent)->Expect.toEqual(["Z"])
    t->expect(Game.isSpent(g, "Z"))->Expect.toBeTruthy
  })
})

describe("Game.tileColor", () => {
  test("maps noun gender to the tricolore tile colors", t => {
    t->expect(Game.tileColor("m"))->Expect.toBe(Game.masculineColor)
    t->expect(Game.tileColor("f"))->Expect.toBe(Game.feminineColor)
  })

  test("falls back to neutral gray for non-nouns and unknown values", t => {
    t->expect(Game.tileColor(""))->Expect.toBe(Game.neutralColor)
    t->expect(Game.tileColor("x"))->Expect.toBe(Game.neutralColor)
  })
})
