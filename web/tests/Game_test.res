open Vitest

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
