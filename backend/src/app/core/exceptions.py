"""Custom exception classes for the application."""

from fastapi import HTTPException, status


class HRASException(Exception):
    """Base exception for HRAS application."""

    def __init__(self, message: str = "An error occurred"):
        self.message = message
        super().__init__(self.message)


class NotFoundError(HRASException):
    """Resource not found error."""

    pass


class ValidationError(HRASException):
    """Validation error."""

    pass


class ExternalAPIError(HRASException):
    """Error communicating with external API."""

    pass


# HTTP Exception factories
def not_found_exception(detail: str = "Resource not found") -> HTTPException:
    """Create a 404 Not Found exception."""
    return HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=detail)


def bad_request_exception(detail: str = "Bad request") -> HTTPException:
    """Create a 400 Bad Request exception."""
    return HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=detail)


def internal_error_exception(detail: str = "Internal server error") -> HTTPException:
    """Create a 500 Internal Server Error exception."""
    return HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=detail)
