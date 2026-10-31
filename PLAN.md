---
name: project-mobile-flutter
description: "Flutter app Chạm Xanh (Android+iOS) — decisions agreed 2026-10-31, work not started yet"
metadata:
  node_type: memory
  type: project
  originSessionId: 4037cefa-f2ab-4f80-8bcb-4cd48bd150c8
  modified: 2026-10-31T09:49:17.949Z
---

User asked (2026-10-31) for a Flutter app, pushed to https://github.com/Ziec205/CX_Mobile-.git (repo empty; local folder `Mobile/` empty).

Decisions from Q&A:
- Flutter (SDK installed, Android SDK in %LOCALAPPDATA%\Android\Sdk). Keep .NET BE + Next.js web, adjust them so all three stay in sync ("đồng bộ cao, lâu dài, ổn định").
- Screens: login/register, Hồ sơ vườn, nhắc tưới, Cộng đồng, Khám phá, Chat (realtime), Nâng cấp gói (PayOS QR), Tài khoản. Colors from web globals.css (emerald/stone/wood/water scales).
- Watering reminders: high-priority local notifications styled like alarms (sound+vibrate, "Đã tưới"/"Nhắc lại 10 phút"), synced with BE careReminders.
- Chat: SignalR already exists in BE (`/hubs/chat`, `/api/auth/hub-token`, events "message"/"notification"); web uses `src/lib/realtime.ts`.
- Plant photos: stored on device in a "Chạm Xanh/<plant>" folder AND a Photos/Gallery album; Mongo keeps only plant data/species. BE MyPlant.MediaIds currently stores media — must stop storing; web should show species image instead.
- Upgrade: BE returns PayOS QR (PayOsGateway.CreateAsync currently only keeps checkoutUrl; add `qrCode` from response).
- No Firebase yet (FCM later, leave hook). iOS: add GitHub Actions macOS build (unsigned).
- Push BE to github.com/Ziec205/CX_BE (53 uncommitted files incl. garden/escrow removal) and FE to its repo; user will recreate Render service `chamxanh-api` (currently "no-server").

**Why:** user had to shut down PC mid-task; resume from here.
**How to apply:** start with BE changes (qrCode, plant photos), then web, then Flutter app, test on Android emulator, commit/push. Related: [[project-subscriptions-ai]], [[env-local-be-e2e]].
