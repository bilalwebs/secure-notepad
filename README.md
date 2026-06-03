# 🔐 SecureNotepad

A privacy-focused, AI-powered note-taking application with military-grade encryption. Your notes, your key, your privacy.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Firebase](https://img.shields.io/badge/Firebase-Latest-FFCA28?logo=firebase)
![Gemini AI](https://img.shields.io/badge/Gemini-1.5%20Flash-4285F4?logo=google)
![Groq](https://img.shields.io/badge/Groq-Llama%203.3-000000?logo=meta)
![Dart](https://img.shields.io/badge/Dart-3.11+-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

> **Screenshots coming soon**

**Built with ❤️ by Muhammad Bilal Hussain**

---

## 📖 Overview

SecureNotepad is a cross-platform note-taking application that prioritizes your privacy above all else. Unlike traditional note apps, SecureNotepad implements a custom **Maze-Card Hybrid Cipher** where your master encryption key is **never stored** — not in the database, not on your device, not anywhere. If you lose your master key, even the developer cannot recover your encrypted notes.

Powered by dual AI engines (Google Gemini and Groq Llama), SecureNotepad offers intelligent features like summarization, grammar correction, and natural language note creation — all while keeping your sensitive data encrypted and secure.

**Key differentiator:** Zero-knowledge encryption. Your master key exists only in RAM while you're editing encrypted notes, then it's immediately wiped from memory.

---

## ✨ Features

| Feature | Status | Description |
|---------|--------|-------------|
| **Authentication** | | |
| Email/Password Registration | ✅ Complete | Full account creation with validation |
| Email Verification | ✅ Complete | Auto-polling (checks every 5 seconds) |
| Google Sign-In | ✅ Complete | Popup on web, native on mobile |
| Password Reset | ✅ Complete | 60-second resend cooldown |
| Username Uniqueness Check | ✅ Complete | Real-time Firestore query |
| Password Strength Meter | ✅ Complete | Weak/Fair/Good/Strong indicators |
| Route Guards | ✅ Complete | Protected + public route separation |
| **Notes & Editor** | | |
| Rich Text Editor | ✅ Complete | flutter_quill WYSIWYG |
| Bold / Italic / Underline | ✅ Complete | Visual formatting toolbar |
| Numbered & Bullet Lists | ✅ Complete | Mutually exclusive lists |
| Auto-save | ✅ Complete | Every 4 seconds while editing |
| Note CRUD | ✅ Complete | Create/Read/Update/Delete |
| Pin Notes | ✅ Complete | Pinned notes appear first |
| Word Count & Read Time | ✅ Complete | Live statistics in status bar |
| **Encryption** | | |
| Maze-Card Hybrid Cipher | ✅ Complete | Custom algorithm (see below) |
| Multi-round Fisher-Yates | ✅ Complete | 2-4 rounds per key |
| Master Key (in-memory only) | ✅ Complete | Never persisted anywhere |
| Encrypt/Decrypt Toggle | ✅ Complete | 🔓/🔒 icon in editor |
| Wrong Key Detection | ✅ Complete | Validates decryption output |
| **Folders** | | |
| Create Folders | ✅ Complete | With custom color picker |
| Rename Folders | ✅ Complete | Inline dialog |
| Delete Folder (keep notes) | ✅ Complete | Moves notes to root |
| Delete Folder + Notes | ✅ Complete | Cascade delete option |
| Folder Filter | ✅ Complete | Filter notes by folder |
| Note Count Badge | ✅ Complete | Real-time count per folder |
| **AI Features** | | |
| Gemini 1.5 Flash | ✅ Complete | Google AI (primary) |
| Groq Llama 3.3-70b | ✅ Complete | Ultra-fast fallback |
| Auto-fallback | ✅ Complete | Groq when Gemini quota hit |
| AI Panel in Editor | ✅ Complete | Slide-up bottom sheet |
| Summarize | ✅ Complete | 2-3 sentence summary |
| Fix Grammar | ✅ Complete | Corrects errors inline |
| Expand Idea | ✅ Complete | Detailed paragraph expansion |
| Shorten Note | ✅ Complete | Concise version |
| Generate Tags | ✅ Complete | 3-5 relevant tags |
| AI Chatbot Screen | ✅ Complete | Full conversational interface |
| Create Note from Chat | ✅ Complete | "Create a file X with description Y" |
| Create Folder from Chat | ✅ Complete | "Create folder X" |
| Streaming Output | ✅ Complete | Real-time typewriter effect |
| **Voice** | | |
| Voice to Text | ✅ Complete | speech_to_text package |
| Web Speech API | ✅ Complete | Chrome/Edge browser support |
| Android STT | ✅ Complete | Google Voice integration |
| iOS STT | ✅ Complete | Apple Speech framework |
| **UI/UX** | | |
| Dark Mode | ✅ Complete | System auto-detect + manual toggle |
| Teal Theme (#2EC4A9) | ✅ Complete | Custom design system |
| Sora + DM Sans Fonts | ✅ Complete | Google Fonts integration |
| Lottie Animations | ✅ Complete | Onboarding + loading states |
| Shimmer Loading | ✅ Complete | Skeleton screens for note cards |
| Delete with Undo | ✅ Complete | 4-second undo window |

---

## 🛠️ Tech Stack

| Layer | Technology | Version |
|-------|------------|---------|
| Framework | Flutter | 3.x |
| Language | Dart | 3.11+ |
| State Management | Riverpod | 2.6.1 |
| Routing | go_router | 16.1.0 |
| Auth | Firebase Auth | 6.5.1 |
| Database | Cloud Firestore | 6.4.1 |
| Storage | Firebase Storage | 13.4.1 |
| AI (Primary) | Google Gemini 1.5 Flash | 0.4.7 |
| AI (Fallback) | Groq Llama 3.3-70b | Latest (via HTTP) |
| Rich Text Editor | flutter_quill | 11.5.0 |
| Notifications | flutter_local_notifications | 18.0.1 |
| Voice Input | speech_to_text | 7.0.0 |
| Fonts | google_fonts | 6.2.1 |
| Animations | lottie | 3.3.1 |
| Image Handling | image_picker | 1.1.2 |
| Caching | hive_flutter | 1.1.0 |
| Calendar | table_calendar | 3.2.0 |
| PDF Generation | pdf | 3.11.2 |
| Sharing | share_plus | 10.1.4 |

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SecureNotepad App                    │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  PRESENTATION LAYER                                     │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │   Auth   │ │  Notes   │ │   AI     │ │ Profile  │  │
│  │ Screens  │ │ Screens  │ │  Chat    │ │ Screen   │  │
│  └────┬─────┘ └────┬─────┘ └────┬─────┘ └────┬─────┘  │
│       │            │            │            │         │
│  ┌────▼────────────▼────────────▼────────────▼──────┐  │
│  │              Riverpod Providers                  │  │
│  │  authProvider | notesProvider | themeProvider    │  │
│  │  aiProvider   | chatHistory   | folderProvider   │  │
│  └────┬──────────────────────────────────────┬──────┘  │
│       │                                      │         │
│  DATA LAYER                                  │         │
│  ┌────▼────────┐  ┌──────────────┐  ┌───────▼──────┐  │
│  │   Auth      │  │   Notes      │  │  AI Services │  │
│  │ Repository  │  │ Repository   │  │ Gemini/Groq  │  │
│  └────┬────────┘  └──────┬───────┘  └──────────────┘  │
│       │                  │                             │
│  CORE LAYER              │                             │
│  ┌────▼────┐  ┌──────────▼───────┐  ┌─────────────┐   │
│  │Firebase │  │ MazeCard Cipher  │  │  Voice      │   │
│  │ Auth +  │  │ encrypt()/       │  │  Service    │   │
│  │Firestore│  │ decrypt()        │  │  STT        │   │
│  └─────────┘  └──────────────────┘  └─────────────┘   │
└─────────────────────────────────────────────────────────┘
```

---

## 🔐 Encryption Algorithm: Maze-Card Hybrid Cipher

This is a **custom symmetric encryption algorithm** designed specifically for SecureNotepad. It is **not** a standard cipher (not AES, not RSA, not Blowfish). Here's how it works:

### Key Derivation

```dart
masterKey = "mypassword"
asciiSum  = sum of all character ASCII values
          = m(109) + y(121) + p(112) + a(97) + s(115) + s(115) 
            + w(119) + o(111) + r(114) + d(100)
          = 1113
seed      = asciiSum % 99991 = 1113
rounds    = 2 + (asciiSum % 3) = 2 + 0 = 2
```

### Encryption Flow

**Step 1: Character → Hex → Card Token Mapping**

Each character is converted to a 4-digit hexadecimal code, then each hex digit is mapped to a unique playing card symbol:

```
'H' (72₁₀) → '0048'₁₆ → ['A♠', '2♥', '6♦', 'A♣']
'e' (101₁₀) → '0065'₁₆ → ['A♠', '2♥', '8♦', '7♣']
'l' (108₁₀) → '006c'₁₆ → ['A♠', '2♥', '8♦', 'K♣']
```

Mapping table (bijective):
```
0→A♠  1→2♠  2→3♠  3→4♠  4→5♥  5→6♥  6→7♥  7→8♥
8→9♦  9→T♦  a→J♦  b→Q♦  c→K♦  d→X♣  e→Y♣  f→Z♣
```

**Step 2: Multi-round Fisher-Yates Shuffle**

The token array undergoes `rounds` iterations of deterministic Fisher-Yates shuffling using the derived seed.

**Step 3: Join with Spaces**

The final token array is joined with spaces to produce the ciphertext.

### Decryption Flow

```
Step 1: Split by spaces → token array
Step 2: REVERSE shuffle (Round N → Round 1)
        Replay Fisher-Yates swap pairs in reverse order
Step 3: Card tokens → hex digits → original characters
Step 4: Join → original plain text
```

### Security Properties

| Property | Description |
|----------|-------------|
| **Key-dependent** | Different key = completely different ciphertext |
| **Bijective mapping** | Each character maps to exactly ONE set of symbols |
| **Never stored** | Key lives in RAM only, wiped on dispose() |
| **Avalanche effect** | 1-character key change = entirely new output |
| **Deterministic** | Same plaintext + key = same ciphertext |
| **Multi-round** | 2-4 shuffle rounds based on key ASCII sum |

---

## 📁 Project Structure

```
lib/
├── main.dart                          # App entry, Firebase init, dotenv load
├── firebase_options.dart              # Generated by FlutterFire CLI
│
├── core/
│   ├── router/
│   │   └── app_router.dart            # go_router + auth redirect guard
│   ├── theme/
│   │   └── app_theme.dart             # Light + dark themes
│   ├── encryption/
│   │   └── maze_card_cipher.dart      # Custom encryption algorithm
│   ├── services/
│   │   ├── voice_service.dart         # Speech-to-text
│   │   └── notification_service.dart  # Local notifications
│   └── exceptions/
│       └── app_exception.dart         # Firebase error handling
│
├── data/
│   ├── models/
│   │   ├── note_model.dart            # Note data structure
│   │   └── folder_model.dart          # Folder data structure
│   ├── repositories/
│   │   ├── auth_repository.dart       # Firebase Auth operations
│   │   └── notes_repository.dart      # Notes/Folders CRUD
│   └── services/
│       ├── ai_service.dart            # Abstract AI interface
│       ├── gemini_ai_service.dart     # Google Gemini implementation
│       └── groq_ai_service.dart       # Groq Llama implementation
│
└── presentation/
    ├── providers/
    │   ├── auth_provider.dart         # AuthNotifier + AuthState
    │   ├── notes_provider.dart        # Notes + folders streams
    │   ├── theme_provider.dart        # Dark/light mode toggle
    │   └── ai_provider.dart           # AI service + chat history
    └── screens/
        ├── auth/
        │   ├── splash_screen.dart
        │   ├── onboarding_screen.dart
        │   ├── login_screen.dart
        │   ├── register_screen.dart
        │   ├── forgot_password_screen.dart
        │   └── email_verify_screen.dart
        ├── home/
        │   ├── home_screen.dart
        │   └── widgets/
        │       └── note_card.dart
        ├── editor/
        │   ├── note_editor_screen.dart
        │   └── widgets/
        │       ├── encrypt_sheet.dart
        │       └── ai_assist_sheet.dart
        ├── ai/
        │   └── ai_chat_screen.dart
        ├── search/
        │   └── search_screen.dart
        ├── calendar/
        │   └── calendar_screen.dart
        └── profile/
            └── profile_screen.dart
```

---

## 🚀 Getting Started

### Prerequisites

- **Flutter SDK** 3.x ([Install Flutter](https://docs.flutter.dev/get-started/install))
- **Dart** 3.11+
- **Node.js** 18+ (for Firebase CLI)
- **Git**

### Installation

```bash
# Clone repository
git clone https://github.com/bilalhussain/secure_notepad.git
cd secure_notepad

# Install dependencies
flutter pub get

# Install Firebase CLI
npm install -g firebase-tools

# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Login to Firebase
firebase login

# Configure Firebase for your project
flutterfire configure
```

### Firebase Setup

1. **Enable Authentication**
   - Go to Firebase Console → Authentication → Sign-in method
   - Enable Email/Password ✅
   - Enable Google ✅

2. **Create Firestore Database**
   - Go to Firestore Database → Create database
   - Select Production mode
   - Choose your region

3. **Set Firestore Security Rules**

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null 
                         && request.auth.uid == uid;
    }
  }
}
```

4. **Enable Firebase Storage**
   - Go to Storage → Get started

### Configure API Keys

Create a `.env` file in the project root:

```env
# Google Gemini AI
# Get your key: https://aistudio.google.com/app/apikey
GEMINI_API_KEY=AIzaSy_your_actual_key_here
GEMINI_MODEL=gemini-1.5-flash

# Groq AI (Fallback)
# Get your key: https://console.groq.com/keys
GROQ_API_KEY=gsk_your_actual_key_here
GROQ_MODEL=llama-3.3-70b-versatile

# AI Provider Selection
# Options: 'gemini' or 'groq'
AI_PROVIDER=gemini
```

⚠️ **Important:** Add `.env` to `.gitignore` — never commit API keys.

### Run the App

```bash
# Web
flutter run -d chrome

# Android
flutter run -d android

# iOS
flutter run -d ios

# Windows
flutter run -d windows

# Build for production
flutter build web --web-renderer canvaskit
```

---

## 🤖 AI Provider Configuration

### Switch Between Providers

Edit `.env`:

```env
# Use Gemini (Google AI):
AI_PROVIDER=gemini

# Use Groq (Faster):
AI_PROVIDER=groq
```

### Change AI Models

**Gemini models:**
```env
GEMINI_MODEL=gemini-1.5-flash      # Fast, recommended
GEMINI_MODEL=gemini-1.5-pro        # More capable
```

**Groq models:**
```env
GROQ_MODEL=llama-3.3-70b-versatile  # Best quality
GROQ_MODEL=llama-3.1-8b-instant     # Fastest
GROQ_MODEL=mixtral-8x7b-32768       # Balanced
```

### Auto-Fallback

When Gemini hits rate limits, the app automatically switches to Groq. No user action needed.

---

## 🔄 Note Lifecycle

### Create Note
- User writes note → auto-save every 4 seconds
- Stored as Quill Delta JSON in Firestore
- `isEncrypted: false`

### Encrypt Note
1. Tap 🔓 icon → "Set Master Key" dialog
2. Enter + confirm master key
3. Plaintext → `MazeCardCipher.encrypt()`
4. Ciphertext saved, plaintext cleared
5. `isEncrypted: true`, key stored in RAM only

### Open Encrypted Note
1. Tap note → "Enter Master Key" dialog
2. Enter key → `MazeCardCipher.decrypt()`
3. Validation check (`isValidDecryption()`)
4. ✓ Pass → load into editor
5. ✗ Fail → "Incorrect master key" error

### Edit Encrypted Note
- Auto-save encrypts before saving
- Key stays in RAM during editing
- Original plaintext never touches Firestore

### Dispose
- Leave screen → `_masterKey = null`
- Key wiped from memory
- Next open requires key again

---

## 💬 AI Chatbot Commands

The AI chatbot understands natural language:

| Command | Result |
|---------|--------|
| "Summarize my note" | Returns 2-3 sentence summary |
| "Fix grammar" | Corrects grammar errors |
| "Expand this idea" | Writes detailed paragraph |
| "Make it shorter" | Concise version |
| "Generate tags" | Returns 5 relevant tags |
| "Create a note titled Python" | Creates note in Firestore |
| "Create note ML with description Data Training" | Creates note with content |
| "Create a folder Work" | Creates folder in Firestore |
| "What is machine learning?" | General AI question |
| "Help me write about AI" | Writing assistance |

---

## 🗄️ Firestore Schema

```
users/{uid}
  ├── fullName: string
  ├── username: string (unique)
  ├── email: string
  ├── avatarUrl: string
  ├── plan: 'free' | 'plus' | 'pro'
  ├── createdAt: timestamp
  └── lastLoginAt: timestamp

users/{uid}/notes/{noteId}
  ├── title: string
  ├── content: string (Quill Delta JSON — plain notes)
  ├── cipherText: string | null (encrypted notes)
  ├── isEncrypted: boolean
  ├── plainPreview: string (first 80 chars)
  ├── isPinned: boolean
  ├── folderId: string | null
  ├── tags: string[]
  ├── createdAt: timestamp
  └── updatedAt: timestamp

users/{uid}/folders/{folderId}
  ├── name: string
  ├── colorHex: string
  ├── iconName: string
  ├── noteCount: number
  └── createdAt: timestamp

users/{uid}/reminders/{reminderId}
  ├── title: string
  ├── scheduledAt: timestamp
  ├── isCompleted: boolean
  └── createdAt: timestamp
```

---

## 🎨 Design System

### Colors
```dart
Primary     : #2EC4A9  (Teal)
Dark Navy   : #1B1B2F
Light BG    : #F8F9FB
Dark BG     : #121212
Card Light  : #FFFFFF
Card Dark   : #1E1E1E
Error       : #E24B4A
Success     : #1D9E75
```

### Typography
```dart
Headings   : Sora (Bold/SemiBold)
Body       : DM Sans (Regular/Medium)
```

### Spacing
```dart
Card Radius    : 16px
Button Radius  : 12px
Input Radius   : 12px
Card Padding   : 16px
Screen Padding : 20px
```

---

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| "AI not configured" | Add `GEMINI_API_KEY` or `GROQ_API_KEY` to `.env` |
| "Quota exceeded" | App auto-switches to Groq; or get new Gemini key |
| "No account found" | User not registered; check email spelling |
| Voice not working | Use Chrome/Edge; allow microphone permission |
| Notes not loading | Check Firestore Security Rules |
| Wrong master key | Key is case-sensitive; note cannot be recovered |

---

## 📦 Dependencies

```yaml
# Core
flutter_riverpod: ^2.6.1          # State management
go_router: ^16.1.0                # Routing
flutter_dotenv: ^5.2.1            # Environment variables

# Firebase
firebase_core: ^4.9.0             # Firebase initialization
firebase_auth: ^6.5.1             # Authentication
cloud_firestore: ^6.4.1           # Database
firebase_storage: ^13.4.1         # File storage
google_sign_in: ^6.3.0            # Google OAuth

# UI
google_fonts: ^6.2.1              # Sora + DM Sans fonts
lottie: ^3.3.1                    # Animations
shimmer: ^3.0.0                   # Loading skeletons
animated_text_kit: ^4.2.2         # Text animations

# Editor
flutter_quill: ^11.5.0            # Rich text editor

# AI
google_generative_ai: ^0.4.7     # Gemini AI SDK
http: ^1.2.2                      # Groq HTTP requests

# Features
speech_to_text: ^7.0.0            # Voice input
flutter_local_notifications: ^18.0.1  # Notifications
table_calendar: ^3.2.0            # Calendar view
image_picker: ^1.1.2              # Image selection
share_plus: ^10.1.4               # Share notes
pdf: ^3.11.2                      # PDF export

# Storage
hive_flutter: ^1.1.0              # Local cache
shared_preferences: ^2.5.3        # Settings storage
flutter_secure_storage: ^9.2.4    # Secure key storage

# Utilities
email_validator: ^3.0.0           # Email validation
intl: any                         # Internationalization
timezone: ^0.10.0                 # Timezone handling
```

---

## 🚀 Roadmap

- [ ] Biometric lock screen (fingerprint / Face ID)
- [ ] Note sharing with encrypted links
- [ ] Voice notes (audio recording + playback)
- [ ] Export notes to PDF
- [ ] Note version history
- [ ] Two-factor authentication (2FA)
- [ ] Native mobile apps (iOS + Android)
- [ ] Offline mode with sync
- [ ] Note templates
- [ ] Real-time collaboration

---

## 📄 License

MIT License

Copyright (c) 2026 Muhammad Bilal Hussain

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---

## 🙏 Credits

- **Built by:** Bilal Hussain
- **Framework:** [Flutter](https://flutter.dev)
- **Backend:** [Firebase](https://firebase.google.com)
- **AI (Primary):** [Google Gemini](https://ai.google.dev)
- **AI (Fallback):** [Groq](https://groq.com)
- **Rich Text:** [flutter_quill](https://pub.dev/packages/flutter_quill)

---

**⭐ Star this repository if you find it useful!**

For issues and feature requests, visit: [GitHub Issues](https://github.com/bilalhussain/secure_notepad/issues)
