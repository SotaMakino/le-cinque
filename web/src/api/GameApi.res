// The game endpoints, typed. Each performs the request and decodes a successful
// JSON body, returning the value or the raw ApiClient error — state handling
// (which errors show a notice vs. a banner) stays with the caller.

// run a request outcome to a decoded body, threading the error through
let decode = async (outcome: result<ApiClient.response, ApiClient.apiError>): result<
  'a,
  ApiClient.apiError,
> =>
  switch outcome {
  | Ok(res) => Ok(await ApiClient.json(res))
  | Error(e) => Error(e)
  }

// The same, for the one body the app reads as a record of lists: a round is
// filled out on the way in, so a service older than this build cannot leave a
// field undefined under the UI (see Game.received). Every endpoint that returns
// a round goes through here — that is the whole point of it.
let decodeGame = async (outcome): result<Game.game, ApiClient.apiError> =>
  switch await decode(outcome) {
  | Ok(g) => Ok(Game.received(g))
  | Error(e) => Error(e)
  }

let fetchGame = async (): result<Game.game, ApiClient.apiError> =>
  await decodeGame(await ApiClient.request("/game"))

let fetchMe = async (): result<Game.me, ApiClient.apiError> =>
  await decode(await ApiClient.request("/me"))

let guess = async (~letter, ~word, ~position): result<Game.game, ApiClient.apiError> =>
  await decodeGame(
    await ApiClient.request(
      "/game/guess",
      ~method_="POST",
      ~body={"guess": letter, "word": word, "position": position},
    ),
  )

// start (or re-deal) a round at the given path, e.g. "/game"
let start = async (path): result<Game.game, ApiClient.apiError> =>
  await decodeGame(await ApiClient.request(path, ~method_="POST"))

let setDirection = async (dir): result<Game.game, ApiClient.apiError> =>
  await decodeGame(
    await ApiClient.request("/game/direction", ~method_="POST", ~body={"direction": dir}),
  )
