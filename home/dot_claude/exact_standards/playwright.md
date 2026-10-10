# Playwright

How [testing.md](testing.md) is spelled for Playwright end-to-end tests, built on page objects. Where these files differ from [languages/typescript.md](languages/typescript.md), they win. A repo with its own structure keeps it.

## What to read

| Writing or changing | Read |
|---|---|
| A page or component object | [playwright/pages.md](playwright/pages.md) |
| A request object | [playwright/requests.md](playwright/requests.md) |
| Fixtures | [playwright/fixtures.md](playwright/fixtures.md) |
| Config, sign-in, or lint setup | [playwright/config.md](playwright/config.md) |
| A spec | [playwright/specs.md](playwright/specs.md), then the files for whatever it touches |

## Layout

With no existing suite, start one in `e2e/` at the repo root:

```
e2e/
├── playwright.config.ts
├── eslint.config.mjs
├── auth/              storage-state paths shared by config and setup
├── pages/             BasePage.ts, <Name>Page.ts
├── components/        BaseComponent.ts, <Name>Component.ts
├── apiRequests/       BaseRequests.ts, <Area>Requests.ts
├── fixtures/          <area>Fixtures.ts
├── data/              types and builders for test data
├── playwright/.auth/  saved storage states, gitignored
└── tests/
    ├── setup/         <role>.setup.ts
    ├── <feature>/     <name>.spec.ts
    └── api/           <name>.api.ts
```

- A file holding a class is PascalCase, named exactly for its class: `OrdersPage.ts`, `OrderCardComponent.ts`, `OrdersRequests.ts`.
- Every other file is camelCase: specs (`orders.spec.ts`), setup (`customer.setup.ts`), fixtures (`ordersFixtures.ts`), data, and config.
- One class per file, as a named export: `export class OrdersPage`.
- `.spec.ts` tests run in a browser. `.api.ts` tests run in their own project, with no browser, and call the running app's API as a client would. A client's own HTTP code is an integration test instead: see [testing.md](testing.md).
