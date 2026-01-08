"""FastAPI dependency injection functions."""

from typing import Annotated

from fastapi import Depends

from src.app.core.config import Settings, get_settings

# Type alias for settings dependency
SettingsDep = Annotated[Settings, Depends(get_settings)]
