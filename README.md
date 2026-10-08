# Jieshuo+ (Commentary Screen Reader) Plugins & Tools Collection

If you use **Jieshuo+ (Commentary Screen Reader / Talkman)** on Android, you already know how powerful its Lua scripting engine is. With the right plugins and tools, you can turn single swipe gestures into an AI screen reader assistant, type effortlessly in multiple languages using your voice, read clutter-free news, or download media without fighting inaccessible web pages.

This repository brings together **12 practical Jieshuo Plugins** and **5 standalone Jieshuo Tools (Mini-Apps)** built specifically for blind and visually impaired Android users. Every script in this collection was designed to solve real everyday frustrations—like unreadable CAPTCHAs, stylish Unicode fonts that screen readers can't pronounce, mixed-language voice typing, and ad-heavy news or story websites.

---

## Why This Collection Exists

- **Instant AI Vision & Captcha Solving:** Standard OCR often struggles with distorted verification codes or complex layouts. The included **Gemini AI OCR** plugin reads screen text accurately, solves tricky CAPTCHAs in seconds, describes images, and even translates extracted text on the fly.
- **Natural Voice Typing & Translation (Nepali, Hindi, English & More):** Whether you want to speak in Nepali and have it type in English, transliterate Nepali speech into Roman script (`namaste`), or dictate natural bilingual messages where Nepali stays in Devanagari and English words stay in Latin script, there is a dedicated voice tool for it.
- **Accessible Daily Apps Inside Jieshuo:** No need to install bloated, ad-filled Android apps just to check the news, listen to FM radio, check Nepal market rates, read Hindi stories, or download a video. The **Tools** folder gives you clean, fast, screen-reader-friendly mini-apps that run natively inside Jieshuo.
- **Clean Up Unreadable Text:** Social media posts full of "fancy" mathematical Unicode fonts usually sound like gibberish or silence on TTS engines. A single gesture with the **Fancy Text Cleaner** turns them back into plain, spoken text.

---

## What's Inside

### 1. Jieshuo Plugins (`Plugins/`)

Plugins are lightweight extensions meant to be bound to a Jieshuo gesture, edge swipe, or quick menu so you can trigger them on any screen or inside any text box.

#### AI Vision, OCR & Audio Transcription
- **[`ocr`](Plugins/ocr/) — Gemini AI OCR, Scene Describer & Captcha Solver (v1.4)**  
  Captures your screen or focused item and uses Google Gemini (`gemini-2.5-flash` up to `gemini-3.8-flash`) to extract text, solve distorted CAPTCHAs, or describe images in detail. Includes built-in translation of extracted text, a 20-item history log, token usage tracking, and customizable launch modes (*Show Menu*, *Direct OCR*, or *Direct Captcha*).
- **[`voice transcribe`](Plugins/voice%20transcribe/) — Multi-Provider AI Voice Transcriber**  
  Records audio through an accessible floating overlay and transcribes your speech verbatim with natural punctuation and smart emoji placement. Built to handle bilingual code-switching (for example, keeping Nepali words in Devanagari while writing spoken English words in Latin letters instead of phonetic Devanagari). Supports **Google Gemini**, **OpenAI Whisper**, and **Groq**.
- **[`translator`](Plugins/translator/) — Long-Text AI Translator to Nepali**  
  Grabs the text from the currently focused screen element, splits long articles into sentence-aware chunks without breaking punctuation, translates everything into natural Devanagari Nepali using Gemini AI, and presents the result in a clean, selectable dialog.

#### Voice Typing & Live Speech Translation
- **[`multi voice typing`](Plugins/multi%20voice%20typing/) — 10-Language Voice Typing**  
  Opens a quick language grid (*Arabic, Bengali, Chinese, French, English, Hindi, Nepali, Portuguese, Russian, Spanish*) and types your speech with automatic capitalization, custom word replacements, and smart punctuation.
- **[`Nepali to English Voice Typing`](Plugins/Nepali%20to%20English%20Voice%20Typing/) — Speak Nepali, Type in English (No API Key Needed)**  
  Listens to you in Nepali (`ne-np`), translates your words into English via Google Translate, speaks the translation aloud for confirmation, and inserts it directly into your active edit box.
- **[`nep to eng using gemini`](Plugins/nep%20to%20eng%20using%20gemini/) — Speak Nepali, Type in English (Powered by Gemini)**  
  Uses Android speech recognition for Nepali and translates your speech into fluent, context-aware English using `gemini-2.5-flash` before inserting it into the focused text field.
- **[`nep to english`](Plugins/nep%20to%20english/) — Nepali to English Voice Translator**  
  Compiled Jieshuo voice translation plugin using an external `api.json` file for easy Gemini API key configuration.
- **[`nepali rroman typing`](Plugins/nepali%20rroman%20typing/) — Nepali Speech to Roman Nepali (`namaste`)**  
  Perfect for chatting when you want to speak in Nepali but type in Romanized Latin letters. Automatically transliterates Devanagari speech into Roman script, capitalizes popular brand names (*Google, WhatsApp, YouTube, Jieshuo*), and supports voice commands.
- **[`Nepali to Hindi Voice typing`](Plugins/Nepali%20to%20Hindi%20Voice%20typing/) — Speak Nepali, Type in Hindi**  
  Recognizes spoken Nepali and automatically translates and types it in Hindi Devanagari script.
- **[`nepali typing`](Plugins/nepali%20typing/) — Dedicated Nepali Voice Typing**  
  Fast, accurate Nepali Devanagari voice input plugin for Jieshuo.

