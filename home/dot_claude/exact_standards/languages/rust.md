# Rust

How [testing.md](../testing.md) is spelled in Rust.

## Runner

- `cargo test`, or `cargo nextest run` where the repo uses it. `#[tokio::test]` for async tests in tokio crates.
- `assert_eq!`, and `assert!(matches!(…))` for variants that aren't `PartialEq`. Add test crates (`rstest`, `mockall`) only where the repo already uses them.

## Where tests live

Follow the crate's layout. Where it has none, keep tests out of the source file, because test modules outgrow the code:

- **Unit:** declare the module at the bottom of `foo.rs` and write the tests in `foo/tests.rs`. They still reach private items through `use super::*`.

  ```rust
  #[cfg(test)]
  mod tests;
  ```

- When `foo/tests.rs` grows, turn it into `foo/tests/mod.rs` with one file per sub-topic, mirroring how `foo` itself is split. Fixtures shared across modules go in a `#[cfg(test)]` `test_support` module.
- **Integration:** the crate's `tests/` directory, where Cargo finds them. Each file is its own crate and sees only the public API. Shared helpers go in `tests/common/mod.rs`. Tests spanning several crates get their own workspace member, `integration/`.

## Naming

- The function name is the behaviour, in snake_case, with no `test_` prefix: `fn returns_valid_response_from_valid_request()`.
- Subject and group are nested modules, each opening with `use super::*;`, so the test path reads as the sentence: `post_track::contract_matching::returns_valid_response_from_valid_request`.
- **Subject:** the code or API name in snake_case: `POST /v1/track` → `post_track`, `TrackClient::send` → `track_client_send`.
- In `tests/`, the file is the subject (`tests/post_track.rs`) and groups are modules inside it.
- Parameterise with `rstest`'s `#[case::latitude_above_90("91,0")]` where the crate has it. Otherwise write one function per case.

## Doubles and determinism

- Code takes a trait at each boundary, and tests pass a hand-written implementation: `FakeStore`, `StubClock`.
- Files: `tempfile::TempDir`, which deletes itself on drop.
- HTTP: a local server such as `wiremock::MockServer`, used as a fake that answers and records requests.
- A test with fallible setup returns `Result<(), Box<dyn std::error::Error>>` and uses `?`.

## Example: unit

```rust
// src/coordinates/tests.rs, declared by `#[cfg(test)] mod tests;` in src/coordinates.rs
use super::*;

mod parse_coordinates {
    use super::*;

    mod validation {
        use super::*;

        #[test]
        fn returns_coordinates_from_valid_input() {
            assert_eq!(
                parse_coordinates("40.7,-74"),
                Ok(Coordinates {
                    latitude: 40.7,
                    longitude: -74.0
                })
            );
        }

        #[test]
        fn rejects_latitude_above_90() {
            assert_eq!(
                parse_coordinates("91,0"),
                Err(TrackError::InvalidCoordinates)
            );
        }

        #[test]
        fn rejects_missing_longitude() {
            assert_eq!(
                parse_coordinates("40.7"),
                Err(TrackError::InvalidCoordinates)
            );
        }
    }
}
```

## Example: integration

```rust
// tests/post_track.rs
use serde_json::json;
use track::{Coordinates, TrackClient, TrackResponse};
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

const NEW_YORK: Coordinates = Coordinates {
    latitude: 40.7,
    longitude: -74.0,
};

mod contract_matching {
    use super::*;

    #[tokio::test]
    async fn returns_valid_response_from_valid_request() {
        let server = start_fake_api().await;
        let client = TrackClient::new(&server.uri(), "test-key");

        let response = client.track(NEW_YORK).await;

        let expected = TrackResponse {
            status: "ok".into(),
        };
        assert_eq!(response.unwrap(), expected);
    }

    #[tokio::test]
    async fn sends_api_key_as_bearer_token() {
        let server = start_fake_api().await;
        let client = TrackClient::new(&server.uri(), "test-key");

        client.track(NEW_YORK).await.unwrap();

        let received = server.received_requests().await.unwrap();
        assert_eq!(received[0].headers["authorization"], "Bearer test-key");
    }
}

async fn start_fake_api() -> MockServer {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/v1/track"))
        .respond_with(ResponseTemplate::new(200).set_body_json(json!({ "status": "ok" })))
        .mount(&server)
        .await;
    server
}
```
