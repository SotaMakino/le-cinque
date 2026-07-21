open Vitest
open TestingLibrary

afterEach(() => cleanup())

describe("AuthForm", () => {
  test("renders the login form by default", t => {
    let _ = render(<AuthForm onSuccess={() => ()} />)
    t->expect(screen->getByRole("heading")->textContent)->Expect.toBe("Log in")
  })

  test("switches to signup mode via the link button", t => {
    let _ = render(<AuthForm onSuccess={() => ()} />)
    fireEvent->click(screen->getByRole("button", ~options={name: "Sign up"}))
    t->expect(screen->getByRole("heading")->textContent)->Expect.toBe("Sign up")
  })
})
