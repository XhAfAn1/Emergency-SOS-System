# 🚨 ResQMob – Emergency SOS System  

ResQMob is an **emergency-based community safety mobile application** built with **Flutter, Firebase**.  
It enables users to send **instant SOS alerts**, connect with **police stations & responders**, share **real-time locations**, and build a **safety-focused community network** with posts, comments, and feedback.  
- [SRS Document](https://docs.google.com/document/d/19gcjcngLF-31X7Z2wkDsr3Re4yf7YYc27nmb0AaIvEs/edit?tab=t.p4mijk2jvot7)
- [Project Report](https://github.com/XhAfAn1/Emergency-SOS-System/blob/main/Screens%20Shoots/3_Dynasty_CSE412_Project_Report.pdf)
- [Andriod APK](https://drive.google.com/file/d/1fnq0BGZKBxWqfSsO3KjveKUWq2vRWXJh/view?usp=drive_link)
- [Presentation](https://www.canva.com/design/DAGxpEFeNBA/Dcrxr5cupcmU4ZW493b6Cg/view?utm_content=DAGxpEFeNBA&utm_campaign=designshare&utm_medium=link2&utm_source=uniquelinks&utlId=h77dd304365)

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-orange?logo=firebase)](https://firebase.google.com)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows-success)]()
[![License](https://img.shields.io/badge/License-Unspecified-lightgrey)]()

---

## 📖 Table of Contents
- [Introduction](#introduction)
- [Features](#features)
- [Technology Stack](#technology-stack)
- [System Architecture](#system-architecture)
- [Database Design](#database-design)
- [Modules](#modules)
- [Screenshots & Demo](#screenshots--demo)
- [Setup & Installation](#setup--installation)
- [Usage](#usage)
- [Future Scope](#future-scope)
- [Contributors](#contributors)
- [License](#license)

---

## 📝 Introduction
Emergencies can strike anytime, and **response time matters**.  
ResQMob was designed to **reduce delays**, provide **real-time danger prediction**, and build a **community-driven safety ecosystem**.  

Unlike traditional SOS apps, ResQMob not only sends alerts but also:  
- Predicts risky situations using **ML & geofencing**  
- Connects users with **police stations & verified responders**  
- Provides a **community feed** for safety discussions  
- Collects **feedback** for system improvement  

---

## ✨ Features

### 👤 User Management
- Register/Login via Supabase Auth  
- Manage profile and **Emergency Contacts**  
- Real-time location updates  

### 🚨 Emergency Alerts
- One-tap **SOS alert button**
- Power and Volume button **shortcut trigger**
- Share location with contacts, responders, and nearest **Police Station**  
- Status tracking: *active, resolved*  
- Responder assignment & notification  

### 🧑‍🤝‍🧑 Community Feed
- Post safety updates or warnings  
- Comment, reply, and upvote system  
- Nested discussions for better context  

### 🧠 ML Danger Prediction
- Predicts high-risk zones using historical data  
- Integrates with **Map Zones (safe/danger areas)**  
- Triggers alerts automatically in geofenced danger zones  

### 🗺️ Map & Geofencing
- Real-time maps integration  
- Location pins for **users, responders, and police stations**  
- Safe/Danger area visualization  

### ⭐ Feedback System
- Users can rate emergency handling  
- Leave comments on incidents & responders  
- Helps improve community trust  

---

## 🛠 Technology Stack

| Layer              | Technology |
|--------------------|------------|
| **Language**       | Dart (Flutter) |
| **Frontend**       | Flutter (Cross-platform UI) |
| **Backend**        | Firebase Cloud Functions (Node.js/TypeScript) |
| **Databases**      | Firebase Firestore (NoSQL) |
| **Authentication** | Firebase Auth |
| **Storage**        | Firebase  |
| **Notifications**  | Firebase Cloud Messaging (FCM) |
| **APIs**           | HTTP (Amar Sheba SMS API, Google Maps API) |

---

## 🏗 System Architecture
                ┌─────────────────────────┐
                │     User App (Flutter)  │
                │ ─────────────────────── │
                │ - SOS Button            │
                │ - Community Feed        │
                │ - Maps & Geofencing     │
                │ - User Profile          │
                │ - Feedback              │
                └──────────┬──────────────┘
                           │
                           │ REST / gRPC / WebSockets
                           ▼
        ┌───────────────────────────────────────────────────────────┐
        │  Backend (Firebase Functions + Supabase Edge Functions)   │
        │                                                           │
        │ ───────────────────────────────────────────────────────── │
        │ - SOS Alert Handler                                       │
        │ - User/Auth Management (Firebase)                         │
        │ - Post/Comment Services                                   │
        │ - Notification Service (FCM)                              │
        │ - SMS Gateway Integration (Amar Sheba API)                │
        │ - ML Danger Prediction Service                            │
        │ - Feedback Processor                                      │
        └──────────┬────────────────────────┬─────────────────────┬─┘
                   │                        │                     │
                   ▼                        ▼                     ▼
        ┌──────────────────────┐  ┌──────────────────────┐ ┌──────────────────────┐
        │ Firestore (NoSQL)    │  │ Supabase (Postgres)  │ │ External APIs        │
        │ - Alerts             │  │ - User Profiles      │ │ - SMS (Amar Sheba)   │
        │ - Posts              │  │ - Auth & Sessions    │ │ - Google Maps API    │
        │ - Comments           │  │ - Feedback           │ │ - Geo/ML models      │
        └──────────────────────┘  └──────────────────────┘ └──────────────────────┘
                   │                           │
                   ▼                           ▼
        ┌───────────────────┐        ┌─────────────────────┐
        │ Police Stations   │        │ Emergency Contacts  │
        │ Responders (DB)   │        │ (from user profile) │
        └───────────────────┘        └─────────────────────┘


## 📁 Project Structure

```plaintext
.
├── android/              # Android-specific configuration & build files
├── ios/ (if present)     # iOS-specific files
├── web/                  # Web deployment configuration
├── windows/              # Windows desktop support files
├── lib/                  # Main Flutter application code
│   ├── main.dart         # Entry point
│   ├── screens/          # App screens (Home, SOS, Settings, etc.)
│   ├── services/         # Firebase, location, SOS service handlers
│   ├── models/           # Data models
│   └── widgets/          # Reusable UI components
├── assets/               # Images, fonts, and other static assets
├── .firebase/            # Firebase-related local config
├── firebase.json         # Firebase hosting & project settings
├── apphosting.yaml       # Hosting config for Firebase
├── pubspec.yaml          # Flutter dependencies and metadata
├── pubspec.lock          # Locked dependency versions
├── analysis_options.yaml # Code analysis rules
├── test/                 # Unit and widget tests
└── README.md             # Project documentation


---

## 🗄 Database Design

Main collections & relations:
- **Users** → Has many Emergency Contacts, Posts, Alerts  
- **Posts** → Has many Comments  
- **Alerts** → Linked to Users & Police Stations  
- **ML Predictions** → Generated for Alerts/Users  
- **Feedback** → Submitted for Alerts & Responders  
- **Map Zones** → Define safe/danger geofences  

(See `docs/ERD.md` for full entity-relationship diagram)

---

## 📦 Modules

- `user.dart` → User model + emergency contacts  
- `social_model.dart` → Posts & comments for community feed  
- `alert.dart` → Alerts (SOS, severity, responders)  
- `pstation.dart` → Police station data  
- `sms.dart` → Utility for sending SOS via SMS  
- `ml_module` → ML danger prediction logic  
- `map_zones` → Geofencing safe/danger areas  
- `feedback` → Ratings & user reports  

---

## 📸 Screenshots & Demo

![](https://github.com/XhAfAn1/Emergency-SOS-System/blob/main/screenshots/a4vmo8.gif)


- **Home Screen** – Quick access to SOS  
- **Emergency Alert Screen** – Send & track alerts  
- **Community Feed** – Posts & comments  
- **Map View** – Safe/Danger zones  
- **Feedback Form** – Rate and review responses  


---

## ⚙️ Setup & Installation

1. Clone the repository  
   ```bash
   git clone https://github.com/XhAfAn1/Emergency-SOS-System.git
   cd Emergency-SOS-System

