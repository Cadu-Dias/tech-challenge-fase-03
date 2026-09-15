"""
Configuração compartilhada dos testes do analytics-service.

O app.py real inicia N threads que fazem long-polling na fila SQS assim que o
módulo é importado (`start_worker()` roda no import). Para testar a lógica de
processamento de mensagens de forma isolada, isso é neutralizado da seguinte
forma:
  - variáveis de ambiente obrigatórias são definidas;
  - `boto3.Session` é substituída por uma dublê que devolve clientes falsos
    (sem chamadas reais à AWS);
  - `threading.Thread` é substituída por uma versão cujo `.start()` não
    executa nada, evitando loops de background reais durante os testes.
"""
import importlib
import sys

import pytest


class FakeSqsClient:
    def __init__(self):
        self.deleted = []
        self.put_calls = []

    def receive_message(self, **kwargs):
        return {"Messages": []}

    def delete_message(self, QueueUrl, ReceiptHandle):
        self.deleted.append(ReceiptHandle)


class FakeDynamoClient:
    def __init__(self):
        self.put_calls = []

    def put_item(self, TableName, Item):
        self.put_calls.append((TableName, Item))


class FakeSession:
    def __init__(self, region_name=None):
        self.region_name = region_name

    def client(self, service_name):
        if service_name == "sqs":
            return FakeSqsClient()
        if service_name == "dynamodb":
            return FakeDynamoClient()
        raise ValueError(f"cliente boto3 não esperado nos testes: {service_name}")


class NoOpThread:
    """Substitui threading.Thread para não iniciar loops reais nos testes."""

    def __init__(self, *args, **kwargs):
        self._target = kwargs.get("target")
        self.name = kwargs.get("name")
        self.daemon = kwargs.get("daemon", False)

    def start(self):
        pass


@pytest.fixture
def app_module(monkeypatch):
    monkeypatch.setenv("AWS_REGION", "us-east-1")
    monkeypatch.setenv("AWS_SQS_URL", "https://sqs.us-east-1.amazonaws.com/123/toggle-events")
    monkeypatch.setenv("AWS_DYNAMODB_TABLE", "ToggleMasterAnalytics")
    monkeypatch.setenv("WORKER_THREADS", "1")

    import boto3
    import threading

    monkeypatch.setattr(boto3, "Session", FakeSession)
    monkeypatch.setattr(threading, "Thread", NoOpThread)

    sys.modules.pop("app", None)
    module = importlib.import_module("app")
    yield module
    sys.modules.pop("app", None)


@pytest.fixture
def client(app_module):
    app_module.app.config["TESTING"] = True
    with app_module.app.test_client() as c:
        yield c
