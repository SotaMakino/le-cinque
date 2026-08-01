// Minimal zero-cost bindings to @testing-library/react — only what the tests use.
// Community binding packages predate ReScript v11 / React 19, so we bind by hand.

type renderResult

@module("@testing-library/react")
external render: React.element => renderResult = "render"

// the rendered markup, for the classes and counts no role query reaches
@get external container: renderResult => Dom.element = "container"
@send external querySelectorAll: (Dom.element, string) => array<Dom.element> = "querySelectorAll"
@get external className: Dom.element => string = "className"
let length = (nodes: array<Dom.element>) => Belt.Array.length(nodes)

@module("@testing-library/react")
external cleanup: unit => unit = "cleanup"

type queryOptions = {name?: string}

type screen
@module("@testing-library/react")
external screen: screen = "screen"

@send
external getByRole: (screen, string, ~options: queryOptions=?) => Dom.element = "getByRole"

@send external getByText: (screen, string) => Dom.element = "getByText"

type fireEvent
@module("@testing-library/react")
external fireEvent: fireEvent = "fireEvent"

@send external click: (fireEvent, Dom.element) => unit = "click"

@get external textContent: Dom.element => string = "textContent"
