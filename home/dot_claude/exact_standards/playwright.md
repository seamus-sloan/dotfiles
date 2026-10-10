# Playwright

How [testing.md](testing.md) is spelled for Playwright end-to-end tests, built on page objects. Where it differs from [languages/typescript.md](languages/typescript.md), this file wins. A repo with its own structure keeps it.

## Layout

With no existing suite, start one in `e2e/` at the repo root:

```
e2e/
├── playwright.config.ts
├── auth/          storage-state paths shared by config and setup
├── pages/         BasePage.ts, <Name>Page.ts
├── components/    BaseComponent.ts, <Name>Component.ts
├── apiRequests/   BaseRequests.ts, <Area>Requests.ts
├── fixtures/      <area>Fixtures.ts
├── data/          types and builders for test data
└── tests/
    ├── setup/     <role>.setup.ts
    ├── <feature>/ <name>.spec.ts
    └── api/       <name>.api.ts
```

- A file holding a class is PascalCase, named exactly for its class: `OrdersPage.ts`, `OrderCardComponent.ts`, `OrdersRequests.ts`.
- Every other file is camelCase: specs (`orders.spec.ts`), fixtures (`ordersFixtures.ts`), data, and config.
- One class per file, default-exported.
- `.spec.ts` tests run in a browser. `.api.ts` tests run in their own project, with no browser.

## Page objects

- Every page extends `BasePage` and declares `static get path()`. `goto()` navigates there and waits for the page's `readyLocator`; `assertDisplayed()` checks the URL and that `readyLocator` is visible.
- Locators are `readonly` fields assigned in the constructor. A locator that needs an argument is a method named for what it returns: `orderCard(id)`.
- Locator names are camelCase and end in the element's type: `placeOrderButton`, `skuField`, `statusText`, `confirmationMessage`, `ordersTab`, `helpLink`.
- Reach for `getByRole` first, then `getByLabel`, `getByPlaceholder`, or `getByText`, then `getByTestId`. CSS only when nothing else reaches the element.
- Members go in this order, separated by blank lines rather than comments: static `path`, components, locators, constructor, `readyLocator`, dynamic locators, actions, `assert*` methods.
- Actions are verbs (`fillOrderForm`, `placeOrder`, `signIn`) and never assert.
- An action that triggers a request starts `waitForResponse` before it acts, then returns what the test needs: `placeOrder()` returns the created `Order`.
- `assert*` methods hold grouped or data-driven checks that specs would otherwise repeat. A single check stays in the spec.
- Pages never call APIs or build test data. That belongs to request objects and `data/`.

```ts
// pages/BasePage.ts
import { expect, type Locator, type Page } from '@playwright/test';

export default abstract class BasePage {
  static get path(): string {
    throw new Error(`${this.name} must override static get path()`);
  }

  constructor(readonly page: Page) {}

  protected abstract get readyLocator(): Locator;

  private get path(): string {
    return (this.constructor as typeof BasePage).path;
  }

  async goto(): Promise<void> {
    await this.page.goto(this.path);
    await this.readyLocator.waitFor();
  }

  async assertDisplayed(): Promise<void> {
    await expect(this.page).toHaveURL(this.path);
    await expect(this.readyLocator).toBeVisible();
  }
}
```

```ts
// pages/OrdersPage.ts
import { expect, type Locator, type Page } from '@playwright/test';
import HeaderComponent from '../components/HeaderComponent';
import OrderCardComponent from '../components/OrderCardComponent';
import type { NewOrder, Order } from '../data/orders';
import BasePage from './BasePage';

export default class OrdersPage extends BasePage {
  static override get path(): string {
    return '/orders';
  }

  readonly header: HeaderComponent;

  readonly skuField: Locator;
  readonly quantityField: Locator;
  readonly placeOrderButton: Locator;
  readonly confirmationMessage: Locator;

  constructor(page: Page) {
    super(page);
    this.header = new HeaderComponent(page);
    this.skuField = page.getByLabel('SKU');
    this.quantityField = page.getByLabel('Quantity');
    this.placeOrderButton = page.getByRole('button', { name: 'Place order' });
    this.confirmationMessage = page.getByRole('status');
  }

  protected get readyLocator(): Locator {
    return this.placeOrderButton;
  }

  orderCard(id: string): OrderCardComponent {
    return new OrderCardComponent(this.page, this.page.getByTestId(`orderCard-${id}`));
  }

  async fillOrderForm(order: NewOrder): Promise<void> {
    await this.skuField.fill(order.sku);
    await this.quantityField.fill(String(order.quantity));
  }

  async placeOrder(): Promise<Order> {
    const response = this.page.waitForResponse(
      (r) => r.url().endsWith('/api/orders') && r.request().method() === 'POST',
    );
    await this.placeOrderButton.click();
    return (await response).json();
  }

  async assertOrderCard(order: Order): Promise<void> {
    const card = this.orderCard(order.id);
    await expect(card.root).toContainText(`${order.sku} × ${order.quantity}`);
    await expect(card.statusText).toHaveText(order.status);
  }
}
```

## Components

- Every component extends `BaseComponent` and joins a page as a `readonly` field.
- A component that appears once locates from `page`.
- A component that repeats takes a `root` locator and builds every locator from it. The page hands out one per item: `orderCard(id)`.

