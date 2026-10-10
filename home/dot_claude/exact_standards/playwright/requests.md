# Request objects

Part of the [Playwright standard](../playwright.md).

- One class per API area, extending `BaseRequests`, which wraps Playwright's `APIRequestContext`.
- Methods are named `<verb><Resource>`: `getOrders`, `postOrder`, `deleteOrder`.
- They return the raw `APIResponse`. The caller asserts the status with `toBeOK()` and reads the body.
- They're built from the `request` fixture, which carries the signed-in storage state without needing a browser page.
- Specs use them for every API call a test needs: seeding, cleanup, reading back state. The API itself is never what a spec tests.

```ts
// apiRequests/BaseRequests.ts
import type { APIRequestContext, APIResponse } from '@playwright/test';

/** Thin wrapper over Playwright's APIRequestContext that returns raw responses. */
export abstract class BaseRequests {
  constructor(protected readonly request: APIRequestContext) {}

  protected get(url: string): Promise<APIResponse> {
    return this.request.get(url);
  }

  protected post(url: string, data?: unknown): Promise<APIResponse> {
    return this.request.post(url, { data });
  }

  protected delete(url: string): Promise<APIResponse> {
    return this.request.delete(url);
  }
}
```

```ts
// apiRequests/OrdersRequests.ts
import type { APIResponse } from '@playwright/test';
import type { NewOrder } from '../data/orders';
import { BaseRequests } from './BaseRequests';

export class OrdersRequests extends BaseRequests {
  getOrders(): Promise<APIResponse> {
    return this.get('/api/orders');
  }

  postOrder(order: NewOrder): Promise<APIResponse> {
    return this.post('/api/orders', order);
  }

  deleteOrder(id: string): Promise<APIResponse> {
    return this.delete(`/api/orders/${id}`);
  }
}
```
