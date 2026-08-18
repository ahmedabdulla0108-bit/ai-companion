import pytest
from fastapi import HTTPException
from app.auth import verify_token

def test_verify_accepts_correct_token():
    verify_token("Bearer secret", expected="secret")  # no raise

def test_verify_rejects_missing():
    with pytest.raises(HTTPException) as e:
        verify_token(None, expected="secret")
    assert e.value.status_code == 401

def test_verify_rejects_wrong():
    with pytest.raises(HTTPException) as e:
        verify_token("Bearer nope", expected="secret")
    assert e.value.status_code == 401
