from sqlalchemy import Column, Integer, String, DateTime, JSON
from .database import Base
from datetime import datetime

class TranslationHistory(Base):
    __tablename__ = "translation_history"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(String, index=True, nullable=False)
    source_lang = Column(String, nullable=False)
    target_lang = Column(String, nullable=False)
    original_text = Column(String, nullable=False)
    translated_text = Column(String, nullable=False)
    timestamp = Column(DateTime, default=datetime.utcnow)
    
class AppModel(Base):
    __tablename__ = "app_models"
    
    id = Column(Integer, primary_key=True, index=True)
    language_pair = Column(String, unique=True, index=True, nullable=False)
    version = Column(String, nullable=False)
    download_url = Column(String, nullable=False)
    size_mb = Column(Integer, nullable=False)
