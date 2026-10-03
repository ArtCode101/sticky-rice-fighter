// Web journey script.
//
// One file per journey, generated from journeys/<slug>.md AFTER that document exists.
// The steps here are the steps in the document, in the same order, including the ones
// inserted to make a later step possible.
//
// Mock data is injected before the journey starts, through the Python tools in the
// tool repository. This script does not touch a datastore itself.

import { test, expect } from '@playwright/test';

// Saved browser session, for a journey whose login goes through a provider. The first
// run has a human sign in; later runs start from this file. Git-ignored.
const STORAGE_STATE = '../.storage-state/general-user.json';

test.describe('Add an income record', () => {
  // Uncomment for a provider login. For username and password the journey logs in as
  // step 1 instead, and no storage state is needed.
  // test.use({ storageState: STORAGE_STATE });

  test('a user with no account can add an income record', async ({ page }) => {
    // Step 1 - log in
    await page.goto('/login');
    await page.getByLabel('Username').fill(process.env.JOURNEY_USERNAME!);
    await page.getByLabel('Password').fill(process.env.JOURNEY_PASSWORD!);
    await page.getByRole('button', { name: 'Log in' }).click();

    // Step 2 - create an account.
    // Inserted: step 4 has nowhere to put a record until an account exists.
    await page.getByRole('link', { name: 'Accounts' }).click();
    await page.getByRole('button', { name: 'Create account' }).click();
    await page.getByLabel('Account name').fill('Everyday');
    await page.getByRole('button', { name: 'Save' }).click();

    // Step 3 - open the account page
    await page.getByRole('link', { name: 'Everyday' }).click();

    // Step 4 - add an income record
    await page.getByRole('button', { name: 'Add record' }).click();
    await page.getByLabel('Type').selectOption('income');
    await page.getByLabel('Amount').fill('1200');
    await page.getByRole('button', { name: 'Save' }).click();

    // What tells us it worked
    await expect(page.getByRole('row', { name: /1,?200/ })).toBeVisible();
    await expect(page.getByTestId('account-balance')).toContainText('1,200');
  });
});
