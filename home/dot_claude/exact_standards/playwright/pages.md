# Page and component objects

Part of the [Playwright standard](../playwright.md).

## Page objects

- Every page extends `BasePage` and sets `protected readonly path`. `goto()` navigates there and waits for the page's `readyLocator`; `assertDisplayed()` checks the URL and that `readyLocator` is visible.
- Locators are `readonly` fields assigned in the constructor. A locator that needs an argument is a method named for what it returns: `orderCard(id)`.
- Locator names are camelCase and end in the element's type: `placeOrderButton`, `skuField`, `statusText`, `confirmationMessage`, `ordersTab`, `helpLink`.
- Reach for `getByRole` first, then `getByLabel`, `getByPlaceholder`, or `getByText`, then `getByTestId`. CSS only when nothing else reaches the element.
- Members go in this order, separated by blank lines rather than comments: `path`, components, locators, constructor, `readyLocator`, dynamic locators, actions, `assert*` methods.
- Actions are verbs (`fillOrderForm`, `placeOrder`, `signIn`) and never assert.
- `assert*` methods hold grouped or data-driven checks that specs would otherwise repeat. A single check stays in the spec.
- Pages never call APIs or build test data. That belongs to request objects and `data/`.

## Waiting on a request

- An action that triggers a request starts `waitForResponse` before it clicks, then awaits it. Started after the click, the wait misses a response that has already landed.
- Match on the method too when one URL serves several verbs.
- When the test needs the response, the action returns it parsed: `placeOrder()` returns the created `Order`. Otherwise it only waits: `cancel()`.

```ts
// Misses a response that lands before the wait starts
await this.placeOrderButton.click();
await this.page.waitForResponse('**/api/orders');

// Listens first, then clicks
const response = this.page.waitForResponse('**/api/orders');
await this.placeOrderButton.click();
await response;
```

## Components

- Every component extends `BaseComponent` and joins a page as a `readonly` field.
- A component that appears once locates from `page`.
- A component that repeats takes a `root` locator and builds every locator from it. The page hands out one per item: `orderCard(id)`.

## Examples

```ts
// pages/BasePage.ts
import { expect, type Locator, type Page } from '@playwright/test';

export abstract class BasePage {
  protected abstract readonly path: string;

  constructor(readonly page: Page) {}

  protected abstract get readyLocator(): Locator;

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
import { HeaderComponent } from '../components/HeaderComponent';
import { OrderCardComponent } from '../components/OrderCardComponent';
import type { NewOrder, Order } from '../data/orders';
import { BasePage } from './BasePage';

export class OrdersPage extends BasePage {
  protected readonly path = '/orders';

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

```ts
// components/HeaderComponent.ts
import type { Locator, Page } from '@playwright/test';
import { BaseComponent } from './BaseComponent';

export class HeaderComponent extends BaseComponent {
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
import { BaseComponent } from './BaseComponent';

export class OrderCardComponent extends BaseComponent {
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
    const response = this.page.waitForResponse(
      (r) => r.url().endsWith('/cancel') && r.request().method() === 'POST',
    );
    await this.cancelButton.click();
    await response;
  }
}
```
