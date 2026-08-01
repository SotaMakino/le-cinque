open Vitest
open TestingLibrary

afterEach(() => cleanup())

let pairs: array<Game.pair> = [{prompt: "gatto", tiles: ["c", "", ""], gender: "m"}]

let board = (~pending=None, ~shake=None, ()) =>
  <DndKit.DndContext>
    <Board
      pairs
      direction="it"
      selected="A"
      dragging=false
      shake
      pending
      navMode=false
      activeTile=None
      authenticated=false
      lang=#en
      onPlace={(_, _, _) => ()}
    />
  </DndKit.DndContext>

describe("Board", () => {
  test("a tile the server has not ruled on already wears its letter", t => {
    let _ = render(board(~pending=Some({letter: "A", wordIndex: 0, position: 1}), ()))
    t->expect(screen->getByText("A")->className)->Expect.toBe("tile pending")
  })

  test("the tile waiting on a ruling is no longer a drop target", t => {
    let r = render(board(~pending=Some({letter: "A", wordIndex: 0, position: 1}), ()))
    t->expect(r->container->querySelectorAll(".tile.open")->length)->Expect.toBe(1)
  })

  test("with nothing in flight every empty tile is open", t => {
    let r = render(board())
    t->expect(r->container->querySelectorAll(".tile.open")->length)->Expect.toBe(2)
    t->expect(r->container->querySelectorAll(".tile.pending")->length)->Expect.toBe(0)
  })

  test("a refused letter stays in its tile while it shakes", t => {
    let r = render(board(~shake=Some({letter: "Z", wordIndex: 0, position: 2}), ()))
    t->expect(screen->getByText("Z")->className)->Expect.toBe("tile-rejected")
    t->expect(r->container->querySelectorAll(".tile.open.shake")->length)->Expect.toBe(1)
  })

  test("only the refused tile shakes, and only while the shake lasts", t => {
    let r = render(board())
    t->expect(r->container->querySelectorAll(".shake")->length)->Expect.toBe(0)
    t->expect(r->container->querySelectorAll(".tile-rejected")->length)->Expect.toBe(0)
  })
})
