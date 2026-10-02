"""Shared MySQL connection helper. Reads settings from the .env file in the repo root.

Usage:
    from src.etl.db import get_engine
    engine = get_engine()
    df.to_sql("accident", engine, if_exists="append", index=False)
"""

import os

from dotenv import load_dotenv
from sqlalchemy import create_engine
from sqlalchemy.engine import Engine

from src.etl.paths import REPO_ROOT

load_dotenv(REPO_ROOT / ".env")


def get_engine() -> Engine:
    url = (
        f"mysql+pymysql://{os.environ['MYSQL_USER']}:{os.environ['MYSQL_PASSWORD']}"
        f"@{os.getenv('MYSQL_HOST', 'localhost')}:{os.getenv('MYSQL_PORT', '3306')}"
        f"/{os.getenv('MYSQL_DB', 'fars')}"
    )
    return create_engine(url)
