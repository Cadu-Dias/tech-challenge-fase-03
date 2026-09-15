"""
Configuração compartilhada dos testes do flag-service.

O app.py real conecta no PostgreSQL e chama sys.exit(1) caso as variáveis de
ambiente obrigatórias não estejam definidas ou a conexão falhe. Para testar a
lógica de negócio isoladamente (sem infraestrutura real), definimos as
variáveis de ambiente necessárias e substituímos o pool de conexões por um
dublê (fake) antes de importar o módulo.
"""
import importlib
import sys

import pytest


class FakeCursor:
    """Cursor falso que registra a última query executada."""

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

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        return False


class FakeConnection:
    def __init__(self):
        self.rowcount = 1
        self.fake_row = {"id": 1, "name": "demo", "is_enabled": True}
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
    """Substitui psycopg2.pool.SimpleConnectionPool nos testes."""

    def __init__(self, *args, **kwargs):
        self._conn = FakeConnection()

    def getconn(self):
        return self._conn

    def putconn(self, conn):
        pass


@pytest.fixture
def app_module(monkeypatch):
    """Importa o módulo app.py com dependências externas isoladas."""
    monkeypatch.setenv("DATABASE_URL", "postgres://user:pass@localhost:5432/flag_db")
    monkeypatch.setenv("AUTH_SERVICE_URL", "http://auth-service:8001")

    import psycopg2.pool as psycopg2_pool

    monkeypatch.setattr(psycopg2_pool, "SimpleConnectionPool", FakePool)

    sys.modules.pop("app", None)
    module = importlib.import_module("app")
    yield module
    sys.modules.pop("app", None)


@pytest.fixture
def client(app_module, monkeypatch):
    """Cliente de teste Flask com a autenticação sempre validada com sucesso."""

    def fake_require_auth(f):
        return f

    # A autenticação real chama o auth-service via HTTP; nos testes de unidade
    # do flag-service isso é substituído por uma checagem simples de header.
    def always_pass(*args, **kwargs):
        class Resp:
            status_code = 200

        return Resp()

    monkeypatch.setattr(app_module.requests, "get", always_pass)
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as c:
        yield c
