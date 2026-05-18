from pydantic import BaseModel, EmailStr, Field


class SignupIn(BaseModel):
    email: EmailStr
    password: str = Field(min_length=6)
    display_name: str | None = None


class LoginIn(BaseModel):
    email: EmailStr
    password: str


class SessionOut(BaseModel):
    access_token: str
    refresh_token: str | None = None
    user_id: str
    email: str | None = None


class UserOut(BaseModel):
    id: str
    email: str | None
    display_name: str | None = None
