from typing import Any, Optional

from fastapi import status
from fastapi.responses import JSONResponse


def create_standard_response(
    result: Optional[Any] = None,
    message: str = "Success",
    actual_status_code: int = status.HTTP_200_OK,
) -> JSONResponse:
    """
    Creates a standardized API response with HTTP status 200.

    Args:
        result: The data payload of the response.
        message: A descriptive message about the outcome.
        actual_status_code: The true HTTP status code representing the outcome.

    Returns:
        A JSONResponse object with status 200 and a standardized body.
    """
    content = {
        "status_code": actual_status_code,
        "message": message,
        "result": result if result is not None else {},
    }
    # Explicitly return with HTTP 200 OK, regardless of the actual_status_code
    return JSONResponse(status_code=status.HTTP_200_OK, content=content)
