# KeyAtlas Feature Reference (Web App)

Source: https://keyatlas.io | Repo: github.com/kennnyshiwa/KeyAtlas

## Authentication
- Sign up / Sign in (NextAuth — email/password + OAuth providers)
- Email verification flow
- Profile management (avatar upload, username, bio)
- API key management for external integrations

## Projects (Core Feature)
- Browse all projects with sort options: newest, oldest, A-Z, Z-A, most followed, recently updated
- Project detail page with:
  - Hero image (full-width, Cloudflare Images CDN)
  - Status badge (Interest Check, Group Buy, Production, Shipping, Completed)
  - GB dates / estimated delivery in hero header
  - Description (rich text)
  - Pricing section (min/max in multiple currencies)
  - Vendor list with regions and storefront links
  - Timeline entries
  - Gallery (carousel with thumbnail rail, object-contain, full-width)
  - Sound tests (embedded)
  - Comments section
  - Project updates/changelog
  - Follow/favorite functionality
- Project submission form with:
  - Section sidebar navigation with jump-to and highlight
  - Hero image upload with progress bar
  - Gallery Studio (multi-image upload, reorder, metadata)
  - Slug field (permanent URL, read-only after creation)
  - Rich text description editor
  - Vendor multi-select
  - Timeline builder
  - Tags
  - Links (GeeKHack, etc.)
  - Estimated delivery (free text, e.g. "Q3 2026")
  - Price input (dollars display, cents storage)
- Admin features: publish/feature toggle, ownership transfer

## Discover Pages
- Interest Checks
- Group Buys (active)
- Ending Soon
- New This Week
- Build Guides
- Vendors directory

## Vendors
- Vendor listing page
- Vendor detail page with logo, description, regions, storefront URL
- Projects associated with vendor

## Forums
- Forum categories
- Thread listing per category
- Thread detail with posts
- Create new threads, reply to threads
- Post editing/deletion

## Build Guides
- Guide listing
- Guide detail (rich content)
- Guide creation

## Compare
- Side-by-side project comparison

## Calendar
- Calendar view of GB start/end dates
- Expected Deliveries section by quarter (e.g. "Q1 2026")

## Statistics
- Total projects, vendors, active GBs, shipped count
- Projects by Category (pie chart)
- Projects by Status (pie chart)
- Group Buys per Month (line chart)
- Top 10 Designers (bar chart)
- Top 10 Vendors (bar chart)

## Activity Feed
- Recent activity across the platform

## Notifications
- In-app notifications
- Notification preferences
- Follow notifications (project status changes)

## Search
- Global search across projects

## User Profiles
- Public user profile pages (`/users/[username]`)
- User's submitted projects, followers/following

## Media/Upload
- Cloudflare Images integration (CDN-backed)
- Upload with progress bars (two phases: uploading → processing)
- Server-side SHA256 dedup
- 20MB max per image
- SmartImage component (trusted hosts → Next Image optimizer, others → direct img)

## API (v1 — Public)
- GET /api/v1/projects — list projects
- GET /api/v1/projects/[slug] — project detail
- GET /api/v1/projects/latest — latest projects
- GET /api/v1/categories — category list
- GET /api/v1/vendors — vendor list
- GET /api/v1/calendar — calendar data

## Tech Stack (Web)
- Next.js 15 (App Router)
- Prisma + PostgreSQL
- Redis (rate limiting, caching)
- Meilisearch (search)
- Cloudflare Images (media)
- NextAuth (authentication)
- Tailwind CSS + shadcn/ui
- Recharts (statistics)
- Docker deployment on GHCR
