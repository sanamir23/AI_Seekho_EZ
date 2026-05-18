from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    supabase_url: str
    supabase_anon_key: str
    supabase_service_key: str
    supabase_db_url: str

    gemini_api_key: str
    gemini_model: str = "gemini-2.0-flash"

    google_places_api_key: str
    seed_city: str = "Islamabad"

    app_host: str = "0.0.0.0"
    app_port: int = 8000
    frontend_origin: str = "http://localhost:5000"


@lru_cache
def get_settings() -> Settings:
    return Settings()
