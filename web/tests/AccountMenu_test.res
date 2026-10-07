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

// The grid must end on the viewer's local today: a UTC-based window leaves
// players east of UTC with no cell for today and players west of UTC with an
// empty future cell.
describe("AccountMenu.toLocalToday", () => {
  // local YYYY-MM-DD n days ago, via noon to dodge DST edges
  let dayOffset: int => string = %raw(`(n) => { const d = new Date(); d.setHours(12, 0, 0, 0); d.setDate(d.getDate() - n); const m = String(d.getMonth() + 1).padStart(2, "0"); const day = String(d.getDate()).padStart(2, "0"); return d.getFullYear() + "-" + m + "-" + day }`)

  test("a window ending today is left alone", t => {
    let days = [1, 0, 3, 0, 0, 2, 0, 0, 0, 4]
    t->expect(AccountMenu.toLocalToday(days, dayOffset(9)))->Expect.toEqual(days)
  })

  test("a window ending yesterday gains today's empty cell", t => {
    let days = [1, 0, 3, 0, 0, 2, 0, 0, 0, 4]
    t
    ->expect(AccountMenu.toLocalToday(days, dayOffset(10)))
    ->Expect.toEqual(Belt.Array.concat(days, [0]))
  })

  test("a window ending tomorrow loses its future cell", t => {
    let days = [1, 0, 3, 0, 0, 2, 0, 0, 0, 4]
    t
    ->expect(AccountMenu.toLocalToday(days, dayOffset(8)))
    ->Expect.toEqual(Belt.Array.slice(days, ~offset=0, ~len=9))
  })

  test("a window far from today is left alone rather than blown up", t => {
    let days = [1, 0, 3, 0, 0, 2, 0, 0, 0, 4]
    t->expect(AccountMenu.toLocalToday(days, dayOffset(30)))->Expect.toEqual(days)
  })
})
