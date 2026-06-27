#!/usr/bin/env python3
"""Generate CV Repository product documentation PDF (web admin + mobile app)."""

from __future__ import annotations

from pathlib import Path

from fpdf import FPDF

DOCS = Path(__file__).resolve().parent
MOBILE_SHOTS = DOCS / "screenshots"
ADMIN_SHOTS = DOCS / "screenshots" / "admin"
OUTPUT = DOCS / "CV_Repository_Product_Documentation.pdf"

FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")
FONT_REGULAR = str(FONT_DIR / "DejaVuSans.ttf")
FONT_BOLD = str(FONT_DIR / "DejaVuSans-Bold.ttf")

PRIMARY = (2, 64, 79)
SECONDARY = (235, 125, 35)
INK = (10, 26, 31)
MUTED = (100, 116, 125)
WHITE = (255, 255, 255)

SECTIONS: list[tuple[str, str]] = [
    ("overview", "Product Overview"),
    ("platform", "Platform Architecture"),
    ("admin_shell", "Web Admin - Navigation"),
    ("admin_dashboard", "Web Admin - Dashboard"),
    ("admin_library", "Web Admin - CV Library"),
    ("admin_cv_detail", "Web Admin - CV Detail"),
    ("admin_upload", "Web Admin - Upload"),
    ("admin_jobs", "Web Admin - Jobs"),
    ("admin_job_detail", "Web Admin - Job Detail"),
    ("admin_campaigns", "Web Admin - Campaigns"),
    ("admin_campaign_detail", "Web Admin - Campaign Detail"),
    ("admin_pipeline", "Web Admin - Pipeline"),
    ("admin_search", "Web Admin - Search"),
    ("admin_profile", "Web Admin - Profile"),
    ("mobile_intro", "Mobile App - Overview"),
    ("mobile_nav", "Mobile App - Navigation"),
    ("mobile_feed", "Mobile App - Feed"),
    ("mobile_jobs", "Mobile App - Jobs"),
    ("mobile_campaigns", "Mobile App - Campaigns"),
    ("mobile_lists", "Mobile App - Lists"),
    ("mobile_chat", "Mobile App - Chat"),
    ("mobile_profile", "Mobile App - Profile"),
    ("mobile_notifications", "Mobile App - Notifications"),
    ("mobile_stats", "Mobile App - Stats & Leaderboard"),
]


