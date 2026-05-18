from functools import lru_cache

from langgraph.checkpoint.postgres import PostgresSaver
from psycopg_pool import ConnectionPool

from app.config import get_settings


@lru_cache
def get_checkpointer() -> PostgresSaver:
    s = get_settings()
    pool = ConnectionPool(
        conninfo=s.supabase_db_url,
        max_size=10,
        kwargs={"autocommit": True, "prepare_threshold": 0},
        open=True,
    )
    saver = PostgresSaver(pool)
    saver.setup()  # creates langgraph schema/tables on first run; idempotent
    return saver
