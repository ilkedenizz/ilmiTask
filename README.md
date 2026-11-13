<div align="center">

# 🦊 ilmi Task

**System-Grade Contextual Reminder & Task Engine**  
*Engineered with a bespoke Linear / Things 3 / Nothing OS dark aesthetic.*

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white)](#)
[![SQLite](https://img.shields.io/badge/SQLite-Relational_Engine-003B57?style=flat-square&logo=sqlite&logoColor=white)](#)
[![Architecture](https://img.shields.io/badge/UI_System-Obsidian_%26_Amber-FF5500?style=flat-square)](#)
[![Tests](https://img.shields.io/badge/Tests-Passing_100%25-10B981?style=flat-square)](#)
[![Studio](https://img.shields.io/badge/Crafted_by-Racc_Lab-090A0C?style=flat-square)](#)

</div>

---

## ⚡ Overview

**ilmi Task** is a high-precision, local-first contextual reminder and task management application built with Flutter. Inspired by the deep OS-level capabilities of **Samsung Reminder** and the editorial dark-mode ergonomics of **Linear**, **Things 3**, and **Nothing OS**, it moves beyond basic to-do lists by combining **multi-tier alarm channels**, **full-screen lock-screen wake triggers**, **geofencing (location-based triggers)**, and **interactive in-alarm checklists**.

---

## ✨ Key Architectural Features

### 🚨 1. 3-Tier Notification & Full-Screen Alarm Engine
Unlike standard task apps whose notifications get buried in the shade, **ilmi Task** implements three distinct Android Notification Channels paired with a dual-scheduling engine:
* **Light (`light_channel`):** Silent, zero-vibration delivery for non-intrusive notes.
* **Short (`short_channel`):** Standard system alert with default acoustic feedback.
* **Strong / Full-Screen (`strong_fullscreen_channel`):** High-priority insistent alarm that wakes the screen over the lock screen (`USE_FULL_SCREEN_INTENT`) and launches a dedicated **Editorial Alarm Ringing Screen**.
* **Early Pre-Alerts:** Dual-trigger scheduling (`-15m`, `-30m`, `-1h`, `-1d`) that notifies you ahead of the main deadline without prematurely triggering the full-screen dismissal flow.

### 📍 2. Contextual Geofencing & Dark-Mode Map Picker
* **Arrival & Departure Triggers:** Trigger reminders automatically when entering (`ARRIVE`) or leaving (`LEAVE`) a target radius (`100m`, `250m`, `500m`).
* **Zero-API-Key Map Integration:** Built-in dark-themed interactive **OpenStreetMap** (`flutter_map`) coordinate picker with translucent `#FF5500` radius visualization.
* **Deterministic Evaluation Engine:** Real-time distance calculation via `GeofenceMonitorService` with state-transition tracking (`outside -> inside` and `inside -> outside`).

### ☑️ 3. Interactive Subtasks & Smart Payload Extraction
* **In-Card & In-Alarm Checklists:** Tick off subtasks directly from the Home Screen cards or live on the **Full-Screen Alarm Screen** while the alarm is ringing—persisted instantaneously to SQLite with `ON DELETE CASCADE`.
* **Smart URL Extractor:** Automatically detects `http://` and `https://` links inside task notes and renders a monospace `[ ↗ OPEN LINK ]` action chip on the card.
* **Visual Attachments:** Attach photos from camera or gallery directly to tasks.

### 🛡️ 4. System Reliability & Battery Optimization Shield
* Built-in diagnostic engine (`SystemShieldBanner` & `SystemShieldDialog`) monitoring:
  * `Permission.notification`
  * `Permission.scheduleExactAlarm`
  * `Permission.ignoreBatteryOptimizations`
  * `Permission.location` / `locationAlways`
* Includes a one-tap **Android Doze Mode Exemption** action and an interactive **"Test Alarm Screen"** preview utility.

---

## 🎨 Design System (`AppColors`)

**ilmi Task** strictly rejects generic Material templates, heavy drop shadows, and saturated gradients in favor of `1px` hairline borders, matte carbon surfaces, and precision `monospace` metadata readouts:

| Token Role | Hex Code | Visual Spec |
| :--- | :--- | :--- |
| **Canvas Background** | `#090A0C` | Deep Matte Obsidian (`0dp` elevation) |
| **Elevated Card Surface** | `#121418` | Subtle Charcoal with `1px` border (`#22252C`) |
| **Bento Settings Container** | `#16191E` | Grouped architectural blocks with `1px` dividers |
| **Indented Subtask Box** | `#0D0F12` | Recessed container for checklist items |
| **Interactive Pill / Chip** | `#181B20` | Low-profile surface with `#2A2E37` border |
| **Primary Accent** | `#FF5500` | International Orange / Warm Amber |
| **Primary Typography** | `#F3F4F6` | Crisp Off-White (`letterSpacing: -0.6`) |
| **Metadata & Readouts** | `monospace` | Used for timestamps, countdowns, `PINNED (n)`, and live clock |

---

## 🧠 Notification & Routing Flow

```mermaid
flowchart TD
    A[Notification Triggered / Tapped] --> B{Payload Type}
    B -->|early_reminder_id| C[Early Pre-Alert]
    C --> D[Route to HomeScreen & Open Bento Editor Sheet]
    B -->|reminder_id| E[Main Reminder Trigger]
    E --> F[Fetch Fresh State from SQLite]
    F --> G{alert_severity == strong_fullscreen?}
    G -->|Yes| H[Launch Editorial AlarmRingingScreen]
    G -->|No: light / short| D
    H --> I[Interactive Checklist / Snooze +10m / Dismiss]
