# Specs

Part of the [Playwright standard](../playwright.md).

- `test.describe('<subject>')`, then an optional `test.describe('<group>')`, then `test('<behaviour>')`. The subject is the page or feature in lowercase (`orders page`), or the endpoint for API tests (`POST /api/orders`).
- Test titles are imperative: `test('cancel a pending order')`. Lowercase, no punctuation, no "should".
- A test with more than one phase splits into `test.step`s, each named as an imperative: `'submit the order'`, `'check the order appears in the list'`.
- Hooks are titled: `test.beforeEach('setup', …)` and `test.afterEach('teardown', …)`.
- Tags go in the options, never the title: `test('…', { tag: '@smoke' }, …)`.
- Seed data through request objects inside the test, before opening the page that shows it. Builders in `data/` make unique values, so parallel runs never collide.
- `toBeVisible` for presence. `toBeInViewport` only when scrolling is the behaviour under test.
- Run independent waits together with `Promise.all`. Use `expect.poll` with a `message` for values that settle over time.
- No `waitForTimeout` and no retry loops. A wait that truly needs time disables `playwright/no-wait-for-timeout` on that one line, with the reason as the comment.
- Stub routes only to force a state the backend can't easily produce, like an empty list or a server error, through a page-object method that calls `page.route`.

```ts
// tests/orders/orders.spec.ts
import { buildOrder, type Order } from '../../data/orders';
import { expect, test } from '../../fixtures/ordersFixtures';

test.describe('orders page', () => {
  test.describe('new orders', () => {
    test('place an order from the form', { tag: '@smoke' }, async ({ ordersPage, createdOrderIds }) => {
      const order = buildOrder({ quantity: 2 });

      await test.step('open the orders page', async () => {
        await ordersPage.goto();
      });

      await test.step('fill in the order form', async () => {
        await ordersPage.fillOrderForm(order);
      });

      const created = await test.step('submit the order', async () => {
        const placed = await ordersPage.placeOrder();
        createdOrderIds.push(placed.id);
        return placed;
      });

      await test.step('check the order appears in the list', async () => {
        await expect(ordersPage.confirmationMessage).toHaveText('Order placed');
        await ordersPage.assertOrderCard(created);
      });
    });
  });

  test.describe('cancellation', () => {
    test('cancel a pending order', async ({ ordersPage, ordersRequests, createdOrderIds }) => {
      const order = await test.step('create a pending order through the api', async () => {
        const response = await ordersRequests.postOrder(buildOrder());
        await expect(response).toBeOK();
        const pending: Order = await response.json();
        createdOrderIds.push(pending.id);
        return pending;
      });

      await test.step('open the orders page', async () => {
        await ordersPage.goto();
      });

      await test.step('cancel the order', async () => {
        await ordersPage.orderCard(order.id).cancel();
      });

      await test.step('check the order shows as cancelled', async () => {
        await expect(ordersPage.orderCard(order.id).statusText).toHaveText('cancelled');
      });
    });
  });

  test.describe('header', () => {
    test('sign out from the header', async ({ ordersPage, loginPage }) => {
      await test.step('open the orders page', async () => {
        await ordersPage.goto();
      });

      await test.step('sign out', async () => {
        await ordersPage.header.signOut();
      });

      await test.step('check the login page shows', async () => {
        await loginPage.assertDisplayed();
      });
    });
  });
});
```

```ts
// tests/api/orders.api.ts
import { buildOrder, type Order } from '../../data/orders';
import { expect, test } from '../../fixtures/ordersFixtures';

test.describe('POST /api/orders', () => {
  test('create a pending order from a valid body', async ({ ordersRequests, createdOrderIds }) => {
    const response = await ordersRequests.postOrder(buildOrder());

    await expect(response).toBeOK();
    const order: Order = await response.json();
    createdOrderIds.push(order.id);
    expect(order.status).toBe('pending');
  });

  test('reject an order without a sku', async ({ ordersRequests }) => {
    const response = await ordersRequests.postOrder(buildOrder({ sku: '' }));

    expect(response.status()).toBe(400);
  });
});
```
