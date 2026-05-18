from functools import lru_cache

from supabase import Client, create_client

from app.config import get_settings


@lru_cache
def get_anon_client() -> Client:
    s = get_settings()
    return create_client(s.supabase_url, s.supabase_anon_key)


@lru_cache
def get_service_client() -> Client:
    """Service-role client. Bypasses RLS. Never expose to end-users."""
    s = get_settings()
    return create_client(s.supabase_url, s.supabase_service_key)


def client_for_token(access_token: str) -> Client:
    """Anon client bound to a user's JWT so PostgREST applies RLS as that user."""
    s = get_settings()
    c = create_client(s.supabase_url, s.supabase_anon_key)
    c.postgrest.auth(access_token)
    return c
