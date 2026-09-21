const { test, expect } = require('@playwright/test');

const email = process.env.CARGODEK_TEST_EMAIL;
const password = process.env.CARGODEK_TEST_PASSWORD;

async function acceptTermsIfShown(page) {
  const accept = page.locator('#acceptCurrentTermsBtn');
  if (await accept.isVisible().catch(() => false)) {
    await page.locator('#currentTermsAgree').check();
    await accept.click();
    await expect(page.locator('#appView')).toBeVisible({ timeout: 20_000 });
  }
}

async function signIn(page) {
  await page.goto('/');
  await expect(page.locator('#authView')).toBeVisible();
  await page.locator('#email').fill(email);
  await page.locator('#password').fill(password);
  await page.locator('#authSubmit').click();
  await expect.poll(async () => {
    const appVisible = await page.locator('#appView').isVisible().catch(() => false);
    const authError = await page.locator('#authMsg .error').isVisible().catch(() => false);
    return appVisible || authError;
  }, { timeout: 30_000 }).toBe(true);
  const error = page.locator('#authMsg .error');
  if (await error.isVisible().catch(() => false)) {
    throw new Error('CargoDek sign-in failed: ' + await error.innerText());
  }
  await acceptTermsIfShown(page);
  await expect.poll(async () => {
    const onboardingVisible = await page.locator('#obName').isVisible().catch(() => false);
    const sidebarVisible = await page.locator('#sidebar .nav').first().isVisible().catch(() => false);
    return onboardingVisible || sidebarVisible;
  }, { timeout: 30_000 }).toBe(true);
  const onboarding = page.locator('#obName');
  if (await onboarding.isVisible().catch(() => false)) {
    const unique = 'CargoDek E2E Test ' + Date.now();
    await page.locator('#obName').fill(unique);
    await page.locator('#obReg').fill('E2E-' + Date.now());
    await page.locator('#obCountry').fill('South Africa');
    await page.locator('#obRep').fill('CargoDek E2E Test');
    await page.locator('input[name="obRole"][value="shipper"]').check();
    await page.locator('input[name="obRole"][value="transporter"]').check();
    await page.getByRole('button', { name: 'Create Company Profile' }).click();
    await expect(page.locator('#modal')).not.toHaveClass(/show/, { timeout: 30_000 });
  }
  await acceptTermsIfShown(page);
  await expect(page.locator('#appView')).toBeVisible({ timeout: 30_000 });
}

async function ensureRole(page, role) {
  const activeRole = page.locator('#roleSwitcher option[value="' + role + '"]');
  if (await activeRole.count()) {
    await page.locator('#roleSwitcher').selectOption(role);
    return;
  }
  await page.locator('#sidebar [data-page="company"]').click();
  await page.getByRole('button', { name: '+ Add Role' }).click();
  const roleInput = page.locator('input[name="newRole"][value="' + role + '"]');
  if (await roleInput.count()) {
    await roleInput.check();
    await page.getByRole('button', { name: 'Add Selected Roles' }).click();
  }
  await expect.poll(async () => await page.locator('#roleSwitcher option[value="' + role + '"]').count(), { timeout: 20_000 }).toBeGreaterThan(0);
  await page.locator('#roleSwitcher').selectOption(role);
}

test.describe('CargoDek public smoke checks', () => {
  test('auth screen exposes the intended sign-in and role registration surface', async ({ page }) => {
    await page.goto('/');
    await expect(page).toHaveTitle(/CargoDek Africa/i);
    await expect(page.locator('#authView')).toBeVisible();
    await expect(page.locator('#email')).toBeVisible();
    await expect(page.locator('#password')).toBeVisible();
    await page.getByRole('button', { name: 'Create account' }).click();
    const expectedRoles = ['shipper','freight_broker','transporter','fuel_supplier','fuel_buyer','fleet_hire','retail_fuel_supplier','clearing_agent','warehouse','roadside_assistance','equipment_hire','asset_sales','truck_stop'];
    for (const role of expectedRoles) {
      await expect(page.locator('input[name="signupRole"][value="' + role + '"]')).toBeVisible();
    }
  });

  test('load posting UI hides manual coordinates and exposes photo upload', async ({ page }) => {
    test.skip(!email || !password, 'Set CARGODEK_TEST_EMAIL and CARGODEK_TEST_PASSWORD for authenticated tests.');
    await signIn(page);
    await ensureRole(page, 'shipper');
    await page.locator('#sidebar [data-page="post"]').click();
    await expect(page.locator('#originLocation')).toBeVisible();
    await expect(page.locator('#destinationLocation')).toBeVisible();
    await expect(page.locator('#loadPhotos')).toBeVisible();
    await expect(page.locator('#originLatitude')).toHaveAttribute('type', 'hidden');
    await expect(page.locator('#originLongitude')).toHaveAttribute('type', 'hidden');
    await expect(page.locator('#destinationLatitude')).toHaveAttribute('type', 'hidden');
    await expect(page.locator('#destinationLongitude')).toHaveAttribute('type', 'hidden');
    await expect(page.locator('#loadPhotos')).toHaveAttribute('accept', /image\/jpeg/);
  });
});

test.describe('CargoDek authenticated end-to-end', () => {
  test.skip(!email || !password, 'Set CARGODEK_TEST_EMAIL and CARGODEK_TEST_PASSWORD to run authenticated E2E tests.');

  test('sign in, create or verify company role, post a geolocated load with photos, and verify it on the Load Board', async ({ page }) => {
    await signIn(page);
    await ensureRole(page, 'shipper');
    await page.locator('#sidebar [data-page="post"]').click();
    const commodity = 'E2E Cargo ' + Date.now();
    await page.locator('#loadForm input[name="commodity"]').fill(commodity);
    await page.locator('#loadForm input[name="weight_per_load"]').fill('10');
    await page.locator('#loadForm input[name="number_of_loads"]').fill('1');
    await page.locator('#originLocation').fill('-26.2041, 28.0473');
    await page.getByRole('button', { name: 'Detect pickup location' }).click();
    await expect(page.locator('#originLocationStatus')).toContainText('Detected:', { timeout: 15_000 });
    await page.locator('#destinationLocation').fill('-17.8252, 31.0335');
    await page.getByRole('button', { name: 'Detect destination' }).click();
    await expect(page.locator('#destinationLocationStatus')).toContainText('Detected:', { timeout: 15_000 });
    await expect(page.locator('#originLatitude')).toHaveValue('-26.204100');
    await expect(page.locator('#originLongitude')).toHaveValue('28.047300');
    await expect(page.locator('#destinationLatitude')).toHaveValue('-17.825200');
    await expect(page.locator('#destinationLongitude')).toHaveValue('31.033500');
    const png = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=', 'base64');
    await page.locator('#loadPhotos').setInputFiles({ name: 'cargodek-e2e.png', mimeType: 'image/png', buffer: png });
    await expect(page.locator('#loadPhotoPreview img')).toHaveCount(1);
    await page.locator('#loadForm').getByRole('button', { name: 'Publish Load' }).click();
    await expect(page.getByRole('heading', { name: commodity })).toBeVisible({ timeout: 30_000 });
    await page.locator('#sidebar [data-page="loads"]').click();
    await expect(page.getByRole('heading', { name: commodity })).toBeVisible({ timeout: 30_000 });
    const card = page.locator('.load', { hasText: commodity }).first();
    await expect(card.locator('img[alt="Load photo"]')).toHaveCount(1, { timeout: 20_000 });
  });
});
