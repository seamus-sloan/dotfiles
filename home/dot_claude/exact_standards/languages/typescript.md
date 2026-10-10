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

## Doubles and determinism

- Pass doubles in through parameters or constructors. `vi.fn()` is for callbacks the code receives; `vi.mock` only for a boundary module that can't be injected.
- HTTP: a real local server on port `0` (`node:http`, or `msw/node`), never a stubbed `fetch`.
- Time: `vi.useFakeTimers()` and `vi.advanceTimersByTime()`, with `vi.useRealTimers()` in `afterEach`.
- Environment: `vi.stubEnv()`, with `vi.unstubAllEnvs()` in `afterEach`. Never assign to `process.env`.

## Example: unit

```ts
// src/price.test.ts
import { describe, expect, it } from 'vitest';
import { InvalidPriceError, parsePrice } from './price';

describe('parsePrice', () => {
  describe('validation', () => {
    it('returns cents from valid price', () => {
      expect(parsePrice('12.50')).toBe(1250);
    });

    it.each([
      ['negative amount', '-1.00'],
      ['more than two decimals', '1.005'],
    ])('rejects %s', (_condition, input) => {
      expect(() => parsePrice(input)).toThrow(InvalidPriceError);
    });
  });
});
```

## Example: integration

```ts
// integration/orders.test.ts
import { createServer, type IncomingHttpHeaders, type Server } from 'node:http';
import type { AddressInfo } from 'node:net';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { OrderClient } from '../src/orderClient';

async function startFakeApi(received: IncomingHttpHeaders[]): Promise<Server> {
  const server = createServer((req, res) => {
    if (req.method !== 'POST' || req.url !== '/v1/orders') {
      res.writeHead(404).end();
      return;
    }
    received.push(req.headers);
    res.writeHead(201, { 'content-type': 'application/json' }).end('{"id":"order-1","status":"pending"}');
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

describe('POST /v1/orders', () => {
  let received: IncomingHttpHeaders[];
  let server: Server;
  let client: OrderClient;

  beforeEach(async () => {
    received = [];
    server = await startFakeApi(received);
    client = new OrderClient({ baseUrl: urlOf(server), apiKey: 'test-key' });
  });

  afterEach(async () => {
    await stop(server);
  });

  describe('contract matching', () => {
    it('returns created order from valid request', async () => {
      const order = await client.create({ sku: 'BOOK-1', quantity: 2 });

      expect(order).toEqual({ id: 'order-1', status: 'pending' });
    });

    it('sends api key as bearer token', async () => {
      await client.create({ sku: 'BOOK-1', quantity: 2 });

      expect(received[0].authorization).toBe('Bearer test-key');
    });
  });
});
```
