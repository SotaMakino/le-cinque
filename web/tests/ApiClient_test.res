open Vitest

describe("ApiClient.statusHint", () => {
  test("maps known statuses to human-readable hints", t => {
    t->expect(ApiClient.statusHint(401, "fallback"))->Expect.String.toContain("log in")
    t->expect(ApiClient.statusHint(409, "fallback"))->Expect.String.toContain("already exists")
    t->expect(ApiClient.statusHint(503, "fallback"))->Expect.String.toContain("down or restarting")
  })

  test("returns the fallback for unknown statuses", t => {
    t->expect(ApiClient.statusHint(418, "I'm a teapot"))->Expect.toBe("I'm a teapot")
  })
})
