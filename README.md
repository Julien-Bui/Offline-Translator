# 🌍 Offline-Translator : L'IA Embarquée (Offline-First)

Un traducteur universel pensé pour les environnements extrêmes (pas de réseau, mode avion). Ce projet démontre ma capacité à concevoir une architecture **"Edge AI"**, en faisant tourner des réseaux de neurones complexes (NLP) directement sur des processeurs mobiles de manière très optimisée (ONNX INT8).

Ce projet est un "Google Translate Offline" 100% fait-main.

---

## 🚀 Fonctionnalités Clés
- **Inférence Locale Ultra-Rapide (<30ms)** : Grâce à l'optimisation des modèles HuggingFace (MarianMT) au format ONNX avec quantisation INT8.
- **Architecture Offline-First** : Traduction garantie sans Wi-Fi ni 4G. L'historique et le glossaire sont stockés sur le téléphone via **SQLite**.
- **Synchronisation Cloud Intelligente** : Dès que le réseau revient, un *background worker* synchronise les données sur un serveur **FastAPI / PostgreSQL** (hébergé sur Railway).
- **Consommation Optimisée** : Pensé pour préserver la RAM et la batterie du téléphone, le modèle pèse moins de 100 Mo.

---

## 🏗️ Architecture du Projet

L'architecture est scindée en 3 grandes parties :
1. **Pipeline IA** : Conversion et compression des modèles.
2. **Cloud Hub (Railway)** : API de gestion des modèles et synchronisation.
3. **App Mobile (Flutter)** : Interface utilisateur et exécution locale (ONNX Runtime Mobile).

```mermaid
graph TD
    subgraph "1. IA (HuggingFace -> ONNX)"
        HF[Modèle HuggingFace\nopus-mt-fr-en] -->|Optimum CLI| ONNX[Format ONNX\nINT8 Quantization]
        ONNX -->|Poids: ~80 Mo| S3[(Stockage Cloud)]
    end

    subgraph "2. Cloud Hub (Railway)"
        S3 -->|Téléchargement Modèles| API[API FastAPI\nPython]
        API <-->|Sync Historique| PG[(PostgreSQL\nRailway)]
    end

    subgraph "3. App Mobile (Flutter / Android)"
        API -.->|1. Téléchargement pack de langue (Wi-Fi)| FS[Stockage Interne]
        FS --> Moteur[ONNX Runtime Mobile]
        
        UI[Interface Flutter] -->|Texte (Offline)| Moteur
        Moteur -->|Traduction Locale| UI
        
        UI -->|Sauvegarde Historique| SQL[(SQLite Local\nOffline-First)]
        SQL -.->|2. Sync Background (Réseau dispo)| API
    end
```

---

## 🛠️ Stack Technologique
- **IA & NLP** : `transformers`, `optimum`, `onnxruntime`
- **Backend Cloud** : Python 3.10, FastAPI, SQLAlchemy, PostgreSQL, Docker (Déployé sur Railway)
- **Application Mobile** : Flutter / Dart, `sqflite` (Base de données locale), `onnxruntime_flutter`
