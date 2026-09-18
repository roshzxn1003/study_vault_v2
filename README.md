# 📚 Study Vault — Personal Academic Companion & Knowledge Hub

<div align="center">

**Study Vault** is an offline-first, student-centric academic companion and repository built with **Flutter**, **SQLite**, and **Supabase**. It empowers students to organize lecture slides, reference documents, and notes into structured academic workspaces, transition seamlessly across semesters, triage incoming files via universal system sharing, exchange study packs, and collaborate securely with peers.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![SQLite](https://img.shields.io/badge/SQLite-Offline--First%20v5-003B57?logo=sqlite)](https://sqlite.org)
[![Supabase](https://img.shields.io/badge/Supabase-Auth%20%26%20Cloud%20Sync-3ECF8E?logo=supabase)](https://supabase.com)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-1.5%20Flash%20%26%20Pro-8E75B2?logo=google)](https://ai.google.dev)
[![Analysis](https://img.shields.io/badge/Analyzer-0%20Issues-brightgreen)](https://dart.dev)
[![Tests](https://img.shields.io/badge/Automated%20Tests-194%20Passing-brightgreen)](https://flutter.dev)
[![Release](https://img.shields.io/badge/Release%20Status-RELEASE%20READY-success)](RELEASE_NOTES.md)

</div>

---

## 📖 Documentation
- 🚀 **[Release Notes (v1.0.0)](RELEASE_NOTES.md)** — Production highlights, security checklist, and release verification.
- 🧑‍🏫 **[User Guide](USER_GUIDE.md)** — Getting started, syllabus building, Universal Import, AI study tutor, and data controls.
- 🛠️ **[Developer & Maintenance Guide](DEVELOPER_GUIDE.md)** — Architecture, database migrations, RAG pipeline, `--dart-define` configurations, and testing protocols.

---

## 🏛️ System Architecture

Study Vault is engineered around an offline-first, unidirectional data flow architecture powered by Riverpod and repository abstractions:

```
lib/
├── core/
│   ├── auth/             # Supabase Auth integration & AuthUser entities
│   ├── config/           # SupabaseConfig, AppEnvironment
│   ├── database/         # LocalDbService (SQLite schema v4, migrations, composite indexes)
│   ├── design/           # Phase 2 Design System tokens, typography, colors, components
│   ├── network/          # ConnectivityService (active internet reachability verification)
│   ├── router/           # GoRouter declaration, session guards, production route stripping
│   └── theme/            # Obsidian dark theme, semantic palette, elevations
│
└── features/
    ├── academic/         # Workspaces, Academic Years, Semesters/Grades, Subject hierarchy
    ├── auth/             # Login, Sign Up, Password Reset, Guest Mode, Multi-User Isolation
    ├── dashboard/        # Academic Header, Historical Banner, Subjects, Inbox & Recent feeds
    ├── import/           # Universal Import Service, OS Share Target, Duplicate Deduplication
    ├── inbox/            # Unorganized material staging, bulk triage & organization
    ├── onboarding/       # Purpose selection (College, School, Personal), draft recovery
    ├── profile/          # Student Profile, Account Settings, Data purge on logout
    ├── sharing/          # Peer sharing, QR discovery, Access Revocation, Study Groups & Packs
    ├── sync/             # Offline Outbox queue, exponential backoff, Supabase Cloud Sync
    └── vault/            # Materials, Nested Folders (cycle-safe), Multi-Labels, Search
```

---

## 💾 Local Database (SQLite v4)

Local persistence is powered by `LocalDbService` using SQLite with robust data isolation and performance indexing:
- **Unified Materials Table**: Encapsulates notes, PDFs, documents, images, and links with decoupled logical display titles, physical file paths, and SHA-256 content hashes.
- **Academic Hierarchy**: Workspaces → Academic Years → Academic Periods (Semesters / Class Grades) → Subjects.
- **Composite Indexes**:
  - `idx_materials_user_ws` on `materials(user_id, workspace_id)`
  - `idx_materials_user_subj` on `materials(user_id, subject_id)`
  - `idx_materials_user_folder` on `materials(user_id, folder_id)`
  - `idx_materials_user_period` on `materials(user_id, academic_period_id)`
  - `idx_folders_user_parent` on `folders(user_id, parent_id)`
  - `idx_subjects_user_period` on `academic_subjects(user_id, academic_period_id)`
  - `idx_periods_user_year` on `academic_periods(user_id, academic_year_id)`
- **Multi-User Purge**: `clearUserData(userId)` transactions completely purge all user-scoped data upon logout or account switch, preventing any local data leakage across student sessions.

---

## 🔄 Sync Architecture & Offline-First Outbox

- **Outbox Pattern**: All local mutations (inserts, updates, soft-deletes) are queued to `outbox_operations` with operation payloads and idempotency keys.
- **Exponential Backoff**: Transient network failures trigger structured retries at 5s, 15s, 60s, 300s, and 900s before flagging as terminal failures.
- **Connectivity Awareness**: `ConnectivityService` continuously monitors network state and triggers outbox synchronization as soon as internet access is restored.
- **Conflict Strategy**: Local pending mutations are preserved and prioritized over incoming remote pulls, preventing overwrite of un-synced offline edits.

---

## 👥 Student Sharing, Groups & Study Packs

- **Identity**: Public `@username` handles safe for peer discovery (never exposes email or authentication credentials).
- **QR Discovery**: Instant QR code generation encoding secure identification URIs (`studyvault://user/<username>?id=<id>&name=<fullName>`).
- **Granular Permissions**: 1-to-1 sharing supports view-only or download permissions, optional expiry dates, and instant owner access revocation.
- **Save Copy to Vault**: Recipients create fully independent, decoupled copies of shared materials in their personal vault, surviving owner revocation.
- **Study Groups**: Group feeds allow collaborative sharing without duplicating underlying files.
- **Study Packs**: Curated high-yield study bundles that can be shared and saved into personal vaults in a single batch operation.

---

## 🔒 Security & Privacy

1. **Row Level Security (RLS)**: Database policies in `migrations/phase9_collaboration.sql` enforce that students can only access their own private resources, resources shared explicitly with them, or materials in their active study groups.
2. **Search Isolation**: All local and remote search queries are strictly scoped to the authenticated user's ID.
3. **Destructive Action Guards**: Confirmations are required for material deletions, folder removals, group leaving, and share revocation.
4. **Secrets Management**: No hardcoded API keys or JWT tokens are stored in source control; environment configuration is injected via `--dart-define`.
5. **Production Route Protection**: Debug routes (such as `/design-preview`) are guarded and inaccessible in release mode.

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.29.0 or later)
- Android SDK (API 33+) or Linux / Chrome desktop

### Setup & Run
1. **Clone the repository:**
   ```bash
   git clone https://github.com/roshzxn1003/study_vault.git
   cd study_vault
   ```
2. **Install dependencies:**
   ```bash
   flutter pub get
   ```
3. **Verify analyzer (must be 0 issues):**
   ```bash
   flutter analyze
   ```
4. **Run automated test suite:**
   ```bash
   flutter test
   ```
5. **Run the application:**
   ```bash
   flutter run --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
   ```

---

## 🧪 Testing Commands

```bash
# Run all tests across the entire suite
flutter test

# Run the Phase 10 Master QA integration & security suite
flutter test test/phase10_master_qa_test.dart

# Run sharing and collaboration tests
flutter test test/sharing_test.dart

# Run sync engine & outbox tests
flutter test test/sync_engine_test.dart

# Run static analysis
flutter analyze
```

---

## 📦 Build Commands

```bash
# Build Android APK (Debug)
flutter build apk --debug

# Build Android APK (Release)
flutter build apk --release --dart-define=SUPABASE_URL=YOUR_URL --dart-define=SUPABASE_ANON_KEY=YOUR_KEY
```

---

## ⚠️ Operational Notes
 
1. **Cloud Sync Requires Active Supabase Project**: When offline or if Supabase credentials are omitted, the app runs entirely in private local-first mode using SQLite; two-way cloud synchronization activates seamlessly as soon as valid credentials are provided via `--dart-define`.
2. **AI Engine**: Local RAG keyword retrieval and cached study plans operate offline; live generative reasoning and conversational tutoring connect to Google Gemini models when an API key is present.
