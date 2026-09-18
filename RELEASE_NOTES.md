# Study Vault — Release Notes (v1.0.0)

**Release Date:** September 2026  
**Status:** **RELEASE READY**  
**Version:** `1.0.0+1`  
**License:** Proprietary / MIT Compatible Academic

---

## 🎓 Overview

Study Vault is a production-grade, offline-first academic study companion and knowledge vault for students and lifelong scholars. Built with Flutter, SQLite, Riverpod, Supabase, and Google Gemini, Study Vault bridges deep structured syllabus management with state-of-the-art on-device Retrieval-Augmented Generation (RAG).

---

## ✨ Key Features & Enhancements

### 1. Official Visual Identity & Design System
- **Official Branding:** Integrated official high-resolution logo (`sv-logo.png`) across splash screen, authentication headers, and about dialogs without distortion or recoloring.
- **Launcher Icons:** Pixel-perfect mipmap densities generated across `mdpi`, `hdpi`, `xhdpi`, `xxhdpi`, and `xxxhdpi` for Android.
- **Design System:** Cohesive dark/light theme tokens for typography, spacing, elevations, colors, and responsive breakpoints.

### 2. Academic Workspace & Syllabus Architecture
- **Hierarchical Scaffolding:** Support for Workspaces, Academic Years, Academic Periods (Semesters/Trimesters), and Subjects.
- **Vault Organization:** Folders, customizable color-coded labels, tags, markdown notes, and universal file attachments.
- **Universal Import:** System Share Target integration accepting PDFs, images, text, and documents directly from external apps with non-destructive AI organization proposals.

### 3. Local-First & Cloud Synchronization
- **Offline Reliability:** Full local SQLite database (`study_vault_local.db`) with complete offline CRUD and vector chunk indexing.
- **Two-Way Sync:** Outbox pattern with exponential backoff, retry queues, and deterministic conflict resolution (remote update wins with local backup).
- **Network Resilience:** Seamless transition between online cloud backup (Supabase) and isolated offline study mode.

### 4. Grounded AI Intelligence & Hybrid RAG (Phase 11)
- **Local + Semantic Search:** Hybrid BM25 keyword and vector cosine similarity retriever ensuring high precision on student notes.
- **Strict Academic Grounding:** Socratic Tutor mode, syllabus-aligned study plan generator, and multi-format practice quizzes with direct source citations (`[Doc: page]`).
- **User Safety:** Non-destructive Smart Organization sheet requiring explicit student confirmation before filing notes.

### 5. Collaboration & Peer Discovery (Phase 9)
- **Student Profiles & Discovery:** Searchable handles, customizable degree/branch metadata, and share privacy controls.
- **Study Groups & Study Packs:** Bundle subject materials into shareable study packs with QR code instant discovery.
- **Granular Permissions:** View-only or contributor permissions with complete revocation support.

### 6. Production Hardening & Privacy (Phase 12)
- **Environment Isolation:** Multi-environment configuration (`development`, `staging`, `production`) via `--dart-define` flags.
- **Zero Credential Leakage:** API keys and sensitive tokens automatically scrubbed from crash reports, diagnostics, and analytics.
- **Data Portability & Cascading Deletion:** One-click JSON data export and irreversible cascading account purge across all 28 SQLite tables and remote datastores.
- **Privacy-Preserving Telemetry:** In-memory crash monitoring and operational analytics tracking milestones without capturing note contents or student queries.

---

## 🛡️ Security & Privacy Compliance

| Security Area | Implementation Details |
| :--- | :--- |
| **API Keys & Secrets** | Loaded via compile-time `--dart-define`; masked in logs (`AIza...****`) |
| **Database Encryption & RLS** | Row-Level Security on Supabase; private sandboxed local SQLite on device |
| **Debug Route Guards** | Developer tools and `/design-preview` disabled in production and release builds |
| **Data Deletion** | Complete cascade across all user-owned rows in all tables upon account deletion |
| **Data Export** | Full JSON export of workspace, subjects, folders, and notes without credentials |

---

## 📋 Release Verification Summary

- **Total Test Cases Passed:** 194+ unit, integration, and widget tests (100% pass rate).
- **Static Analysis:** `flutter analyze` completed with 0 errors and 0 warnings.
- **Asset Integrity:** Verified RGBA integrity for `sv-logo.png` and all Android launcher icon mipmap densities.
- **Production Status:** **RELEASE READY**
