# Testing

The rules every test follows, in any language. The language file decides how they're spelled.

## Test-first by default

Every behaviour change starts with a failing test, following the `tdd` skill. Skip it only for the cases that skill lists, or when I opt out.

## Pick the layer

Before writing a test, decide the layer for its seam (the public interface it goes through) and say why in one line.

A **boundary** is anything outside the process's own memory: network, database, filesystem, clock, randomness, environment variables, subprocesses.

| The code under test… | Layer | Doubles |
|---|---|---|
| computes a result from its inputs, with no I/O | **unit** | none |
| makes decisions, reaching I/O only through an injected dependency | **unit** | a hand-written fake for that dependency |
| *is* the boundary: builds or parses HTTP, runs SQL, reads or writes files, encodes a wire format | **integration** | none on our side: a real HTTP stack, a real database, a real temp directory |
| a flow across several of the above | **one integration test** for the happy path, **unit tests** for every branch | as above |

- **Test logic at the unit level, and each boundary for real, once.** Don't re-run unit-level branches through an integration test.
- **Services I don't run**, like a third-party API, are replaced by a local server that speaks their contract. The HTTP stack in between stays real.
- **Heavy mocking is a design signal.** A unit test that needs it is testing code that mixes logic and I/O: split the code instead of mocking deeper.
- **End-to-end tests** (whole system, browser or device) only where the repo already has a suite, or when I ask.

For a client that sends `POST /v1/orders`: parsing the price is **unit**; the request it sends and how it reads the response is **integration**, against a local server.

## Name it as a sentence

A test's name is a path: **subject → group → behaviour**.

- **Subject:** the thing under test, exactly as the code or API names it: `POST /v1/orders`, `parsePrice`. The only part that may contain symbols. One subject per block, never an `A -> B` mapping.
- **Group:** optional, at most one level. A short lowercase noun phrase for the aspect under test: `contract matching`, `validation`, `retries`.
- **Behaviour:** lowercase, opening with a present-tense verb, outcome first and condition second: `returns created order from valid request`, `rejects negative amount`. No punctuation, no "should", no "correctly". One behaviour: a name that needs "and" is two tests.

| | Subject | Group | Behaviour |
|---|---|---|---|
| TypeScript | `describe('POST /v1/orders')` | `describe('contract matching')` | `it('returns created order from valid request')` |
| Go | `TestPostOrders_` | none | `ReturnsCreatedOrderFromValidRequest` |
| Rust | `mod post_orders` | `mod contract_matching` | `fn returns_created_order_from_valid_request` |

## Shape of a test

- **Assert what a caller can observe:** return values, responses, errors, state read back through the public interface, messages sent across a boundary. Never private fields, internal call counts, or a side channel like querying the table a repository wraps.
- **Expected values come from an independent source:** a literal, a worked example, the spec. Never recompute them the way the code does, or the test can't fail.
- **Keep setup visible.** Build inputs in the test. Move setup into a hook or helper once two tests share it, and keep hooks at the subject level.
- **Helpers go at the top of the file**, after the imports and before the first test.
- **Parameterise** when two or more cases share setup and assertion and differ only in data. Name each case by its condition.
- **Tests are independent:** no order dependence, no shared mutable state, and every test undoes what it sets up.
- **No sleeps.** Wait on a signal (a promise, a channel, a poll with a deadline) or control time with a fake clock.
- **Inject time, randomness, and environment** instead of reading globals, so a test can set them directly.

## Test doubles

| Double | What it is | Use it when |
|---|---|---|
| **Fake** | a working, simplified implementation: an in-memory store, a local HTTP server | by default |
| **Stub** | returns canned answers and checks nothing | the dependency only feeds inputs in |
| **Mock** | records calls so the test can assert on them | the call itself is the behaviour, and no fake can observe it |

- **Double only boundaries.** Never your own modules, internal collaborators, or the unit under test.
- **Hand-write doubles** before reaching for a mocking library, and name them for what they are: `fakeStore`, `stubClock`.
- **Inject dependencies** so a test can pass a double in. Code that builds its own client can only be tested by patching modules.

  ```ts
  // Easy to double
  function createOrder(order: NewOrder, http: HttpClient) {
    return http.post('/v1/orders', order);
  }

  // Needs module patching
  function createOrder(order: NewOrder) {
    return new HttpClient(process.env.API_URL).post('/v1/orders', order);
  }
  ```

- **One function per external operation** (`getUser`, `createOrder`), not one generic `request(endpoint, options)`. Each double then returns one shape, with no branching on the endpoint.

## Where tests live

1. **Follow the repo.** Find where its unit and integration tests already live before creating a file. Integration tests may live in a separate repo; when they do, put new ones there and say so.
2. **Unit tests** sit with the code, as the language file describes.
3. **Integration tests**, when the repo has none yet, go in a top-level `integration/` directory, or where the language's tooling expects them (Rust's `tests/`). They run separately from unit tests.

---

Test doubles, asserting what callers observe, and independent expected values adapted from `tdd` in [mattpocock/skills](https://github.com/mattpocock/skills), Copyright (c) 2026 Matt Pocock, MIT License.
