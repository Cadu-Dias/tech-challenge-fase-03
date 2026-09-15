"""
Configuração compartilhada dos testes do targeting-service.

Mesma estratégia do flag-service: definir as variáveis de ambiente
obrigatórias e substituir o pool de conexões do PostgreSQL por um dublê antes
de importar o módulo app.py, evitando qualquer dependência de infraestrutura
real durante os testes.
"""
import importlib
import sys

import pytest


class FakeCursor:
    def __init__(self, conn):
        self._conn = conn
        self.rowcount = 1

    def execute(self, query, params=None):
        self._conn.last_query = query
        self._conn.last_params = params
        self.rowcount = self._conn.rowcount

    def fetchone(self):
        return self._conn.fake_row

    def fetchall(self):
        return self._conn.fake_rows

    def close(self):
        pass


class FakeConnection:
    def __init__(self):
        self.rowcount = 1
        self.fake_row = {
            "id": 1,
            "flag_name": "demo",
            "is_enabled": True,
            "rules": {"type": "PERCENTAGE", "value": 100},
        }
        self.fake_rows = [self.fake_row]
        self.last_query = None
        self.last_params = None

    def cursor(self, cursor_factory=None):
        return FakeCursor(self)

    def commit(self):
        pass

    def rollback(self):
        pass


class FakePool:
    def __init__(self, *args, **kwargs):
        self._conn = FakeConnection()

    def getconn(self):
        return self._conn

    def putconn(self, conn):
        pass


@pytest.fixture
def app_module(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/targeting_db")
    monkeypatch.setenv("AUTH_SERVICE_URL", "http://auth-service:8001")

    import psycopg2.pool as psycopg2_pool

    monkeypatch.setattr(psycopg2_pool, "SimpleConnectionPool", FakePool)

    sys.modules.pop("app", None)
    module = importlib.import_module("app")
    yield module
    sys.modules.pop("app", None)


@pytest.fixture
def client(app_module, monkeypatch):
    def always_pass(*args, **kwargs):
        class Resp:
            status_code = 200

        return Resp()

    monkeypatch.setattr(app_module.requests, "get", always_pass)
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as c:
        yield c
