from dataclasses import dataclass

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from app.db.supabase import get_anon_client, client_for_token

bearer = HTTPBearer(auto_error=True)


@dataclass
class CurrentUser:
    id: str
    email: str | None
    access_token: str


async def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(bearer),
) -> CurrentUser:
    token = creds.credentials
    try:
        resp = get_anon_client().auth.get_user(token)
    except Exception as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"Invalid token: {e}")
    user = getattr(resp, "user", None)
    if user is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid token")
    return CurrentUser(id=user.id, email=user.email, access_token=token)


def user_db(user: CurrentUser = Depends(get_current_user)):
    return client_for_token(user.access_token)
