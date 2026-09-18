# Study Vault — User Guide

Welcome to **Study Vault**, your intelligent, offline-first academic study companion. Study Vault helps you organize your university or high school course materials, build structured syllabi, and study with an on-device AI tutor grounded strictly in your notes and textbooks.

---

## 🚀 Getting Started

### 1. Account Setup & Onboarding
- **Sign In / Guest Mode:** When launching Study Vault for the first time, you can register a new account, log into an existing account, or continue in offline guest mode.
- **Academic Workspace Setup:** Name your degree (e.g. *B.S. Computer Science*, *Pre-Med*, *Mechanical Engineering*) and set your current academic year and period (e.g. *Year 2, Semester 1*).
- **Add Your Subjects:** Quickly populate the subjects you are taking this semester (e.g. *Data Structures*, *Algorithms*, *Operating Systems*).

---

## 📚 Managing Your Vault

### 1. Folders, Notes, and Files
- Navigate to the **Vault** tab in the bottom navigation bar.
- Create topic-specific folders within each subject.
- Create rich markdown notes with code snippets, math formulas, and summaries.
- Attach reference documents, lecture slides, and PDF textbooks.

### 2. Universal Import (System Share Target)
- While viewing lecture slides or PDF files in external apps (e.g. Chrome, WhatsApp, Drive, File Manager), tap **Share** $\rightarrow$ select **Study Vault**.
- Study Vault will stage your items in the **Inbox**.
- **Smart AI Organization:** Tap "Suggest Organization" to have Gemini inspect the document title and content, recommending the optimal Subject and Folder. You can **Accept** the suggestion or **Keep Original** with zero risk of accidental misfiling.

---

## 🤖 Studying with AI (Google Gemini & RAG)

### 1. Configuring Your Gemini Engine (Optional)
Study Vault provides full offline study functionality without an AI key. To enable live multimodal reasoning:
1. Open **Profile** $\rightarrow$ **Settings & AI Configuration**.
2. Enter your free Google Gemini API Key (obtainable at [aistudio.google.com](https://aistudio.google.com)).
3. Select your model:
   - **Gemini 1.5 Flash:** Recommended for ultra-fast, everyday study queries and quizzes.
   - **Gemini 1.5 Pro:** Recommended for complex mathematical reasoning and deep Socratic dialogues.

### 2. Grounded Document Q&A
- Ask questions about your course materials in the **AI** tab.
- Study Vault indexes your notes and PDF slides locally into vector chunks.
- Every AI response is strictly grounded in your materials and provides exact page-level citations (`[Doc: Page X]`), preventing hallucinations.

### 3. Practice Quizzes & Flashcards
- Generate targeted practice quizzes and flashcard decks directly from your course slides.
- Choose between Multiple Choice (MCQ), Conceptual True/False, and Socratic Free Response.
- Review your mastery level and weak spots before midterms and finals.

---

## 📶 Offline-First & Cloud Synchronization

- **100% Offline Capability:** All notes, folder structures, and flashcards are stored locally in your private on-device SQLite database. You can study on airplanes, subways, or areas with spotty Wi-Fi.
- **Automatic Sync:** When an internet connection is re-established, the sync engine automatically flushes your offline changes to your private cloud storage.
- **Visual Sync Status:** A non-intrusive status banner informs you when you are studying offline and when cloud synchronization is complete.

---

## 👥 Student Sharing & Study Packs

- **Study Packs:** Bundle lecture notes, lab guides, and flashcards into a clean "Study Pack" to share with your study group.
- **Peer Discovery & QR:** Generate your personal Study Vault QR card under **Profile** $\rightarrow$ **My Study Vault QR** so classmates can find you instantly.
- **Privacy Controls:** You choose whether individual materials are Private, Shared with specific peers, or Group-accessible.

---

## 🔒 Privacy, Data Export & Deletion

- **Zero Cloud Training:** Your personal notes and exam materials are never used to train global AI models.
- **Export Your Data:** Navigate to **Privacy Center** $\rightarrow$ **Export My Data** to download an unencrypted, portable JSON archive of your entire vault.
- **Complete Account Deletion:** If you ever wish to leave, tap **Account Deletion** in the Privacy Center. All local SQLite records, cached files, cloud datastore entries, and authentication tokens are irreversibly purged.
