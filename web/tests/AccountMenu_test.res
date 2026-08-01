open Vitest

// The calendar's four shades are relative to the days actually practised, so
// these check the spread rather than any fixed word count.
let shadeOf = activity => AccountMenu.shades(activity)

describe("AccountMenu.shades", () => {
  test("an idle day stays unshaded", t => {
    t->expect(shadeOf([0, 3, 8])(0))->Expect.toBe("0")
  })

  test("a lone busy day among many quiet ones still spreads the shades", t => {
    let shade = shadeOf([6, 0, 0, 10, 0, 0, 40])
    t->expect(shade(6))->Expect.toBe("2")
    t->expect(shade(10))->Expect.toBe("3")
    t->expect(shade(40))->Expect.toBe("4")
  })

  test("the busiest day is always the darkest", t => {
    t->expect(shadeOf([1, 2, 3, 4])(4))->Expect.toBe("4")
    t->expect(shadeOf([7])(7))->Expect.toBe("4")
  })

  test("equal days share a shade", t => {
    let shade = shadeOf([5, 5, 5, 5])
    t->expect(shade(5))->Expect.toBe("4")
  })
})
