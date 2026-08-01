open Vitest
open TestingLibrary

afterEach(() => cleanup())

let pairs: array<Game.pair> = [{prompt: "gatto", tiles: ["c", "", ""], gender: "m"}]

let board = (~pending) =>
  <DndKit.DndContext>
    <Board
      pairs
      direction="it"
      selected="A"
      dragging=false
      shake=None
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
    let _ = render(board(~pending=Some({letter: "A", wordIndex: 0, position: 1})))
    let tile = screen->getByText("A")
    t->expect(tile->className)->Expect.toBe("tile pending")
  })

  test("the tile waiting on a ruling is no longer a drop target", t => {
    let r = render(board(~pending=Some({letter: "A", wordIndex: 0, position: 1})))
    t->expect(r->container->querySelectorAll(".tile.open")->length)->Expect.toBe(1)
  })

  test("with nothing in flight every empty tile is open", t => {
    let r = render(board(~pending=None))
    t->expect(r->container->querySelectorAll(".tile.open")->length)->Expect.toBe(2)
    t->expect(r->container->querySelectorAll(".tile.pending")->length)->Expect.toBe(0)
  })
})
