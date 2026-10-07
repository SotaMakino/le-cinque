// Raw DOM bindings the app drives directly: window.confirm, the physical
// keyboard listener, and the pointer listener that dismisses transient UI.

@val @scope("window") external confirmDialog: string => bool = "confirm"

type keyboardEvent
@get external eventKey: keyboardEvent => string = "key"
@get external ctrlKey: keyboardEvent => bool = "ctrlKey"
@get external metaKey: keyboardEvent => bool = "metaKey"
@get external altKey: keyboardEvent => bool = "altKey"
@val @scope("document")
external addKeyListener: (string, keyboardEvent => unit) => unit = "addEventListener"
@val @scope("document")
external removeKeyListener: (string, keyboardEvent => unit) => unit = "removeEventListener"
@send external preventDefault: keyboardEvent => unit = "preventDefault"
type domTarget
@get external eventTarget: keyboardEvent => domTarget = "target"
@get external targetTag: domTarget => string = "tagName"
@get external targetEditable: domTarget => bool = "isContentEditable"

// element geometry, so the victory lap can route its car through the gaps the
// won round burned into the keyboard
type domRect = {left: float, top: float, width: float, height: float}
@send external boundingRect: Dom.element => domRect = "getBoundingClientRect"
@get @return(nullable) external parentElement: Dom.element => option<Dom.element> = "parentElement"
type nodeList
@send external queryAll: (Dom.element, string) => nodeList = "querySelectorAll"
@val @scope("Array") external nodeArray: nodeList => array<Dom.element> = "from"
// the page's width without its scrollbar, which is what CSS lays out against
@val @scope(("document", "documentElement")) external clientWidth: int = "clientWidth"
@val @scope("window")
external addWindowListener: (string, unit => unit) => unit = "addEventListener"
@val @scope("window")
external removeWindowListener: (string, unit => unit) => unit = "removeEventListener"

type pointerEvent
@val @scope("document")
external addPointerListener: (string, pointerEvent => unit) => unit = "addEventListener"
@val @scope("document")
external removePointerListener: (string, pointerEvent => unit) => unit = "removeEventListener"
type domNode
@get external pointerTarget: pointerEvent => domNode = "target"
@send @return(nullable) external closest: (domNode, string) => option<domNode> = "closest"
@send external blur: domNode => unit = "blur"
@val @scope("document") external activeElement: domNode = "activeElement"

// focusing the narrow native input after a tile is picked, so the OS keyboard
// opens straight onto the chosen slot. No-op when the input isn't rendered
// (roomy layouts hide it with display: none).
@val @scope("document")
external getById: string => Js.Nullable.t<Dom.element> = "getElementById"
@send external focusEl: Dom.element => unit = "focus"
let focusNativeInput = () =>
  switch getById("native-letter")->Js.Nullable.toOption {
  | Some(el) => el->focusEl
  | None => ()
  }
