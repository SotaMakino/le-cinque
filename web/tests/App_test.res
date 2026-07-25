open Vitest

describe("App.tileColor", () => {
  test("maps noun gender to the tricolore tile colors", t => {
    t->expect(App.tileColor("m"))->Expect.toBe(App.masculineColor)
    t->expect(App.tileColor("f"))->Expect.toBe(App.feminineColor)
  })

  test("falls back to neutral gray for non-nouns and unknown values", t => {
    t->expect(App.tileColor(""))->Expect.toBe(App.neutralColor)
    t->expect(App.tileColor("x"))->Expect.toBe(App.neutralColor)
  })
})
