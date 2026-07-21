// Minimal zero-cost bindings to @testing-library/react — only what the tests use.
// Community binding packages predate ReScript v11 / React 19, so we bind by hand.

type renderResult

@module("@testing-library/react")
external render: React.element => renderResult = "render"

@module("@testing-library/react")
external cleanup: unit => unit = "cleanup"

type queryOptions = {name?: string}

type screen
@module("@testing-library/react")
external screen: screen = "screen"

@send
external getByRole: (screen, string, ~options: queryOptions=?) => Dom.element = "getByRole"

type fireEvent
@module("@testing-library/react")
external fireEvent: fireEvent = "fireEvent"

@send external click: (fireEvent, Dom.element) => unit = "click"

@get external textContent: Dom.element => string = "textContent"