class ProductDoc(FPDF):
    def __init__(self) -> None:
        super().__init__(orientation="P", unit="mm", format="A4")
        self.set_auto_page_break(auto=True, margin=20)
        self.set_margins(18, 18, 18)
        self.add_font("Body", "", FONT_REGULAR)
        self.add_font("Body", "B", FONT_BOLD)
        self.add_font("Body", "I", FONT_REGULAR)
        self._section_num = 0

    def footer(self) -> None:
        if self.page_no() == 1:
            return
        self.set_y(-14)
        self.set_font("Body", "I", 8)
        self.set_text_color(*MUTED)
        self.cell(0, 8, "CV Repository - Product Documentation", align="C")
        self.set_x(self.l_margin)
        self.cell(0, 8, f"Page {self.page_no()}", align="R")

    def cover_page(self) -> None:
        self.add_page()
        self.set_fill_color(*PRIMARY)
        self.rect(0, 0, 210, 297, style="F")
        self.set_fill_color(*SECONDARY)
        self.rect(0, 88, 210, 4, style="F")

        self.set_y(48)
        self.set_font("Body", "B", 32)
        self.set_text_color(*WHITE)
        self.cell(0, 14, "CV Repository", new_x="LMARGIN", new_y="NEXT")

        self.set_font("Body", "", 16)
        self.set_text_color(220, 230, 233)
        self.cell(0, 10, "Product Documentation", new_x="LMARGIN", new_y="NEXT")

        self.ln(44)
        self.set_font("Body", "", 11)
        self.set_text_color(200, 215, 220)
        self.multi_cell(
            0,
            6,
            "Complete guide to the CV repository platform: the Next.js web admin for "
            "ingest, pipeline management, and hiring operations, plus the Flutter "
            "mobile exec feed for ranked candidate review.",
        )

        self.set_y(248)
        self.set_font("Body", "", 10)
        self.set_text_color(180, 200, 205)
        self.cell(0, 6, "Kifiya Financial Technology", new_x="LMARGIN", new_y="NEXT")
        self.cell(0, 6, "June 2026", new_x="LMARGIN", new_y="NEXT")

    def toc_page(self, entries: list[tuple[str, int]]) -> None:
        self.add_page()
        self.section_title("Contents", numbered=False)
        self.ln(4)
        self.set_font("Body", "", 10)
        self.set_text_color(*INK)
        for title, page in entries:
            dots = "." * max(2, 52 - len(title))
            self.cell(0, 7, f"{title} {dots} {page}", new_x="LMARGIN", new_y="NEXT")

    def section_title(self, title: str, numbered: bool = True) -> None:
        if numbered:
            self._section_num += 1
            label = f"{self._section_num}. {title}"
        else:
            label = title
        self.ln(2)
        self.set_font("Body", "B", 17)
        self.set_text_color(*PRIMARY)
        self.cell(0, 10, label, new_x="LMARGIN", new_y="NEXT")
        self.set_draw_color(*SECONDARY)
        self.set_line_width(0.6)
        self.line(self.l_margin, self.get_y(), self.l_margin + 42, self.get_y())
        self.ln(6)

    def subsection(self, title: str) -> None:
        self.ln(2)
        self.set_font("Body", "B", 12)
        self.set_text_color(*INK)
        self.cell(0, 8, title, new_x="LMARGIN", new_y="NEXT")
        self.ln(1)

    def body(self, text: str) -> None:
        self.set_font("Body", "", 10.5)
        self.set_text_color(*INK)
        self.multi_cell(0, 5.5, text)
        self.ln(2)

    def bullets(self, items: list[str]) -> None:
        self.set_font("Body", "", 10.5)
        self.set_text_color(*INK)
        for item in items:
            self.set_x(self.l_margin)
            self.multi_cell(0, 5.5, f"  \u2022  {item}")
        self.ln(2)

    def screenshot(self, filename: str, caption: str, *, admin: bool = False) -> None:
        base = ADMIN_SHOTS if admin else MOBILE_SHOTS
        path = base / filename
        if not path.exists():
            self.body(f"[Screenshot missing: {filename}]")
            return

        usable = self.w - self.l_margin - self.r_margin
        if admin:
            img_w = usable
            img_h = img_w * (900 / 1440)
        else:
            img_w = min(usable * 0.62, 95)
            img_h = img_w * (1600 / 720)

        if self.get_y() + img_h + 16 > 277:
            self.add_page()

        x = (self.w - img_w) / 2
        self.image(str(path), x=x, w=img_w, h=img_h)
        self.ln(2)
        self.set_font("Body", "I", 9)
        self.set_text_color(*MUTED)
        self.cell(0, 5, caption, new_x="LMARGIN", new_y="NEXT", align="C")
        self.ln(3)


