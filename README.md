# Confectionery DMS – CASHLIFYPOS

Confectionery Distribution System (quotation CPOS-2026-112-R1): Android app (Flutter, MVC, offline-first) + sync API
(Node/Express + MongoDB Atlas on Render).

```
app/       Flutter Android app (APK) – see app/README.md
backend/   Node/Express sync API (MVC: routes → controllers → services)
render.yaml  Render blueprint for the API
```

## 1. MongoDB Atlas
1. Create a cluster (M0 free is fine to start) → Database Access: add a user → Network Access: allow `0.0.0.0/0`.
2. Copy the connection string (`mongodb+srv://...`).

## 2. Render (API)
1. Render → **New → Blueprint** → select this repo (uses `render.yaml`), or **New → Web Service** with
   Root directory `backend`, Build `npm install`, Start `node server.js`, Health check `/api/health`.
2. Environment: `MONGODB_URI` = Atlas string, `API_TOKEN` = long random secret (Blueprint generates one),
   `DB_NAME=confectionery_dms`, `TZ=Asia/Karachi`.
3. Open `https://<service>.onrender.com/api/health` → `{"ok":true}`.

> Free plan sleeps after 15 min idle (first sync then waits ~50 s and the nightly backup may be skipped).
> Use the Starter plan for field staff.

## 3. App
In the app: **Settings & Sync** → Server URL `https://<service>.onrender.com` and API token = `API_TOKEN` → Save → Sync now.
Do this on the owner's phone first, then on every staff phone (users, shops, products come down automatically).

## API

| Method | Path | Purpose |
|---|---|---|
| GET | `/api/health` | health check (no token) |
| POST | `/api/sync/push` | phone → server changes |
| GET | `/api/sync/pull?since=&deviceId=` | server → phone changes (paged, `hasMore`) |
| POST | `/api/sync/reserve` | unique number block for orders / bills / purchases / returns / vouchers |
| GET | `/api/admin/stats` | record counts, devices, last backup |
| GET/POST | `/api/admin/backups` | list / run backup (gzip JSON in GridFS, last 7 kept, nightly 02:30 PKT) |
| GET | `/api/admin/backups/:id` | download a backup |

All except `/api/health` need `Authorization: Bearer <API_TOKEN>`.

## APK (automatic build)
Every push to `main` that changes `app/` builds the APK on GitHub Actions.
Download it from the repo's **Releases** tab (`ConfectioneryDistribution-<n>.apk`) or from **Actions → Build APK → Artifacts**.
Run it manually: Actions → Build APK → Run workflow.
