# Study Vault — Developer & Maintenance Guide

This document provides architectural context, configuration guidelines, and testing protocols for engineers developing, testing, and maintaining Study Vault.

---

## 🏛️ Architecture & Tech Stack

Study Vault adheres to a **Feature-Driven, Clean-Layered Architecture**:

```
lib/
├── core/
│   ├── ai/               # Local RAG, embeddings, prompt builders, LLM orchestrator
│   ├── config/           # EnvironmentConfig, GeminiConfig, SupabaseConfig
│   ├── database/         # LocalDbService (SQLite schema versions 1..5)
│   ├── design/           # Design system tokens, components, previews
│   ├── router/           # AppRouter (GoRouter with auth guards and release protection)
│   ├── services/         # CrashMonitoringService, AnalyticsService, Connectivity
│   └── theme/            # AppTheme, dark/light modes, color palettes
└── features/
    ├── academic/         # Workspace, Years, Periods, Subjects hierarchy
    ├── ai/               # AI Chat interface, tutor mode, streaming responses
    ├── auth/             # Login, signup, password reset, splash
    ├── dashboard/        # Home screen, subject cards, streak metrics
    ├── import/           # Universal Import sheet, Android Share Receiver
    ├── privacy/          # Privacy Center, data export, account deletion
    ├── profile/          # Scholar profiles, preferences, API key management
    ├── sharing/          # Peer sharing, QR discovery, study groups, study packs
    ├── sync/             # Outbox queue, two-way sync engine
    └── vault/            # Materials, notes, folders, tags, search
```

### Key Libraries
- **UI Framework:** Flutter 3.x with Material 3 Design
- **State Management:** Riverpod (`flutter_riverpod: ^2.6.1`)
- **Navigation:** GoRouter (`go_router: ^18.0.0`)
- **Local Database:** SQLite (`sqflite: ^2.4.3` with `sqflite_common_ffi` for automated testing)
- **Cloud Backend:** Supabase (`supabase_flutter: ^2.0.0`)
- **AI Engine:** Google Generative AI (`google_generative_ai: ^0.4.7`)

---

## ⚙️ Environment Configuration & Dart Defines

Study Vault avoids hardcoded configuration secrets by utilizing compile-time `--dart-define` arguments handled by `EnvironmentConfig`:

### Environment Variables
| Variable | Description | Default |
| :--- | :--- | :--- |
| `APP_ENV` | `development`, `staging`, or `production` | `production` in release mode, otherwise `development` |
| `SUPABASE_URL` | Supabase instance URL | `''` (operates in offline-first mode if empty) |
| `SUPABASE_ANON_KEY` | Supabase anonymous API key | `''` |
| `GEMINI_API_KEY` | Optional global Gemini fallback key | `''` (users can configure in Settings) |

### Launch Commands

#### 1. Local Development (Debug Mode)
```bash
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://your-dev.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-dev-anon-key
```

#### 2. Staging / QA Build
```bash
flutter build apk --profile \
  --dart-define=APP_ENV=staging \
  --dart-define=SUPABASE_URL=https://your-staging.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=your-staging-anon-key
```

#### 3. Production Release Build
```bash
flutter build appbundle --release \
  --dart-define=APP_ENV=production \
  --dart-define=SUPABASE_URL=https://prod.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=prod-anon-key
```

---

## 🗄️ Database & Migration Architecture

Local SQLite storage is managed via `LocalDbService`:
- **Current Version:** `5`
- **Tables (28 total):**
  - Core Hierarchy: `workspaces`, `academic_years`, `academic_periods`, `academic_subjects`, `academic_structures`, `personal_topics`
  - Vault Items: `folders`, `materials`, `labels`, `material_labels`, `notes`, `files`
  - Study & Goals: `flashcards`, `study_stats`, `scratchpad`, `exam_goals`
  - Sync Layer: `outbox_operations`, `sync_metadata`
  - Collaboration (Phase 9): `student_profiles`, `shares`, `study_groups`, `group_members`, `group_resources`, `study_packs`, `study_pack_items`, `share_notifications`
  - AI & RAG (Phase 11): `document_chunks`, `ai_conversations`, `ai_messages`, `ai_study_plans`, `ai_quizzes`

### Cascading Purge Contract
When a user deletes their account or logs out, `LocalDbService.clearUserData(userId)` executes a single ACID transaction deleting all user-scoped rows across all tables, including sub-queries for joint entities (`material_labels`, `group_resources`, `study_pack_items`).

---

## 🤖 RAG & Intelligence Contract

1. **Chunking & Indexing:** Incoming documents and notes are tokenized into 400-token chunks with 50-token overlaps in `DocumentProcessor`.
2. **Hybrid Retrieval:** `HybridRetriever` combines term frequency BM25 search with cosine similarity embeddings.
3. **Citation Guard:** `AiOrchestrator` verifies that all AI assertions refer back to chunks present in the prompt context before returning answers to the user.

---

## 🧪 Testing & Verification Protocol

Always verify static analysis and run the test suite before submitting pull requests:

```bash
# 1. Verify static analysis (must report 0 issues)
flutter analyze

# 2. Run the complete test suite
flutter test

# 3. Run targeted Phase 12 release verification
flutter test test/phase12_production_release_test.dart
```
