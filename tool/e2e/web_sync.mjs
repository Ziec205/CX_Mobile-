// Kiểm tra đồng bộ app ↔ web: chờ app (integration test) in "CX_WEB_SYNC <user> <pass>", rồi mở web bằng
// trình duyệt di động, đăng nhập cùng tài khoản, kiểm tra dữ liệu app vừa tạo, bấm "Đã làm" và thêm một cây trên web.
// Chụp ảnh + vị trí nút vào <shots>/web_shots.json để đưa vào tài liệu.
//
// node tool/e2e/web_sync.mjs <drive.log> <web base> <shots dir> <done file>
import fs from 'node:fs';
import { createRequire } from 'node:module';
const require = createRequire(import.meta.url);
const { chromium } = require('playwright');

const [logFile, web, shotsDir, doneFile] = process.argv.slice(2);
fs.mkdirSync(shotsDir, { recursive: true });
try { fs.unlinkSync(doneFile); } catch {}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let user, pass;
for (let i = 0; i < 2400 && !user; i++) {
  const m = fs.existsSync(logFile) && fs.readFileSync(logFile, 'utf8').match(/CX_WEB_SYNC (\S+) (\S+)/);
  if (m) [, user, pass] = m; else await sleep(500);
}
if (!user) { console.error('Không thấy tín hiệu CX_WEB_SYNC từ app'); process.exit(1); }
console.log('Web: đăng nhập', user);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 412, height: 891 }, deviceScaleFactor: 2, isMobile: true, hasTouch: true, locale: 'vi-VN' });
const shots = [];
const checks = [];
async function shot(name, title, desc, marks) {
  await page.waitForTimeout(500);
  const rects = [];
  for (const [loc, label] of marks) {
    const box = await loc.first().boundingBox().catch(() => null);
    if (box) rects.push({ label, x: box.x, y: box.y, w: box.width, h: box.height });
  }
  await page.screenshot({ path: `${shotsDir}/${name}.png` });
  shots.push({ name, title, desc, dpr: 2, w: 412, h: 891, marks: rects });
  console.log('Web: đã chụp', name);
}
function check(ok, what) { checks.push({ ok, what }); console.log(ok ? '  ✓' : '  ✗', what); }

try {
  await page.goto(`${web}/dang-nhap?next=/vuon-cua-toi`);
  await page.getByPlaceholder('Tên đăng nhập').first().fill(user);
  await page.getByPlaceholder('Mật khẩu').first().fill(pass);
  await page.getByRole('button', { name: 'Đăng nhập' }).last().click();
  await page.waitForURL(/vuon-cua-toi/, { timeout: 30000 }).catch(() => page.goto(`${web}/vuon-cua-toi`));
  await page.getByText('Trầu bà góc phòng khách').first().waitFor({ timeout: 30000 });

  check(await page.getByText('Trầu bà góc phòng khách').count() > 0, 'Web thấy cây tạo trên app (Trầu bà góc phòng khách)');
  check(await page.getByText('Lưỡi hổ ban công').count() > 0, 'Web thấy cây thứ hai (Lưỡi hổ ban công)');
  check(await page.getByText(/✓ Đã làm/).count() >= 1, 'Web thấy “Đã làm” vừa bấm “Đã tưới” trên app');
  check(await page.getByText('Tưới 200ml quanh gốc').count() > 0, 'Web thấy lời nhắc đặt trên app (ghi chú “Tưới 200ml quanh gốc”)');
  const lh = page.locator('article', { hasText: 'Lưỡi hổ ban công' });
  await lh.scrollIntoViewIfNeeded();
  await shot('13w1-web-vuon', 'Trên web: cùng một vườn', 'Mở web Chạm Xanh bằng cùng tài khoản: cây, lời nhắc và lần “Đã tưới” vừa làm trên app hiện ngay.', [
    [lh.getByText('Lưỡi hổ ban công'), 'Cây tạo trên app'],
    [lh.getByText(/✓ Đã làm/), 'Lần “Đã tưới” bấm trên app'],
  ]);

  const tb = page.locator('article', { hasText: 'Trầu bà góc phòng khách' });
  const fert = tb.locator('li', { hasText: 'Bón phân' });
  await fert.scrollIntoViewIfNeeded();
  await shot('13w2-web-da-lam', 'Trên web: bấm “Đã làm”', 'Việc nào làm rồi thì bấm “Đã làm” ngay trên web; app sẽ thấy khi tải lại.', [
    [fert.getByRole('button', { name: 'Đã làm' }), 'Bấm “Đã làm” trên web'],
  ]);
  await fert.getByRole('button', { name: 'Đã làm' }).click();
  await fert.getByText(/✓ Đã làm/).waitFor({ timeout: 15000 });
  check(true, 'Bấm “Đã làm” trên web thành công');

  await page.getByRole('button', { name: '+ Thêm cây' }).click();
  await page.getByPlaceholder('Vd: Trầu bà góc phòng khách').fill('Hoa giấy cổng nhà');
  await page.getByPlaceholder('Ban công, sân thượng…').fill('Cổng nhà');
  await page.getByRole('button', { name: 'Lưu', exact: true }).click();
  await page.getByText('Hoa giấy cổng nhà').first().waitFor({ timeout: 15000 });
  check(true, 'Thêm cây “Hoa giấy cổng nhà” trên web');
  await page.getByText('Hoa giấy cổng nhà').first().scrollIntoViewIfNeeded();
  await shot('13w3-web-them-cay', 'Trên web: thêm cây', 'Cây thêm trên web sẽ có trong app ở lần đồng bộ kế tiếp.', [
    [page.getByText('Hoa giấy cổng nhà').first(), 'Cây vừa thêm trên web'],
  ]);
} catch (e) {
  check(false, 'Lỗi khi thao tác web: ' + e.message.split('\n')[0]);
  await page.screenshot({ path: `${shotsDir}/web-loi.png` }).catch(() => {});
} finally {
  fs.writeFileSync(`${shotsDir}/web_shots.json`, JSON.stringify(shots, null, 2));
  fs.writeFileSync(`${shotsDir}/web_checks.json`, JSON.stringify(checks, null, 2));
  await browser.close();
  fs.writeFileSync(doneFile, 'ok');
}
process.exit(checks.every((c) => c.ok) ? 0 : 1);
