# TypeScript

How [testing.md](../testing.md) is spelled in TypeScript and JavaScript.

## Runner

- The repo's runner. In a new project, Vitest.
- `describe` and `it` only, never `test`: `it` starts the behaviour sentence.

## Where tests live

- **Unit:** `foo.test.ts` next to `foo.ts`.
- **Integration:** the repo's integration directory. With none, `integration/<subject>.test.ts` at the root, run by its own script (`test:integration`) so the unit run stays fast.

## Naming and structure

- `describe('<subject>')`, then an optional `describe('<group>')`, then `it('<behaviour>')`. Never more than two `describe` levels.
- `beforeEach` and `afterEach` sit in the subject block, and `afterEach` undoes everything `beforeEach` did.
- `beforeAll` only for setup too slow to repeat per test.
- Parameterise with `it.each`, completing the sentence with the case: `it.each(cases)('rejects %s', …)`.
- Helper functions go below the outer `describe`.

## Doubles and determinism

- Pass doubles in through parameters or constructors. `vi.fn()` is for callbacks the code receives; `vi.mock` only for a boundary module that can't be injected.
- HTTP: a real local server on port `0` (`node:http`, or `msw/node`), never a stubbed `fetch`.
- Time: `vi.useFakeTimers()` and `vi.advanceTimersByTime()`, with `vi.useRealTimers()` in `afterEach`.
- Environment: `vi.stubEnv()`, with `vi.unstubAllEnvs()` in `afterEach`. Never assign to `process.env`.

## Example: unit

```ts
// src/coordinates.test.ts
import { describe, expect, it } from 'vitest';
import { InvalidCoordinatesError, parseCoordinates } from './coordinates';

describe('parseCoordinates', () => {
  describe('validation', () => {
    it('returns coordinates from valid input', () => {
      expect(parseCoordinates('40.7,-74')).toEqual({ latitude: 40.7, longitude: -74 });
    });

    it.each([
      ['latitude above 90', '91,0'],
      ['missing longitude', '40.7'],
    ])('rejects %s', (_condition, input) => {
      expect(() => parseCoordinates(input)).toThrow(InvalidCoordinatesError);
    });
  });
});
```

## Example: integration

```ts
// integration/track.test.ts
import { createServer, type IncomingHttpHeaders, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { TrackClient } from '../src/trackClient';

describe('POST /v1/track', () => {
  let received: IncomingHttpHeaders[];
  let server: Server;
  let client: TrackClient;

  beforeEach(async () => {
    received = [];
    server = await startFakeApi(received);
    client = new TrackClient({ baseUrl: urlOf(server), apiKey: 'test-key' });
  });

  afterEach(async () => {
    await stop(server);
  });

  describe('contract matching', () => {
    it('returns valid response from valid request', async () => {
      const response = await client.track({ latitude: 40.7, longitude: -74 });

      expect(response).toEqual({ status: 'ok' });
    });

    it('sends api key as bearer token', async () => {
      await client.track({ latitude: 40.7, longitude: -74 });

      expect(received[0].authorization).toBe('Bearer test-key');
    });
  });
});

async function startFakeApi(received: IncomingHttpHeaders[]): Promise<Server> {
  const server = createServer((req, res) => {
    received.push(req.headers);
    res.writeHead(200, { 'content-type': 'application/json' }).end('{"status":"ok"}');
  });
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  return server;
}

function urlOf(server: Server): string {
  return `http://127.0.0.1:${(server.address() as AddressInfo).port}`;
}

function stop(server: Server): Promise<void> {
  return new Promise((resolve, reject) => server.close((err) => (err ? reject(err) : resolve())));
}
```
