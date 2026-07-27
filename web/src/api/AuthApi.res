// map a request outcome to unit, keeping any error — the auth endpoints only
// care whether the call succeeded, not about the response body
let okUnit = (outcome: result<ApiClient.response, ApiClient.apiError>) =>
  switch outcome {
  | Ok(_) => Ok()
  | Error(e) => Error(e)
  }

let login = async (~username, ~password) =>
  okUnit(
    await ApiClient.request(
      "/login",
      ~method_="POST",
      ~body={"username": username, "password": password},
    ),
  )

let signup = async (~username, ~password) =>
  switch await ApiClient.request(
    "/signup",
    ~method_="POST",
    ~body={"username": username, "password": password},
  ) {
  | Ok(_) => await login(~username, ~password) // auto-log-in on a fresh signup
  | Error(e) => Error(e)
  }

let logout = async () => okUnit(await ApiClient.request("/logout", ~method_="POST"))

let deleteAccount = async () => okUnit(await ApiClient.request("/me", ~method_="DELETE"))
