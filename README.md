# 📚 Study Vault — AI-Powered Academic Companion & Knowledge Hub

<div align="center">

**Study Vault** is an intelligent, offline-capable study assistant and personal knowledge repository built with **Flutter**, **Google Gemini AI**, and **Supabase**. It transforms course materials, lecture slides, and notes into interactive Socratic lessons, instant practice quizzes, smart flashcards, and grounded RAG knowledge search.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)](https://flutter.dev)
[![Gemini](https://img.shields.io/badge/Google%20Gemini-1.5%20%2F%202.0%20Flash-8E75B2?logo=google)](https://ai.google.dev/)
[![SQLite](https://img.shields.io/badge/SQLite-Local%20First-003B57?logo=sqlite)](https://sqlite.org)
[![Supabase](https://img.shields.io/badge/Supabase-Backend%20Ready-3ECF8E?logo=supabase)](https://supabase.com)

</div>

---

## 🌟 Core Feature Suite

### 1. 🤖 Live Google Gemini AI Reasoning & Socratic Tutor
- **Interactive Socratic Tutor**: Guides learning step-by-step with analogies, concrete code/formulas, common exam pitfalls, and active check-for-understanding questions.
- **Multi-Model Fallback Engine**: Seamlessly falls back across `gemini-1.5-flash`, `gemini-2.0-flash`, and `gemini-1.5-pro` with retry timeouts.
- **Save Lesson to Vault**: 1-tap conversion of full AI tutor conversations into structured Markdown notes in your vault.
- **Preconfigured AI Studio Key Support**: Ready to use out of the box with custom key overriding in Settings.

### 2. 📄 In-App PDF Reader & Document Viewer (`SfPdfViewer`)
- **Rich Document Rendering**: Powered by Syncfusion PDF Viewer for local files, remote URLs, and dynamic in-memory academic PDFs.
- **In-Document Text Search**: Fast text search with previous/next occurrence navigation and match counters.
- **Reading Controls**: Jump-to-page dialog, high-contrast dark reading mode, and zoom controls.
- **AI Study Sidecar**: Instant bottom-sheet actions for any open document:
  - 💡 *Explain Current Page*
  - 🎯 *Generate 5-Minute Practice Quiz*
  - 🃏 *Create Active Recall Flashcards*
  - 📋 *Generate Executive Document Summary*

### 3. 📥 Universal Document Import (Anywhere in App)
- **Universal Import Service**: Import PDFs, TXTs, Markdown files, and Word documents from:
  - Dashboard Home Screen
  - Add / Ingestion Hub
  - Subject Folders Screen
  - Folder Details Screen
- **Automated Text Extraction & Chunking**: Extracts page-by-page text using `syncfusion_flutter_pdf` and indexes content locally in SQLite for instant AI retrieval.

### 4. 📊 Redesigned Modern Dashboard & Gamification
- **Live Vault Metrics Banner**: Real-time counter of total Subjects, PDF Documents, Markdown Notes, and Daily Streak 🔥.
- **Global Search & AI Hub Trigger**: Fast search bar with an instant AI Topic Hub launcher.
- **Interactive AI Study Arena Carousel**: Quick access to Socratic Tutor, Quiz Arena, Flashcards, and Scratchpad.
- **Interactive Vault Explorer with Filter Tabs**: Switch between *All Vault*, *PDFs & Documents*, *Notes*, and *Subjects*.
- **Empty State Delight**: Clean, modern onboarding card for fresh vaults with 1-tap starter buttons.

### 5. ⚡ Quick Scratchpad & Formula Board
- Quick bottom sheet to jot down equations, formulas, or lecture thoughts.
- Features **Auto-Save**, **1-Tap Save to Vault as Permanent Note**, and **Explain with AI**.

### 6. 🎯 AI Exam Target & Study Plan Generator
- Set custom exam targets (Exam Title, Course, Target Date).
- Real-time countdown cards (*"X Days Left"*) with AI-generated daily milestone study schedules.

---

## 🛠️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── ai/               # Gemini LLM Service, RAG Retriever, Socratic/Quiz prompt builders
│   ├── config/           # GeminiConfig & SupabaseConfig
│   ├── database/         # LocalDbService (SQLite: folders, notes, files, stats, flashcards)
│   ├── providers/        # Riverpod database, AI, and auth providers
│   ├── router/           # GoRouter route definitions & navigation shell
│   ├── services/         # DocumentImportService, TTS, Connectivity, SyncService
│   ├── theme/            # AppColors, AppTheme (Obsidian Dark palette, Indigo/Emerald accents)
│   └── utils/            # PdfGeneratorHelper, PerformanceLogger
│
└── features/
    ├── ai/               # Multi-mode AI Chat Assistant (Ask, Explain, Summarize)
    ├── documents/        # PDF extraction & semantic vectorization pipeline
    ├── exam/             # Exam setup & AI study milestone scheduler
    ├── files/            # Complete SfPdfViewer & AI Study Sidecar
    ├── flashcards/       # Flashcard player & deck generator
    ├── folders/          # Subject folders CRUD & detail views
    ├── home/             # Redesigned Dashboard & AI Action Hubs
    ├── notes/            # Markdown note editor & viewer
    ├── profile/          # Account Settings, Gemini API Key manager & Model Switcher
    ├── quiz/             # AI MCQ practice quiz generator & evaluation
    ├── scan/             # OCR study material camera scanner
    ├── search/           # Global vault search & semantic filtering
    └── study/            # Socratic AI Tutor screen & study sessions
```

---

## 🚀 Getting Started & Installation

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.29.0 or later)
- Android SDK (API 31+) or Chrome/Linux desktop

### Setup & Run

1. **Clone the repository:**
   ```bash
   git clone <repo-url>
   cd study_vault
   ```

2. **Install Flutter packages:**
   ```bash
   flutter pub get
   ```

3. **Verify analyzer:**
   ```bash
   flutter analyze
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

---

## 📦 Android APK Build & Wireless Download

### Building the APK
```bash
flutter build apk --debug --android-skip-build-dependency-validation
```

Output binary:
`build/app/outputs/flutter-apk/app-debug.apk`

### Wireless Download on Wi-Fi Network
Start a local HTTP server:
```bash
python3 -m http.server 8080 --directory build/app/outputs/flutter-apk
```
On your mobile device connected to the same Wi-Fi, open:
```
http://<your-local-ip>:8080/app-debug.apk
```

---

## 📋 Changelog & Recent Milestones

- ✅ Configured live **Google Gemini API** with multi-model fallback (`1.5 Flash`, `2.0 Flash`, `1.5 Pro`).
- ✅ Resolved PDF viewer dependencies and implemented complete **`SfPdfViewer`** with search, page jump, contrast toggle, and AI sidecar.
- ✅ Built **`DocumentImportService`** enabling universal file imports across all screens.
- ✅ Fixed prompt builder interpolation bugs in Socratic Tutor, Quiz, and Evaluation services.
- ✅ Removed hardcoded pre-seeded materials; SQLite database starts completely clean with auto-migration.
- ✅ Redesigned the entire **Dashboard** with Vault Metrics, Exam Countdown, Quick Actions, and Filter Tabs.
- ✅ Added **Quick Scratchpad**, **Exam Goal Tracker**, and **AI Study Command Hub**.
- ✅ Verified with `flutter analyze` (**0 errors**) and `flutter test` (**All passed**).
