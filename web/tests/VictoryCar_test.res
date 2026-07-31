open Vitest

// Every number written into a path, whatever it means there — a coordinate, an
// arc radius, a flag, or a relative step back the way a round lamp is drawn.
// None of them is large in a drawing this size, so a bound on the lot of them is
// what catches the typo that matters: a decimal point dropped out of 38.0, which
// would throw part of a car clean off the canvas.
let numbers = d =>
  d
  ->Js.String2.splitByRe(%re("/[^0-9.\-]+/"))
  ->Belt.Array.keepMap(part =>
    switch part {
    | Some("") | None => None
    | Some(s) => Belt.Float.fromString(s)
    }
  )

let paths = (car: VictoryCar.car) =>
  [[car.body, car.glass, car.lamp, car.tail], car.seams, car.bumpers]->Belt.Array.concatMany

describe("VictoryCar.cars", () => {
  test("every one of them is drawn, and drawn differently", t => {
    t->expect(VictoryCar.cars->Belt.Array.length)->Expect.toBe(4)
    let names = VictoryCar.cars->Belt.Array.map((c: VictoryCar.car) => c.name)
    t->expect(Belt.Set.String.fromArray(names)->Belt.Set.String.size)->Expect.toBe(4)
    let bodies = VictoryCar.cars->Belt.Array.map((c: VictoryCar.car) => c.body)
    t->expect(Belt.Set.String.fromArray(bodies)->Belt.Set.String.size)->Expect.toBe(4)
  })

  test("keeps to the 100 by 45 units they all share", t =>
    VictoryCar.cars->Belt.Array.forEach(
      car => {
        let stray =
          paths(car)
          ->Belt.Array.map(numbers)
          ->Belt.Array.concatMany
          ->Belt.Array.keep(v => v < -12.0 || v > 105.0)
        t->expect((car.name, stray))->Expect.toEqual((car.name, []))
      },
    )
  )

  test("carries its wheels under itself, the front one ahead of the back", t =>
    VictoryCar.cars->Belt.Array.forEach(
      car => {
        let (rear, front) = car.axles
        t->expect((car.name, rear < front))->Expect.toEqual((car.name, true))
        t->expect((car.name, rear > 8.0 && front < 94.0))->Expect.toEqual((car.name, true))
      },
    )
  )

  test("closes every outline, so the paint has somewhere to sit", t =>
    VictoryCar.cars->Belt.Array.forEach(
      car => {
        let closed = d => d->Js.String2.trim->Js.String2.endsWith("Z")
        t
        ->expect((car.name, closed(car.body), closed(car.glass)))
        ->Expect.toEqual((car.name, true, true))
      },
    )
  )
})

describe("VictoryCar.paints", () => {
  test("every coat is a hex colour, and no two are the same", t => {
    let hex = %re("/^#[0-9a-f]{6}$/")
    VictoryCar.paints->Belt.Array.forEach(
      p => {
        t
        ->expect((p.name, hex->Js.Re.test_(p.body), hex->Js.Re.test_(p.hub)))
        ->Expect.toEqual((p.name, true, true))
      },
    )
    let bodies = VictoryCar.paints->Belt.Array.map((p: VictoryCar.paint) => p.body)
    t
    ->expect(Belt.Set.String.fromArray(bodies)->Belt.Set.String.size)
    ->Expect.toBe(VictoryCar.paints->Belt.Array.length)
  })
})

describe("VictoryCar.messages", () => {
  test("all say something, and none outgrows the tricolore", t =>
    VictoryCar.messages->Belt.Array.forEach(
      m => {
        // the run-out is measured for a banner about this long; a longer one would
        // still be on screen when the drive loops
        t->expect((m, m != "" && m->Js.String2.length <= 18))->Expect.toEqual((m, true))
      },
    )
  )
})

describe("VictoryCar.anyFew", () => {
  test("deals as many as asked for, all different and all from the hat", t =>
    Belt.Range.forEach(
      1,
      60,
      _ => {
        let few = VictoryCar.anyFew(VictoryCar.messages, WinStreak.longest)
        t->expect(few->Belt.Array.length)->Expect.toBe(WinStreak.longest)
        t
        ->expect(Belt.Set.String.fromArray(few)->Belt.Set.String.size)
        ->Expect.toBe(WinStreak.longest)
        t
        ->expect(few->Belt.Array.every(m => VictoryCar.messages->Belt.Array.some(x => x == m)))
        ->Expect.toBeTruthy
      },
    )
  )

  test("hands back the whole hat when asked for more than it holds", t => {
    let all = VictoryCar.anyFew(VictoryCar.messages, VictoryCar.messages->Belt.Array.length + 3)
    t->expect(all->Belt.Array.length)->Expect.toBe(VictoryCar.messages->Belt.Array.length)
    t
    ->expect(Belt.Set.String.fromArray(all)->Belt.Set.String.size)
    ->Expect.toBe(VictoryCar.messages->Belt.Array.length)
  })
})

describe("VictoryCar.anyOf", () => {
  test("always draws something that was in the hat", t =>
    Belt.Range.forEach(
      1,
      60,
      _ => {
        let m = VictoryCar.anyOf(VictoryCar.messages)
        t->expect(VictoryCar.messages->Belt.Array.some(x => x == m))->Expect.toBeTruthy
        let c: VictoryCar.car = VictoryCar.anyOf(VictoryCar.cars)
        t
        ->expect(VictoryCar.cars->Belt.Array.some((x: VictoryCar.car) => x.name == c.name))
        ->Expect.toBeTruthy
      },
    )
  )
})
