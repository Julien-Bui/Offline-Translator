from fastapi import FastAPI, Depends, HTTPException, BackgroundTasks
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel
import os
from fastapi.security import APIKeyHeader

from .database import engine, get_db, Base
from . import models

Base.metadata.create_all(bind=engine)
app = FastAPI(title="Offline Translator Cloud Hub", version="1.0")

api_key_header = APIKeyHeader(name="X-API-Key", auto_error=False)

def get_api_key(api_key: str = Depends(api_key_header)):
    # Mot de passe par défaut pour sécuriser l'API publique
    admin_key = os.getenv("ADMIN_API_KEY", "offline-translator-admin-123")
    if api_key == admin_key:
        return api_key
    raise HTTPException(status_code=403, detail="Clé API administrateur invalide ou manquante")

class LanguageItem(BaseModel):
    name: str
    bcp47_code: str

@app.get("/")
def read_root():
    return {"message": "Cloud Hub du Traducteur Offline (API Catalogue)"}

@app.get("/catalog")
def get_language_catalog(db: Session = Depends(get_db)):
    languages = db.query(models.LanguageCatalog).all()
    
    # Si la base est vide (premier lancement), on retourne quelques langues par défaut.
    # Dans un vrai scénario, on remplirait la BDD.
    if not languages:
        return {
            "status": "success",
            "catalog": [
                {"name": "Anglais", "bcp47_code": "en"},
                {"name": "Français", "bcp47_code": "fr"},
                {"name": "Espagnol", "bcp47_code": "es"},
                {"name": "Allemand", "bcp47_code": "de"},
                {"name": "Italien", "bcp47_code": "it"},
                {"name": "Portugais", "bcp47_code": "pt"},
                {"name": "Japonais", "bcp47_code": "ja"},
                {"name": "Coréen", "bcp47_code": "ko"},
                {"name": "Chinois", "bcp47_code": "zh"}
            ]
        }
    
    return {
        "status": "success",
        "catalog": [{"name": lang.name, "bcp47_code": lang.bcp47_code} for lang in languages]
    }

@app.post("/catalog")
def add_language(lang: LanguageItem, db: Session = Depends(get_db), api_key: str = Depends(get_api_key)):
    # Vérifier si la langue existe déjà
    existing = db.query(models.LanguageCatalog).filter(models.LanguageCatalog.bcp47_code == lang.bcp47_code).first()
    if existing:
        raise HTTPException(status_code=400, detail="Cette langue existe déjà dans le catalogue.")
    
    # Ajouter à la BDD
    new_lang = models.LanguageCatalog(name=lang.name, bcp47_code=lang.bcp47_code)
    db.add(new_lang)
    db.commit()
    
    return {"status": "success", "message": f"La langue '{lang.name}' a été ajoutée avec succès au catalogue !"}