#### Everyday Accessibility Utilities
- **[`fancy`](Plugins/fancy/) — Stylish & Fancy Unicode Text Cleaner**  
  Normalizes decorative/mathematical Unicode characters on the focused item into standard ASCII text, speaks it immediately using your Jieshuo voice, and copies the clean text to your clipboard.
- **[`drishti`](Plugins/drishti/) — Drishti AI Quick Launcher**  
  A one-line helper plugin that launches the **Drishti AI** Android application with a single gesture.

---

### 2. Standalone Jieshuo Tools (`Tools/`)

Tools are full interactive Android mini-apps written in AndroLua+ that run directly inside Jieshuo+.

#### **[PocketNews](Tools/PocketNews/) (v2.3.0) — News, Live FM Radio, Nepal Markets, Patro & AI Hub**
An all-in-one daily information app built from the ground up for screen reader navigation:
- **Clutter-Free News Reader:** Browse multi-language RSS news feeds by category with paragraph-by-paragraph or full-article reading modes, reading time estimates, duplicate/garbage text filtering, bookmarks, offline reading, and a searchable 28-day reading history.
- **Live FM Radio Player:** Stream live radio stations with alphabetical sorting, custom station management, background playback controls, and a built-in sleep timer.
- **Nepal Markets & Utilities:** Check live Gold & Silver prices, NRB foreign exchange rates (with a 20-currency converter), NEPSE stock index updates, NOC fuel prices, and Kalimati vegetable & fruit rates.
- **Nepali Patro:** View the current Nepali date, Tithi, daily Rashifal, and upcoming events.
- **Built-in Translation & Gemini AI:** Translate articles into 10 languages using Google Translate (no API key required), summarize long news stories with Gemini AI, or chat with the built-in AI Companion. Includes a complete offline HTML manual ([`user_guide.html`](Tools/PocketNews/user_guide.html)).

#### **[DRISHTI Universal Media Downloader](Tools/DRISHTI%20Universal%20Media%20Downloader/) — Accessible Video & Audio Downloader**
- Paste any supported social media or video link to fetch available video and audio download streams via the DRISHTI Downloader API (`downloader.sushil0.com.np`).
- Clearly announces stream quality, file format (`mp4`, `mp3`, etc.), and file size for screen readers.
- Tracks live download progress through Android's `DownloadManager` and keeps a local download history. Comes pre-configured with a trial key and lets you save your own DRISHTI API key in Settings.

#### **[Hindi Kahaniya](Tools/hindi%20kahaniya/) (v6.0) — Accessible Hindi Story Reader**
- Brings together **31 story categories** across **6 popular Hindi story websites** (*KahaniZone, HindiMoralStory, KahaniHindiMe, DaaniTV, BhootKiKahani,* and *HorrorStoryHindi*)—covering moral stories, Akbar-Birbal, Tenali Rama, motivational tales, and horror stories.
- Features an accessible navigation drawer, Day/Night reading modes, instant keyword search, story bookmarks, adjustable font sizes, and local caching so stories load fast without web ads.

#### **[Enhanced Player](Tools/enhanced_player/) — Accessible Media & Subtitle Player**
- A multi-module media player (`main.lua`, `browse.lua`, `player.lua`, `subtitle.lua`, `utils.lua`) featuring a built-in folder browser, screen-reader-friendly playback controls, and external subtitle reading support.

#### **[Markdown Reader](Tools/md%20reader/) — Clean `.md` File Viewer**
- Opens any `.md` documentation or note file from `/sdcard/`, converts Markdown formatting (headings, bold/italic text, code blocks, lists, links, and images) into clean HTML, and displays it in a zoomable WebView.

---

## How to Install on Your Android Phone

1. **Download this repository:** Clone the repo or download the ZIP file and extract it on your phone or computer.
2. **Copy Plugins:** Move the folders inside **`Plugins/`** into your Jieshuo plugins folder on your Android device:
   ```text
   /sdcard/Jieshuo/Plugins/
   ```
3. **Copy Tools:** Move the folders inside **`Tools/`** into your Jieshuo tools (or extensions) folder:
   ```text
   /sdcard/Jieshuo/Tools/
   ```
4. **Set Up Your API Key (Optional, for AI Features):**
   - You can get a free Google Gemini API key from [Google AI Studio](https://aistudio.google.com/app/apikey).
   - **OCR, Voice Transcribe & PocketNews:** Open the plugin/tool and paste your API key directly into its built-in **Settings** screen.
   - **Translator & Nep to Eng using Gemini:** Open `main.lua` in any text editor and paste your key inside `local GEMINI_API_KEY = ""`.
   - **Nep to English:** Paste your Gemini API key into `Plugins/nep to english/api.json`.

---

## Keywords & Topics

`jieshuo` · `jieshuo-plus` · `commentary-screen-reader` · `talkman` · `android-accessibility` · `screen-reader` · `blind-accessibility` · `visually-impaired` · `androlua` · `lua-scripts` · `gemini-ocr` · `captcha-solver` · `voice-typing` · `nepali-voice-typing` · `hindi-kahaniya` · `accessible-news-reader`

---

## Author & Community

- **Author:** Sushil Chaudhary
- **Website:** [sushil0.com.np](https://sushil0.com.np)
- **License:** GNU General Public License v2.0 — see [LICENSE](LICENSE) for details.

If you find these plugins or tools helpful, feel free to star the repository, share it with other Jieshuo+ users, or open an issue/pull request with improvements!
