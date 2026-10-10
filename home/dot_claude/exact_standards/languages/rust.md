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

- The function name is the behaviour, in snake_case, with no `test_` prefix: `fn returns_created_order_from_valid_request()`.
- Subject and group are nested modules, each opening with `use super::*;`, so the test path reads as the sentence: `post_orders::contract_matching::returns_created_order_from_valid_request`.
- **Subject:** the code or API name in snake_case: `POST /v1/orders` → `post_orders`, `OrderClient::create` → `order_client_create`.
- In `tests/`, the file is the subject (`tests/post_orders.rs`) and groups are modules inside it.
- Parameterise with `rstest`'s `#[case::negative_amount("-1.00")]` where the crate has it. Otherwise write one function per case.

## Doubles and determinism

- Code takes a trait at each boundary, and tests pass a hand-written implementation: `FakeStore`, `StubClock`.
- Files: `tempfile::TempDir`, which deletes itself on drop.
- HTTP: a local server such as `wiremock::MockServer`, used as a fake that answers and records requests.
- A test with fallible setup returns `Result<(), Box<dyn std::error::Error>>` and uses `?`.

## Example: unit

```rust
// src/price/tests.rs, declared by `#[cfg(test)] mod tests;` in src/price.rs
use super::*;

mod parse_price {
    use super::*;

    mod validation {
        use super::*;

        #[test]
        fn returns_cents_from_valid_price() {
            assert_eq!(parse_price("12.50"), Ok(1250));
        }

        #[test]
        fn rejects_negative_amount() {
            assert_eq!(parse_price("-1.00"), Err(OrderError::InvalidPrice));
        }

        #[test]
        fn rejects_more_than_two_decimals() {
            assert_eq!(parse_price("1.005"), Err(OrderError::InvalidPrice));
        }
    }
}
```

## Example: integration

```rust
// tests/post_orders.rs
use orders::{NewOrder, Order, OrderClient};
use serde_json::json;
use wiremock::matchers::{method, path};
use wiremock::{Mock, MockServer, ResponseTemplate};

fn two_books() -> NewOrder {
    NewOrder {
        sku: "BOOK-1".into(),
        quantity: 2,
    }
}

async fn start_fake_api() -> MockServer {
    let server = MockServer::start().await;
    Mock::given(method("POST"))
        .and(path("/v1/orders"))
        .respond_with(
            ResponseTemplate::new(201)
                .set_body_json(json!({ "id": "order-1", "status": "pending" })),
        )
        .mount(&server)
        .await;
    server
}

mod contract_matching {
    use super::*;

    #[tokio::test]
    async fn returns_created_order_from_valid_request() {
        let server = start_fake_api().await;
        let client = OrderClient::new(&server.uri(), "test-key");

        let order = client.create(two_books()).await;

        let expected = Order {
            id: "order-1".into(),
            status: "pending".into(),
        };
        assert_eq!(order.unwrap(), expected);
    }

    #[tokio::test]
    async fn sends_api_key_as_bearer_token() {
        let server = start_fake_api().await;
        let client = OrderClient::new(&server.uri(), "test-key");

        client.create(two_books()).await.unwrap();

        let received = server.received_requests().await.unwrap();
        assert_eq!(received[0].headers["authorization"], "Bearer test-key");
    }
}
```
