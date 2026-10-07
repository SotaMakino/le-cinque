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
      pickedTile=None
      authenticated=false
      lang=#en
      onPlace={(_, _, _) => ()}
      onPick={(_, _) => ()}
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

  test("a picked tile wears the cursor ring even outside arrow-key mode", t => {
    let r = render(
      <DndKit.DndContext>
        <Board
          pairs
          direction="it"
          selected=""
          dragging=false
          shake=None
          pending=None
          navMode=false
          activeTile=None
          pickedTile=Some((0, 1))
          authenticated=false
          lang=#en
          onPlace={(_, _, _) => ()}
          onPick={(_, _) => ()}
        />
      </DndKit.DndContext>,
    )
    t->expect(r->container->querySelectorAll(".tile.open.tile-cursor")->length)->Expect.toBe(1)
  })

  test("tapping with no letter in hand picks the tile instead of placing", t => {
    let picked = ref(None)
    let placed = ref(false)
    let r = render(
      <DndKit.DndContext>
        <Board
          pairs
          direction="it"
          selected=""
          dragging=false
          shake=None
          pending=None
          navMode=false
          activeTile=None
          pickedTile=None
          authenticated=false
          lang=#en
          onPlace={(_, _, _) => placed := true}
          onPick={(wi, pos) => picked := Some((wi, pos))}
        />
      </DndKit.DndContext>,
    )
    switch r->container->querySelectorAll(".tile.open")->Belt.Array.get(0) {
    | Some(tile) => fireEvent->click(tile)
    | None => ()
    }
    t->expect(picked.contents)->Expect.toEqual(Some((0, 1)))
    t->expect(placed.contents)->Expect.toBe(false)
  })

  test("tapping with a letter in hand still places it", t => {
    let picked = ref(false)
    let placed = ref(None)
    let r = render(
      <DndKit.DndContext>
        <Board
          pairs
          direction="it"
          selected="A"
          dragging=false
          shake=None
          pending=None
          navMode=false
          activeTile=None
          pickedTile=None
          authenticated=false
          lang=#en
          onPlace={(letter, wi, pos) => placed := Some((letter, wi, pos))}
          onPick={(_, _) => picked := true}
        />
      </DndKit.DndContext>,
    )
    switch r->container->querySelectorAll(".tile.open")->Belt.Array.get(0) {
    | Some(tile) => fireEvent->click(tile)
    | None => ()
    }
    t->expect(placed.contents)->Expect.toEqual(Some(("A", 0, 1)))
    t->expect(picked.contents)->Expect.toBe(false)
  })
})
