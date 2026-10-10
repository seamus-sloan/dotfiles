# Fixtures

Part of the [Playwright standard](../playwright.md).

- One fixtures file per area extends `test` with its pages and request objects and re-exports `expect`. An area builds on the fixtures it needs: `ordersFixtures` extends `authFixtures`.
- Specs and setup files import `test` and `expect` from a fixtures file, never from `@playwright/test`. They never construct page objects or touch `page` directly.
- Fixtures construct page objects but never navigate. The test calls `goto()`.
- A fixture that tracks created data deletes it after `use`, so cleanup runs even when a test fails.

```ts
// fixtures/authFixtures.ts
import { test as base, expect } from '@playwright/test';
import { LoginPage } from '../pages/LoginPage';

type AuthFixtures = {
  loginPage: LoginPage;
};

export const test = base.extend<AuthFixtures>({
  loginPage: async ({ page }, use) => {
    await use(new LoginPage(page));
  },
});

export { expect };
```

```ts
// fixtures/ordersFixtures.ts
import { test as base, expect } from './authFixtures';
import { OrdersRequests } from '../apiRequests/OrdersRequests';
import { OrdersPage } from '../pages/OrdersPage';

type OrdersFixtures = {
  ordersPage: OrdersPage;
  ordersRequests: OrdersRequests;
  createdOrderIds: string[];
};

export const test = base.extend<OrdersFixtures>({
  ordersPage: async ({ page }, use) => {
    await use(new OrdersPage(page));
  },
  ordersRequests: async ({ request }, use) => {
    await use(new OrdersRequests(request));
  },
  createdOrderIds: async ({ ordersRequests }, use) => {
    const ids: string[] = [];
    await use(ids);
    const responses = await Promise.all(ids.map((id) => ordersRequests.deleteOrder(id)));
    for (const response of responses) {
      await expect(response).toBeOK();
    }
  },
});

export { expect };
```
