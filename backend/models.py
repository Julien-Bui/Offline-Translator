from sqlalchemy import Column, Integer, String
from .database import Base

class LanguageCatalog(Base):
    __tablename__ = "language_catalog"
    
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, index=True, nullable=False) # e.g. "Français", "Anglais"
    bcp47_code = Column(String, unique=True, nullable=False) # e.g. "fr_FR", "en_US" (or ML Kit specific)

