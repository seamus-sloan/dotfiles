# Go

How [testing.md](../testing.md) is spelled in Go.

## Runner

- The standard `testing` package, run with `-race`.
- No assertion libraries. Compare with `!=`, or with `cmp.Diff` from `github.com/google/go-cmp` for structs, slices, and maps that `!=` can't compare.

## Where tests live

- **Unit:** `foo_test.go` next to `foo.go`, in the external package `foo_test` so tests use only the public API. Use `package foo` only when the seam itself is unexported.
- **Integration:** the repo's integration location. With none, a top-level `integration/` package where every file starts with `//go:build integration`, so `go test ./...` skips it. Run it with `go test -race -tags integration ./integration/...`.

## Naming

- `Test<Subject>_<Behaviour>`, both in PascalCase: `TestPostOrders_ReturnsCreatedOrderFromValidRequest`.
- **Subject:** the code or API name without symbols: `POST /v1/orders` → `PostOrders`, `OrderClient.Create` → `OrderClientCreate`. The underscore appears once, between subject and behaviour.
- **Behaviour:** the sentence an `it` would hold, in PascalCase. Initialisms keep Go casing: `SendsAPIKeyAsBearerToken`.
- There's no group level. Keep a group's tests next to each other in the file.

## Tables

- Use a table when two or more cases share setup and assertion. The function name holds the shared outcome, and each row's `name` holds its condition in lowercase words: `"negative amount"`.
- Run every row with `t.Run(tt.name, …)`.

## Helpers and determinism

- Helpers call `t.Helper()` first.
- `t.Cleanup` for teardown, `t.TempDir()` for files, `t.Setenv` for environment, `t.Context()` for contexts.
- `t.Parallel()` in every test that leaves process-wide state alone. A test calling `t.Setenv` can't be parallel.
- HTTP: `httptest.NewServer`. Hand data from the handler to the test over a channel, not a shared variable.
- Failure messages name the call, then got and want: `ParsePrice(%q) = %d, want %d`. Use `t.Fatalf` only when the test can't continue.

## Example: unit

```go
// orders/price_test.go
package orders_test

import (
	"errors"
	"testing"

	"example.com/app/orders"
)

func TestParsePrice_ReturnsCentsFromValidPrice(t *testing.T) {
	t.Parallel()
	const input = "12.50"

	got, err := orders.ParsePrice(input)
	if err != nil {
		t.Fatalf("ParsePrice(%q) error = %v", input, err)
	}
	if want := 1250; got != want {
		t.Errorf("ParsePrice(%q) = %d, want %d", input, got, want)
	}
}

func TestParsePrice_RejectsInvalidPrice(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name  string
		input string
	}{
		{name: "negative amount", input: "-1.00"},
		{name: "more than two decimals", input: "1.005"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			_, err := orders.ParsePrice(tt.input)
			if !errors.Is(err, orders.ErrInvalidPrice) {
				t.Errorf("ParsePrice(%q) error = %v, want %v", tt.input, err, orders.ErrInvalidPrice)
			}
		})
	}
}
```

## Example: integration

```go
// integration/orders_test.go
//go:build integration

package integration_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/app/orders"
)

var twoBooks = orders.NewOrder{SKU: "BOOK-1", Quantity: 2}

func startFakeAPI(t *testing.T, received chan<- http.Header) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if received != nil {
			received <- r.Header.Clone()
		}
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusCreated)
		_, _ = io.WriteString(w, `{"id":"order-1","status":"pending"}`)
	}))
	t.Cleanup(server.Close)
	return server
}

func TestPostOrders_ReturnsCreatedOrderFromValidRequest(t *testing.T) {
	t.Parallel()
	client := orders.NewClient(startFakeAPI(t, nil).URL, "test-key")

	got, err := client.Create(t.Context(), twoBooks)
	if err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if want := (orders.Order{ID: "order-1", Status: "pending"}); got != want {
		t.Errorf("Create() = %+v, want %+v", got, want)
	}
}

func TestPostOrders_SendsAPIKeyAsBearerToken(t *testing.T) {
	t.Parallel()
	received := make(chan http.Header, 1)
	client := orders.NewClient(startFakeAPI(t, received).URL, "test-key")

	if _, err := client.Create(t.Context(), twoBooks); err != nil {
		t.Fatalf("Create() error = %v", err)
	}
	if got, want := (<-received).Get("Authorization"), "Bearer test-key"; got != want {
		t.Errorf("Authorization header = %q, want %q", got, want)
	}
}
```
