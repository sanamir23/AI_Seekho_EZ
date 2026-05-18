from fastapi import APIRouter, Depends, HTTPException, status

from app.db.supabase import get_anon_client, get_service_client
from app.deps import CurrentUser, get_current_user
from app.schemas.auth import LoginIn, SessionOut, SignupIn, UserOut

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/signup", response_model=SessionOut, status_code=status.HTTP_201_CREATED)
def signup(body: SignupIn) -> SessionOut:
    anon = get_anon_client()
    try:
        resp = anon.auth.sign_up({"email": body.email, "password": body.password})
    except Exception as e:
        raise HTTPException(status.HTTP_400_BAD_REQUEST, f"Signup failed: {e}")

    user = resp.user
    session = resp.session
    if user is None or session is None:
        raise HTTPException(
            status.HTTP_400_BAD_REQUEST,
            "Signup did not return a session. Disable 'Confirm email' in Supabase "
            "Auth settings.",
        )

    svc = get_service_client()
    svc.table("profiles").upsert(
        {"id": user.id, "email": body.email, "display_name": body.display_name},
        on_conflict="id",
    ).execute()

    return SessionOut(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        user_id=user.id,
        email=body.email,
    )


@router.post("/login", response_model=SessionOut)
def login(body: LoginIn) -> SessionOut:
    anon = get_anon_client()
    try:
        resp = anon.auth.sign_in_with_password(
            {"email": body.email, "password": body.password}
        )
    except Exception as e:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, f"Login failed: {e}")
    user = resp.user
    session = resp.session
    if user is None or session is None:
        raise HTTPException(status.HTTP_401_UNAUTHORIZED, "Invalid credentials")
    return SessionOut(
        access_token=session.access_token,
        refresh_token=session.refresh_token,
        user_id=user.id,
        email=body.email,
    )


@router.get("/me", response_model=UserOut)
def me(user: CurrentUser = Depends(get_current_user)) -> UserOut:
    svc = get_service_client()
    row = (
        svc.table("profiles")
        .select("id, email, display_name")
        .eq("id", user.id)
        .limit(1)
        .execute()
    )
    if not row.data:
        return UserOut(id=user.id, email=user.email, display_name=None)
    r = row.data[0]
    return UserOut(id=r["id"], email=r.get("email"), display_name=r.get("display_name"))
