from __future__ import annotations

from contextlib import contextmanager
from dataclasses import dataclass
from typing import Iterator

import psycopg
from psycopg.rows import dict_row
from psycopg import sql

from app.core.config import settings


@dataclass(frozen=True)
class MasterContext:
    tenant_id: int
    company_id: int | None = None


@contextmanager
def db_connection() -> Iterator[psycopg.Connection]:
    conn = psycopg.connect(
        host=settings.ktms_db_host,
        port=settings.ktms_db_port,
        dbname=settings.ktms_db_name,
        user=settings.ktms_db_user,
        password=settings.ktms_db_password,
        row_factory=dict_row,
    )
    try:
        yield conn
        conn.commit()
    except Exception:
        conn.rollback()
        raise
    finally:
        conn.close()


def table_identifier(table_name: str) -> sql.Identifier:
    return sql.Identifier(settings.ktms_db_schema, table_name)


def default_master_context(conn: psycopg.Connection) -> MasterContext:
    tenant_filter = sql.SQL("")
    company_filter = sql.SQL("")
    params: list[object] = []

    if settings.ktms_default_tenant_code:
        tenant_filter = sql.SQL("and t.tenant_code = %s")
        params.append(settings.ktms_default_tenant_code)

    if settings.ktms_default_company_code:
        company_filter = sql.SQL("and c.company_code = %s")
        params.append(settings.ktms_default_company_code)

    query = sql.SQL(
        """
        select t.tenant_id, c.company_id
        from {tenants} t
        join {companies} c on c.tenant_id = t.tenant_id
        where t.deleted_at is null
          and c.deleted_at is null
          and t.is_active = true
          and c.is_active = true
          {tenant_filter}
          {company_filter}
        order by t.tenant_id, c.company_id
        limit 1
        """
    ).format(
        tenants=table_identifier("tenants"),
        companies=table_identifier("companies"),
        tenant_filter=tenant_filter,
        company_filter=company_filter,
    )

    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()

    if not row:
        raise RuntimeError("No active tenant/company context was found.")

    return MasterContext(
        tenant_id=int(row["tenant_id"]),
        company_id=int(row["company_id"]),
    )
