"""Sirve para hacer consultas a la base de datos."""
from django.db import connection

def fetchall(sql, params=None):
    with connection.cursor() as cur:
        cur.execute(sql, params or [])
        cols = [c[0] for c in cur.description]
        return [dict(zip(cols, row)) for row in cur.fetchall()]

def fetchone(sql, params=None):
    rows = fetchall(sql, params)
    return rows[0] if rows else None

def execute(sql, params=None):
    with connection.cursor() as cur:
        cur.execute(sql, params or [])
        return cur.rowcount

def parametro(clave, default):
    row = fetchone("select valor from parametros where clave = %s", [clave])
    return float(row["valor"]) if row else default