def render_section(pdf: ProductDoc, key: str) -> None:
    if key == "overview":
        pdf.section_title("Product Overview")
        pdf.body(
            "CV Repository is a full-stack talent review platform. Recruiters and "
            "executive reviewers upload CV PDFs, run them through an AI-powered pipeline "
            "(extraction, profiling, ranking), and triage candidates against reusable "
            "job definitions and operational hiring campaigns."
        )
        pdf.subsection("Two client surfaces")
        pdf.bullets([
            "Web admin (Next.js) - upload, library management, pipeline monitoring, "
            "job/campaign CRUD, ranking controls, and keyword search",
            "Mobile exec feed (Flutter) - ranked candidate cards, reactions, "
            "shortlists, AI chat with citations, and team leaderboard",
        ])
        pdf.subsection("Key capabilities")
        pdf.bullets([
            "PDF ingest with text extraction and Meilisearch indexing",
            "Groq-powered profile extraction, fit scoring, one-pagers, and chat",
            "Reusable job definitions and lifecycle-managed hiring campaigns",
            "Ranked feeds, reactions (like/star/pass/shortlist), and analytics",
            "Evidence-backed natural-language Q&A across the CV corpus",
        ])
    elif key == "platform":
        pdf.section_title("Platform Architecture")
        pdf.body(
            "Both clients share a single Go API backend with PostgreSQL metadata, "
            "filesystem PDF storage, and background worker processing."
        )
        pdf.subsection("Backend services")
        pdf.bullets([
            "Go API - REST endpoints for CVs, jobs, campaigns, feed, reactions, chat, stats",
            "Go worker - async extraction, profiling, and ranking jobs",
            "PostgreSQL - CV, job, campaign, and reaction metadata",
            "Meilisearch - full-text keyword search over extracted CV text",
            "Apache Tika - PDF text extraction",
            "Groq - LLM for profiles, ranking, one-pagers, and chat answers",
        ])
        pdf.subsection("Deployment")
        pdf.bullets([
            "Web UI: npm run dev (default http://localhost:3000, proxies to API)",
            "Mobile: flutter run with --dart-define=API_BASE_URL=<host>:8080",
            "Infrastructure: docker compose for Postgres, Meilisearch, and Tika",
        ])
    elif key == "admin_shell":
        pdf.section_title("Web Admin - Navigation")
        pdf.body(
            "The web admin uses a persistent sidebar with global search, notifications, "
            "and reviewer profile in the top bar."
        )
        pdf.bullets([
            "Dashboard - library metrics, upload trends, quick actions",
            "Library - all CV documents with extraction status",
            "Jobs - reusable role definitions for ranking",
            "Campaigns - operational hiring initiatives with lifecycle",
            "Pipeline - ingestion, extraction, profiling, and ranking stages",
        ])
        pdf.screenshot("01_dashboard.png", "Web admin shell and dashboard", admin=True)
    elif key == "admin_dashboard":
        pdf.section_title("Web Admin - Dashboard")
        pdf.body(
            "Live snapshot of the CV library: ingest volume, parse pipeline status, "
            "search readiness, storage usage, and 14-day upload trends."
        )
        pdf.bullets([
            "Stat cards for library size, search-ready count, jobs, campaigns, pipeline, storage",
            "Upload activity chart (14 days)",
            "Quick actions: upload CVs, manage jobs/campaigns, view pipeline, search",
        ])
        pdf.screenshot("01_dashboard.png", "Dashboard - CV repository overview", admin=True)
    elif key == "admin_library":
        pdf.section_title("Web Admin - CV Library")
        pdf.body("Browse all uploaded résumé PDFs with extraction and indexing status.")
        pdf.bullets([
            "Paginated table of CV documents",
            "Status badges for extraction, profiling, and indexing",
            "Click through to candidate profile and PDF viewer",
        ])
        pdf.screenshot("02_library.png", "Library - all CV documents", admin=True)
    elif key == "admin_cv_detail":
        pdf.section_title("Web Admin - CV Detail")
        pdf.body(
            "Individual CV view with extracted profile, pipeline status, and PDF preview."
        )
        pdf.bullets([
            "Candidate name, contact, skills, and experience from AI extraction",
            "Pipeline stage indicators",
            "Embedded PDF viewer",
        ])
        pdf.screenshot("03_cv_detail.png", "CV detail - profile and PDF viewer", admin=True)
    elif key == "admin_upload":
        pdf.section_title("Web Admin - Upload")
        pdf.body("Drag-and-drop or file-picker upload for new résumé PDFs.")
        pdf.bullets([
            "Multi-file upload support",
            "Optional title override per document",
            "Triggers background extraction and profiling pipeline",
        ])
        pdf.screenshot("04_upload.png", "Upload - add new CV PDFs", admin=True)
    elif key == "admin_jobs":
        pdf.section_title("Web Admin - Jobs")
        pdf.body(
            "Manage reusable role definitions (title + job description) used for CV ranking."
        )
        pdf.bullets([
            "List all job definitions with ranked-candidate counts",
            "Create, edit, and delete roles",
            "Rank CVs against a job description on demand",
        ])
        pdf.screenshot("05_jobs.png", "Jobs - reusable role definitions", admin=True)
    elif key == "admin_job_detail":
        pdf.section_title("Web Admin - Job Detail")
        pdf.body("View and manage a single job definition.")
        pdf.bullets([
            "Full job description with markdown rendering",
            "Ranking progress bar (pending, processing, done, failed)",
            "Actions: edit, rank CVs, delete",
        ])
        pdf.screenshot("06_job_detail.png", "Job detail - description and ranking progress", admin=True)
    elif key == "admin_campaigns":
        pdf.section_title("Web Admin - Campaigns")
        pdf.body(
            "Operational hiring campaigns with lifecycle status, client metadata, and analytics."
        )
        pdf.bullets([
            "Filter by status: Open, Active, Draft, Paused, Closed, Archived",
            "Table with ranked count, shortlist count, and creation date",
            "Create new campaigns and deactivate existing ones",
        ])
        pdf.screenshot("07_campaigns.png", "Campaigns - hiring initiatives table", admin=True)
    elif key == "admin_campaign_detail":
        pdf.section_title("Web Admin - Campaign Detail")
        pdf.body("Single campaign view with stats, ranked feed, and lifecycle controls.")
        pdf.bullets([
            "Campaign metadata: client, location, headcount, tags",
            "Review funnel analytics (ranked, shortlisted, reactions)",
            "Rank CVs and view ranked candidate feed",
        ])
        pdf.screenshot(
            "08_campaign_detail.png",
            "Campaign detail - stats and ranked feed",
            admin=True,
        )
    elif key == "admin_pipeline":
        pdf.section_title("Web Admin - Pipeline")
        pdf.body(
            "Monitor the background processing pipeline across all CVs."
        )
        pdf.bullets([
            "Four stages: Ingestion, Extraction, Profiling, Ranking",
            "Per-stage counts: pending, processing, ready/done, failed",
            "Links to individual CVs stuck in a stage",
        ])
        pdf.screenshot("09_pipeline.png", "Pipeline - processing stage monitor", admin=True)
    elif key == "admin_search":
        pdf.section_title("Web Admin - Search")
        pdf.body("Keyword search across extracted CV text via Meilisearch.")
        pdf.bullets([
            "Full-text search by skills, titles, filenames",
            "Instant results with relevance ranking",
            "Click through to CV detail",
        ])
        pdf.screenshot("10_search.png", "Search - keyword CV lookup", admin=True)
    elif key == "admin_profile":
        pdf.section_title("Web Admin - Profile")
        pdf.body("Reviewer account settings and activity summary.")
        pdf.bullets([
            "Reviewer identity and organization",
            "Review activity stats",
            "Preferences",
        ])
        pdf.screenshot("11_profile.png", "Profile - reviewer account", admin=True)
    elif key == "mobile_intro":
        pdf.section_title("Mobile App - Overview")
        pdf.body(
            "CV Exec Feed is the Flutter mobile client for executive candidate review. "
            "It gives reviewers a LinkedIn-inspired interface for triaging AI-ranked "
            "candidates on the go."
        )
        pdf.bullets([
            "Ranked candidate feed with fit scores and subscore breakdowns",
            "Like, star, and pass reactions with personal shortlists",
            "Evidence-backed AI chat across the CV pile",
            "Team leaderboard and review streak tracking",
        ])
    elif key == "mobile_nav":
        pdf.section_title("Mobile App - Navigation")
        pdf.body("Every screen shares a consistent shell:")
        pdf.bullets([
            "Profile avatar (top left) - reviewer profile and stats",
            "Global search - candidates, skills, and roles",
            "Notifications bell - pipeline and ranking alerts",
            "Bottom tabs - Feed, Jobs, Campaigns, Lists, Chat",
        ])
    elif key == "mobile_feed":
        pdf.section_title("Mobile App - Feed")
        pdf.body(
            "AI-ranked candidate cards sorted by fit score with All/Strong/Solid/Emerging filters."
        )
        pdf.bullets([
            "Fit score (0-100) with domain, seniority, and skills subscores",
            "TL;DR summary, skill tags, and role matches",
            "Like, Star, and Pass triage actions",
        ])
        pdf.screenshot("01_feed.png", "Mobile feed - ranked candidate cards")
    elif key == "mobile_jobs":
        pdf.section_title("Mobile App - Jobs")
        pdf.body("Reusable role definitions with ranked-candidate counts.")
        pdf.bullets([
            "List of job definitions",
            "New job FAB",
            "Tap for detail, rank, or edit",
        ])
        pdf.screenshot("02_jobs.png", "Mobile jobs - role definitions")
    elif key == "mobile_campaigns":
        pdf.section_title("Mobile App - Campaigns")
        pdf.body("Hiring initiatives with lifecycle status filters.")
        pdf.bullets([
            "Status filters: Open, Active, Draft, Paused, Closed, Archived",
            "Campaign cards with ranked count",
            "New campaign FAB",
        ])
        pdf.screenshot("03_campaigns.png", "Mobile campaigns - hiring initiatives")
    elif key == "mobile_lists":
        pdf.section_title("Mobile App - Lists")
        pdf.body("Personal shortlists from feed reactions.")
        pdf.bullets([
            "My Score dashboard",
            "Liked and Starred segments",
            "Candidate name, role match, fit %, reaction date",
        ])
        pdf.screenshot("04_lists.png", "Mobile lists - liked and starred")
    elif key == "mobile_chat":
        pdf.section_title("Mobile App - Chat")
        pdf.body("Natural-language Q&A with evidence-backed citations.")
        pdf.bullets([
            'Ask questions like "Who has the strongest Go experience?"',
            "Cited answers linking to specific CV claims",
            "Scoped to full CV pile or selected job",
        ])
        pdf.screenshot("05_chat.png", "Mobile chat - ask the CV pile")
    elif key == "mobile_profile":
        pdf.section_title("Mobile App - Profile")
        pdf.body("Reviewer identity, activity stats, and theme settings.")
        pdf.bullets([
            "Total reviews, likes, stars, streak",
            "View leaderboard link",
            "Light / Dark / System theme",
        ])
        pdf.screenshot("06_profile.png", "Mobile profile - reviewer identity")
    elif key == "mobile_notifications":
        pdf.section_title("Mobile App - Notifications")
        pdf.body("Pipeline and ranking alerts.")
        pdf.bullets([
            'Ranking completion ("N candidates ranked")',
            "In-flight processing progress",
            "Tap to jump to relevant tab",
        ])
        pdf.screenshot("07_notifications.png", "Mobile notifications - pipeline alerts")
    elif key == "mobile_stats":
        pdf.section_title("Mobile App - Stats & Leaderboard")
        pdf.body("Team-wide review metrics and streak tracking.")
        pdf.bullets([
            "Summary cards: total, likes, stars",
            "Leaderboard by review activity",
            "Per-reviewer breakdown with streak days",
        ])
        pdf.screenshot("08_leaderboard.png", "Mobile stats - team leaderboard")


def build() -> Path:
    probe = ProductDoc()
    probe.cover_page()
    page_map: dict[str, int] = {}
    for key, _title in SECTIONS:
        page_map[key] = probe.page_no() + 1
        probe.add_page()
        render_section(probe, key)

    pdf = ProductDoc()
    pdf.cover_page()
    toc_entries = [(title, page_map[key] + 1) for key, title in SECTIONS]
    pdf.toc_page(toc_entries)

    for key, _title in SECTIONS:
        pdf.add_page()
        render_section(pdf, key)

    pdf.output(str(OUTPUT))
    return OUTPUT


if __name__ == "__main__":
    path = build()
    print(f"Generated {path}")
