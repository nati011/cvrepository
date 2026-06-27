# CV Repository — Product Manual

> **PDF:** [CV_Repository_Product_Documentation.pdf](CV_Repository_Product_Documentation.pdf)  
> Regenerate PDF: `PYTHONPATH=.pylibs python3 generate_product_pdf.py`  
> Capture mobile screenshots: `../scripts/capture_screenshots.sh`  
> Capture web admin screenshots: `node scripts/capture_web_screenshots.mjs` (requires backend + web UI running)

CV Repository is a full-stack talent review platform: a **Next.js web admin** for ingest, pipeline management, and hiring operations, plus a **Flutter mobile exec feed** for ranked candidate triage on the go.

---

# Part I — Web Admin

The web admin runs at `http://localhost:3000` and proxies to the Go API. Sidebar navigation: **Dashboard · Library · Jobs · Campaigns · Pipeline**.

## Dashboard

Live snapshot of the CV library — ingest volume, parse pipeline, search readiness, storage, and 14-day upload trends. Quick actions for upload, jobs, campaigns, pipeline, and search.

![Web dashboard](screenshots/admin/01_dashboard.png)

## CV Library

Browse all uploaded résumé PDFs with extraction and indexing status. Paginated table with click-through to candidate profile.

![CV library](screenshots/admin/02_library.png)

## CV Detail

Individual CV view with AI-extracted profile (name, skills, experience), pipeline stage indicators, and embedded PDF viewer.

![CV detail](screenshots/admin/03_cv_detail.png)

## Upload

Drag-and-drop or file-picker upload for new résumé PDFs. Triggers the background extraction and profiling pipeline.

![Upload CVs](screenshots/admin/04_upload.png)

## Jobs

Reusable **role definitions** (title + job description) for CV ranking. Create, edit, delete, and rank on demand.

![Jobs list](screenshots/admin/05_jobs.png)

## Job Detail

Full job description, ranking progress bar, and actions to edit, rank CVs, or delete.

![Job detail](screenshots/admin/06_job_detail.png)

## Campaigns

Operational **hiring initiatives** with lifecycle status, client metadata, and analytics. Filter by Open · Active · Draft · Paused · Closed · Archived.

![Campaigns table](screenshots/admin/07_campaigns.png)

## Campaign Detail

Single campaign view with stats, review funnel analytics, ranked feed, and lifecycle controls.

![Campaign detail](screenshots/admin/08_campaign_detail.png)

## Pipeline

Monitor background processing: **Ingestion → Extraction → Profiling → Ranking** with per-stage pending/processing/ready/failed counts.

![Data pipeline](screenshots/admin/09_pipeline.png)

## Search

Keyword search across extracted CV text via Meilisearch — skills, titles, filenames.

![Search](screenshots/admin/10_search.png)

## Profile

Reviewer account settings and activity summary.

![Web profile](screenshots/admin/11_profile.png)

---

# Part II — Mobile Exec Feed

**CV Exec Feed** is the Flutter mobile client. Screenshots captured from a physical Android device against a live backend.

## Navigation shell

- **Profile avatar** (top left) — reviewer profile and stats
- **Global search** — candidates, skills, and roles
- **Notifications bell** — pipeline and ranking alerts
- **Bottom tabs** — Feed · Jobs · Campaigns · Lists · Chat

## Feed

AI-ranked candidate cards with fit filters (**All**, **Strong**, **Solid**, **Emerging**). Each card shows fit score, subscores, TL;DR, skills, role matches, and Like/Star/Pass actions.

![Feed tab](screenshots/01_feed.png)

## Jobs

Reusable role definitions with ranked-candidate counts and **New job** FAB.

![Jobs tab](screenshots/02_jobs.png)

## Campaigns

Hiring initiatives with status filters and **New campaign** FAB.

![Campaigns tab](screenshots/03_campaigns.png)

## Lists

Personal shortlists — **My Score** dashboard, Liked and Starred segments.

![Lists tab](screenshots/04_lists.png)

## Chat

Natural-language Q&A with evidence-backed citations powered by Groq.

![Chat tab](screenshots/05_chat.png)

## Profile

Reviewer identity, activity stats, theme toggle, and leaderboard link.

![Profile screen](screenshots/06_profile.png)

## Notifications

Pipeline and ranking alerts (e.g. "N candidates ranked").

![Notifications screen](screenshots/07_notifications.png)

## Stats & Leaderboard

Team-wide review metrics, streak tracking, and per-reviewer breakdown.

![Stats / Leaderboard](screenshots/08_leaderboard.png)

---

## Regenerating screenshots

**Mobile** (device connected, backend on LAN):

```bash
cd mobile
flutter build apk --debug --dart-define=API_BASE_URL=http://<host-ip>:8080
adb install -r build/app/outputs/flutter-apk/app-debug.apk
./scripts/capture_screenshots.sh
```

**Web admin** (backend + `npm run dev` in `web/`):

```bash
cd mobile/docs
node scripts/capture_web_screenshots.mjs
```

---

## Related docs

- [Mobile README](../README.md) — Flutter setup and run
- [Web README](../../web/README.md) — Next.js admin UI
- [Repository README](../../README.md) — platform architecture and API
