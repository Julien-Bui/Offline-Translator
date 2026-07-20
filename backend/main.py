from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
import os

from .database import engine, get_db, Base
from . import models

Base.metadata.create_all(bind=engine)
app = FastAPI(title="Offline Translator Cloud Hub", version="1.0")

class TranslationItem(BaseModel):
    source_lang: str
    target_lang: str
    original_text: str
    translated_text: str
    timestamp: str

class SyncRequest(BaseModel):
    user_id: str
    translations: List[TranslationItem]

@app.get("/")
def read_root():
    return {"message": "Cloud Hub du Traducteur Offline (API)"}

@app.get("/models/latest")
def get_latest_models(db: Session = Depends(get_db)):
    return {
        "status": "success",
        "models": [
            {"pair": "fr-en", "version": "1.0", "size_mb": 85, "download_url": "/models/download/fr-en"},
            {"pair": "en-zh", "version": "1.0", "size_mb": 90, "download_url": "/models/download/en-zh"}
        ]
    }

@app.get("/models/download/{pair}")
def download_model(pair: str):
    return {"status": "redirect", "url": f"https://cdn.tondomaine.com/models/onnx_{pair}_quantized.zip"}

@app.post("/sync")
def sync_translations(sync_data: SyncRequest, db: Session = Depends(get_db)):
    saved_count = 0
    for item in sync_data.translations:
        db_item = models.TranslationHistory(
            user_id=sync_data.user_id,
            source_lang=item.source_lang,
            target_lang=item.target_lang,
            original_text=item.original_text,
            translated_text=item.translated_text
        )
        db.add(db_item)
        saved_count += 1
    
    db.commit()
    return {"status": "success", "synced_items": saved_count}
