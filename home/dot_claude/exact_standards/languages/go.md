# Go

How [testing.md](../testing.md) is spelled in Go.

## Runner

- The standard `testing` package, run with `-race`.
- No assertion libraries. Compare with `!=`, or with `cmp.Diff` from `github.com/google/go-cmp` for structs, slices, and maps that `!=` can't compare.

## Where tests live

- **Unit:** `foo_test.go` next to `foo.go`, in the external package `foo_test` so tests use only the public API. Use `package foo` only when the seam itself is unexported.
- **Integration:** the repo's integration location. With none, a top-level `integration/` package where every file starts with `//go:build integration`, so `go test ./...` skips it. Run it with `go test -race -tags integration ./integration/...`.

## Naming

- `Test<Subject>_<Behaviour>`, both in PascalCase: `TestPostTrack_ReturnsValidResponseFromValidRequest`.
- **Subject:** the code or API name without symbols: `POST /v1/track` → `PostTrack`, `TrackClient.Send` → `TrackClientSend`. The underscore appears once, between subject and behaviour.
- **Behaviour:** the sentence an `it` would hold, in PascalCase. Initialisms keep Go casing: `SendsAPIKeyAsBearerToken`.
- There's no group level. Keep a group's tests next to each other in the file.

## Tables

- Use a table when two or more cases share setup and assertion. The function name holds the shared outcome, and each row's `name` holds its condition in lowercase words: `"latitude above 90"`.
- Run every row with `t.Run(tt.name, …)`.

## Helpers and determinism

- Helpers call `t.Helper()` first.
- `t.Cleanup` for teardown, `t.TempDir()` for files, `t.Setenv` for environment, `t.Context()` for contexts.
- `t.Parallel()` in every test that leaves process-wide state alone. A test calling `t.Setenv` can't be parallel.
- HTTP: `httptest.NewServer`. Hand data from the handler to the test over a channel, not a shared variable.
- Failure messages name the call, then got and want: `ParseCoordinates(%q) = %+v, want %+v`. Use `t.Fatalf` only when the test can't continue.

## Example: unit

```go
// track/coordinates_test.go
package track_test

import (
	"errors"
	"testing"

	"example.com/app/track"
)

func TestParseCoordinates_ReturnsCoordinatesFromValidInput(t *testing.T) {
	t.Parallel()
	const input = "40.7,-74"

	got, err := track.ParseCoordinates(input)
	if err != nil {
		t.Fatalf("ParseCoordinates(%q) error = %v", input, err)
	}
	if want := (track.Coordinates{Latitude: 40.7, Longitude: -74}); got != want {
		t.Errorf("ParseCoordinates(%q) = %+v, want %+v", input, got, want)
	}
}

func TestParseCoordinates_RejectsInvalidInput(t *testing.T) {
	t.Parallel()
	tests := []struct {
		name  string
		input string
	}{
		{name: "latitude above 90", input: "91,0"},
		{name: "missing longitude", input: "40.7"},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Parallel()

			_, err := track.ParseCoordinates(tt.input)
			if !errors.Is(err, track.ErrInvalidCoordinates) {
				t.Errorf("ParseCoordinates(%q) error = %v, want %v", tt.input, err, track.ErrInvalidCoordinates)
			}
		})
	}
}
```

## Example: integration

```go
// integration/track_test.go
//go:build integration

package integration_test

import (
	"io"
	"net/http"
	"net/http/httptest"
	"testing"

	"example.com/app/track"
)

func TestPostTrack_ReturnsValidResponseFromValidRequest(t *testing.T) {
	t.Parallel()
	client := track.NewClient(startFakeAPI(t, nil).URL, "test-key")

	got, err := client.Track(t.Context(), track.Coordinates{Latitude: 40.7, Longitude: -74})
	if err != nil {
		t.Fatalf("Track() error = %v", err)
	}
	if want := (track.Response{Status: "ok"}); got != want {
		t.Errorf("Track() = %+v, want %+v", got, want)
	}
}

func TestPostTrack_SendsAPIKeyAsBearerToken(t *testing.T) {
	t.Parallel()
	received := make(chan http.Header, 1)
	client := track.NewClient(startFakeAPI(t, received).URL, "test-key")

	if _, err := client.Track(t.Context(), track.Coordinates{Latitude: 40.7, Longitude: -74}); err != nil {
		t.Fatalf("Track() error = %v", err)
	}
	if got, want := (<-received).Get("Authorization"), "Bearer test-key"; got != want {
		t.Errorf("Authorization header = %q, want %q", got, want)
	}
}

func startFakeAPI(t *testing.T, received chan<- http.Header) *httptest.Server {
	t.Helper()
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if received != nil {
			received <- r.Header.Clone()
		}
		w.Header().Set("Content-Type", "application/json")
		_, _ = io.WriteString(w, `{"status":"ok"}`)
	}))
	t.Cleanup(server.Close)
	return server
}
```
