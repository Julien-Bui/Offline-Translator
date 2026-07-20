# 🌍 Offline-Translator: Embedded AI (Offline-First)

A universal translator designed for extreme environments (no network, airplane mode). This project demonstrates my ability to design an **"Edge AI"** architecture by running complex machine learning models (NLP) directly on mobile processors in a highly optimized way.

This project is a 100% custom-built "Google Translate Offline" alternative.

---

## 🚀 Key Features
- **Ultra-Fast Local Inference (<30ms)**: Leveraging optimized on-device translation models (Google ML Kit).
- **Offline-First Architecture**: Guaranteed translation without Wi-Fi or Cellular data. The translation history is securely stored on the device via **SQLite**.
- **Smart Cloud Synchronization**: As soon as the network is available, you can synchronize your local data with a **FastAPI / PostgreSQL** server (hosted on Railway).
- **Optimized Resource Consumption**: Designed to preserve RAM and battery life, with lightweight language models (around 30 MB per language pack).
- **Explicit User Consent**: Language models are never downloaded silently. Users must explicitly grant permission before any data-intensive background download.

---

## 🏗️ Project Architecture

The architecture is divided into two main components:
1. **Cloud Hub (Railway)**: Sync API and remote database.
2. **Mobile App (Flutter)**: User interface and local execution using on-device ML Kit models.

```mermaid
graph TD
    subgraph "1. Cloud Hub (Railway)"
        API[FastAPI Python API]
        API <-->|Sync History| PG[(PostgreSQL\nRailway)]
    end

    subgraph "2. Mobile App (Flutter / Android)"
        UI[Flutter Interface]
        UI -.->|1. Download Language Pack| FS[Internal Storage]
        FS --> Moteur[On-Device Translator\nML Kit]
        
        UI -->|Text (Offline)| Moteur
        Moteur -->|Local Translation| UI
        
        UI -->|Save History| SQL[(Offline-First\nSQLite)]
        SQL -.->|2. Manual Sync (Network available)| API
    end
```

---

## 🛠️ Technology Stack
- **AI & NLP**: Google ML Kit Translation (On-Device Inference)
- **Cloud Backend**: Python 3.10, FastAPI, SQLAlchemy, PostgreSQL, Docker (Deployed on Railway)
- **Mobile Application**: Flutter / Dart, `sqflite` (Local database), `google_mlkit_translation`
