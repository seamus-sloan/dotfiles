# TypeScript

How [code.md](../code.md) and [testing.md](../testing.md) are spelled in TypeScript and JavaScript. Playwright end-to-end tests follow [playwright.md](../playwright.md) instead.

## Code

- **`unknown`, never `any`,** for data from outside: `JSON.parse`, response bodies, `postMessage`, environment variables, files, database rows.
- **Validate with the repo's schema library** and infer the type from it: `type User = z.infer<typeof UserSchema>`. Never keep a schema, an interface, and a hand-written guard for the same shape, and don't add a schema library for one guard.
- **No `as` and no non-null `!`.** Narrow instead, preferring a discriminant `switch`, then `in`, then `typeof` or `instanceof`, then a type guard. The exceptions are `as const` and the cast that brands a value its parse function just validated.
- **`satisfies`, not `as`,** to check a literal against a type without widening it.
- **A type guard checks every claim its type makes**, and is named `isX` or `hasX`.
- **Exhaust unions** with `const _exhaustive: never = value` in the `default` arm.
- **Brands are `string & { readonly __brand: 'UserId' }`.**
- **Derive before declaring:** `Pick`, `Omit`, `Parameters`, `ReturnType`, `Awaited`, `typeof`.
- **Pass one options object** when a caller could swap two arguments of the same type. Keep positional arguments in hot loops.
- **No `console.log` in shipped code.** Use the project's logger.

## Example: code

```ts
// src/payments.ts
import { z } from 'zod';

export type OrderId = string & { readonly __brand: 'OrderId' };

const orderId = z
  .string()
  .min(1)
  .transform((id) => id as OrderId);

const PaymentEventSchema = z.discriminatedUnion('kind', [
  z.object({ kind: z.literal('paid'), orderId, cents: z.number().int().positive() }),
  z.object({ kind: z.literal('refunded'), orderId, reason: z.string() }),
]);

export type PaymentEvent = z.infer<typeof PaymentEventSchema>;

export function parsePaymentEvent(body: unknown): PaymentEvent {
  return PaymentEventSchema.parse(body);
}

export function summarize(event: PaymentEvent): string {
  switch (event.kind) {
    case 'paid':
      return `order ${event.orderId} paid ${event.cents} cents`;
    case 'refunded':
      return `order ${event.orderId} refunded: ${event.reason}`;
    default: {
      const _exhaustive: never = event;
      return _exhaustive;
    }
  }
}
```

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
  const address = server.address();
  if (address === null || typeof address === 'string') throw new Error('server is not listening on a TCP port');
  return `http://127.0.0.1:${address.port}`;
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

---

Code rules adapted from `typescript-best-practices` in [michael-denyer/pstack-claude](https://github.com/michael-denyer/pstack-claude), Copyright (c) 2026 Lauren Tan and Michael Denyer, MIT License.