```ts
// components/HeaderComponent.ts
import type { Locator, Page } from '@playwright/test';
import BaseComponent from './BaseComponent';

export default class HeaderComponent extends BaseComponent {
  readonly signOutButton: Locator;

  constructor(page: Page) {
    super(page);
    this.signOutButton = page.getByRole('button', { name: 'Sign out' });
  }

  async signOut(): Promise<void> {
    await this.signOutButton.click();
  }
}
```

```ts
// components/OrderCardComponent.ts
import type { Locator, Page } from '@playwright/test';
import BaseComponent from './BaseComponent';

export default class OrderCardComponent extends BaseComponent {
  readonly statusText: Locator;
  readonly cancelButton: Locator;

  constructor(
    page: Page,
    readonly root: Locator,
  ) {
    super(page);
    this.statusText = root.getByTestId('orderStatus');
    this.cancelButton = root.getByRole('button', { name: 'Cancel' });
  }

  async cancel(): Promise<void> {
    await this.cancelButton.click();
  }
}
```

## Request objects

- One class per API area, extending `BaseRequests`, which wraps Playwright's `APIRequestContext`.
- Methods are named `<verb><Resource>`: `getOrders`, `postOrder`, `deleteOrder`.
- They return the raw `APIResponse`. The caller asserts the status with `toBeOK()` and reads the body.
- They're built from the `request` fixture, which carries the project's storage state, so they work in API-only projects too.
- Specs use them to seed and clean up data. API tests use them as the subject.

```ts
// apiRequests/BaseRequests.ts
import type { APIRequestContext, APIResponse } from '@playwright/test';

export default abstract class BaseRequests {
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
import BaseRequests from './BaseRequests';

export default class OrdersRequests extends BaseRequests {
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

## Fixtures

- One fixtures file per area extends `test` with its pages and request objects and re-exports `expect`. An area builds on the fixtures it needs: `ordersFixtures` extends `authFixtures`.
- Specs and setup files import `test` and `expect` from a fixtures file, never from `@playwright/test`. They never construct page objects or touch `page` directly.
- Fixtures construct page objects but never navigate. The test calls `goto()`.
- A fixture that tracks created data deletes it after `use`, so cleanup runs even when a test fails.

```ts
// fixtures/authFixtures.ts
import { test as base, expect } from '@playwright/test';
import LoginPage from '../pages/LoginPage';

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
import OrdersRequests from '../apiRequests/OrdersRequests';
import OrdersPage from '../pages/OrdersPage';

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
    for (const id of ids) {
      await expect(await ordersRequests.deleteOrder(id)).toBeOK();
    }
  },
});

export { expect };
```

## Auth and config

- One setup project per role signs in through the login page object and saves the storage state through the `context` fixture.
- Every other project depends on it and loads that state. The path lives in one module, shared by the config and the setup.
- `forbidOnly` and a single retry on CI only. Traces are kept on failure.

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import { CUSTOMER_STORAGE_STATE } from './auth/storageStates';

export default defineConfig({
  testDir: './tests',
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  use: { baseURL: process.env.BASE_URL ?? 'http://localhost:3000', trace: 'retain-on-failure' },
  projects: [
    { name: 'setup', testMatch: /.*\.setup\.ts/ },
    {
      name: 'chromium',
      testMatch: /.*\.spec\.ts/,
      dependencies: ['setup'],
      use: { ...devices['Desktop Chrome'], storageState: CUSTOMER_STORAGE_STATE },
    },
    { name: 'api', testMatch: /.*\.api\.ts/, dependencies: ['setup'], use: { storageState: CUSTOMER_STORAGE_STATE } },
  ],
});
```

```ts
// tests/setup/customer.setup.ts
import { CUSTOMER_STORAGE_STATE } from '../../auth/storageStates';
import { test as setup } from '../../fixtures/ordersFixtures';

setup('sign in as a customer', async ({ loginPage, ordersPage, context }) => {
  await loginPage.goto();
  await loginPage.signIn('reader@example.com', 'test-password');
  await ordersPage.assertDisplayed();
  await context.storageState({ path: CUSTOMER_STORAGE_STATE });
});
```

## Specs

- `test.describe('<subject>')`, then an optional `test.describe('<group>')`, then `test('<behaviour>')`. The subject is the page or feature in lowercase (`orders page`), or the endpoint for API tests (`POST /api/orders`).
- Test titles are imperative: `test('cancel a pending order')`. Lowercase, no punctuation, no "should".
- A test with more than one phase splits into `test.step`s, each named as an imperative: `'submit the order'`, `'check the order appears in the list'`.
- Hooks are titled: `test.beforeEach('setup', …)` and `test.afterEach('teardown', …)`.
- Tags go in the options, never the title: `test('…', { tag: '@smoke' }, …)`.
- Seed data through request objects inside the test, before opening the page that shows it. Builders in `data/` make unique values, so parallel runs never collide.
- `toBeVisible` for presence. `toBeInViewport` only when scrolling is the behaviour under test.
- Run independent waits together with `Promise.all`. Use `expect.poll` with a `message` for values that settle over time.
- No `waitForTimeout` and no retry loops. A wait that truly needs time uses a named constant and a one-line comment saying why.
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
