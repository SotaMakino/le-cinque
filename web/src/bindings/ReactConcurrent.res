// React 19's action hooks, which @rescript/react 0.13 does not bind yet.
// What both are for here is one commit: an optimistic value stays on screen for
// exactly as long as the action that made it is in flight, and is dropped in the
// very render that shows the server's answer — no gap in between for the board
// to flicker through.

@module("react")
external useOptimistic: ('state, ('state, 'action) => 'state) => ('state, 'action => unit) =
  "useOptimistic"

// Typed to take an async action, unlike React.useTransition: React 19 keeps the
// updates made after an await inside the same transition, so the pending flag
// stays raised — and the optimistic value stays put — until the request settles.
@module("react")
external useTransition: unit => (bool, (unit => promise<unit>) => unit) = "useTransition"
