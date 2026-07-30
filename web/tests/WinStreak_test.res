open Vitest

// The streak lives in the browser, so the browser is what these drive: every
// test starts with the storage swept, the way a first-ever visit finds it.
@val @scope(("window", "localStorage")) external clearStorage: unit => unit = "clear"

let played = (~gameId, ~status) => WinStreak.record(~gameId, ~status)

beforeEach(() => clearStorage())

describe("WinStreak.record", () => {
  test("a first win is a streak of one, and nothing before it is assumed", t => {
    played(~gameId=1, ~status="won")
    t->expect(WinStreak.current())->Expect.toBe(1)
  })

  test("counts wins in a row", t => {
    played(~gameId=1, ~status="won")
    played(~gameId=2, ~status="won")
    played(~gameId=3, ~status="won")
    t->expect(WinStreak.current())->Expect.toBe(3)
  })

  test("a loss ends it, and the next win starts again from one", t => {
    played(~gameId=1, ~status="won")
    played(~gameId=2, ~status="won")
    played(~gameId=3, ~status="lost")
    t->expect(WinStreak.current())->Expect.toBe(0)
    played(~gameId=4, ~status="won")
    t->expect(WinStreak.current())->Expect.toBe(1)
  })

  test("counts a round once, however many times it comes round again", t => {
    played(~gameId=7, ~status="won")
    // the same finished round, as every reload of it hands it back
    played(~gameId=7, ~status="won")
    played(~gameId=7, ~status="won")
    t->expect(WinStreak.current())->Expect.toBe(1)
  })

  test("settles nothing while the round is still being played", t => {
    played(~gameId=1, ~status="won")
    played(~gameId=2, ~status="playing")
    t->expect(WinStreak.current())->Expect.toBe(1)
    // and the round it was in the middle of still counts when it is won
    played(~gameId=2, ~status="won")
    t->expect(WinStreak.current())->Expect.toBe(2)
  })
})

describe("WinStreak.cars", () => {
  test("puts one car on the road per win", t => {
    t->expect(WinStreak.cars(1))->Expect.toBe(1)
    t->expect(WinStreak.cars(3))->Expect.toBe(3)
  })

  test("a win is worth a car even with no streak behind it", t => {
    t->expect(WinStreak.cars(0))->Expect.toBe(1)
    t->expect(WinStreak.cars(-2))->Expect.toBe(1)
  })

  test("stops at what the road holds", t => {
    t->expect(WinStreak.cars(WinStreak.longest + 1))->Expect.toBe(WinStreak.longest)
    t->expect(WinStreak.cars(400))->Expect.toBe(WinStreak.longest)
  })
})
