# Config, sign-in, and linting

Part of the [Playwright standard](../playwright.md).

## Sign-in

- One setup project per role signs in through the login page object and saves its storage state through the `context` fixture. Every browser and API project depends on it and loads that state.
- Storage states live in `playwright/.auth/`, which is gitignored: the files hold live session cookies.
- Credentials come from environment variables, never source, and setup fails fast when one is missing.

## Config

- `fullyParallel: true`. Every test owns its data, so any two can run at once.
- `forbidOnly` and two retries on CI only. Traces are kept on failure.

```ts
// playwright.config.ts
import { defineConfig, devices } from '@playwright/test';
import { CUSTOMER_STORAGE_STATE } from './auth/storageStates';

export default defineConfig({
  testDir: './tests',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  use: {
    baseURL: process.env.BASE_URL ?? 'http://localhost:3000',
    trace: 'retain-on-failure',
  },
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

function requireEnv(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`${name} must be set`);
  return value;
}

setup('sign in as a customer', async ({ loginPage, ordersPage, context }) => {
  await loginPage.goto();
  await loginPage.signIn(requireEnv('E2E_CUSTOMER_EMAIL'), requireEnv('E2E_CUSTOMER_PASSWORD'));
  await ordersPage.assertDisplayed();
  await context.storageState({ path: CUSTOMER_STORAGE_STATE });
});
```

```gitignore
# .gitignore
playwright/.auth/
test-results/
```

## Linting

- `eslint-plugin-playwright`'s recommended rules run on `tests/`. They catch focused tests, `waitForTimeout`, unawaited assertions, and tests that assert nothing.
- `missing-playwright-await` also runs on page objects, where an unawaited `expect` in an `assert*` method passes silently.
- `expect-expect` counts `assert*` methods as assertions, and `no-wait-for-timeout` is an error rather than a warning.

```js
// eslint.config.mjs
import { defineConfig } from 'eslint/config';
import playwright from 'eslint-plugin-playwright';
import tseslint from 'typescript-eslint';

const recommended = playwright.configs['flat/recommended'];

export default defineConfig(
  { ignores: ['node_modules/', 'test-results/', 'playwright-report/'] },
  {
    files: ['**/*.ts'],
    languageOptions: { parser: tseslint.parser },
    plugins: { playwright },
    rules: { 'playwright/missing-playwright-await': 'error' },
  },
  {
    files: ['tests/**/*.ts'],
    languageOptions: recommended.languageOptions,
    rules: {
      ...recommended.rules,
      'playwright/no-wait-for-timeout': 'error',
      'playwright/expect-expect': ['error', { assertFunctionPatterns: ['^assert'] }],
    },
  },
);
```
