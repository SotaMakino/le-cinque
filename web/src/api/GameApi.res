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

let fetchGame = async (): result<Game.game, ApiClient.apiError> =>
  await decode(await ApiClient.request("/game"))

let fetchMe = async (): result<Game.me, ApiClient.apiError> =>
  await decode(await ApiClient.request("/me"))

let guess = async (~letter, ~word, ~position): result<Game.game, ApiClient.apiError> =>
  await decode(
    await ApiClient.request(
      "/game/guess",
      ~method_="POST",
      ~body={"guess": letter, "word": word, "position": position},
    ),
  )

// start (or re-deal) a round at the given path, e.g. "/game"
let start = async (path): result<Game.game, ApiClient.apiError> =>
  await decode(await ApiClient.request(path, ~method_="POST"))

let setDirection = async (dir): result<Game.game, ApiClient.apiError> =>
  await decode(
    await ApiClient.request("/game/direction", ~method_="POST", ~body={"direction": dir}),
  )
