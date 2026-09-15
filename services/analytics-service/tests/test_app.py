"""Testes de unidade para o analytics-service (health check e worker SQS)."""
import json


def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_process_message_success_deletes_from_queue(app_module):
    message = {
        "MessageId": "msg-1",
        "ReceiptHandle": "receipt-1",
        "Body": json.dumps(
            {
                "user_id": "user-1",
                "flag_name": "demo",
                "result": True,
                "timestamp": "2024-01-01T00:00:00Z",
            }
        ),
    }

    app_module.process_message(message)

    assert app_module.dynamodb_client.put_calls, "esperava um put_item no DynamoDB"
    table_name, item = app_module.dynamodb_client.put_calls[0]
    assert table_name == "ToggleMasterAnalytics"
    assert item["flag_name"]["S"] == "demo"
    assert item["result"]["BOOL"] is True
    assert "receipt-1" in app_module.sqs_client.deleted


def test_process_message_invalid_json_does_not_delete(app_module):
    message = {
        "MessageId": "msg-2",
        "ReceiptHandle": "receipt-2",
        "Body": "{invalid-json",
    }

    app_module.process_message(message)

    assert not app_module.dynamodb_client.put_calls
    assert "receipt-2" not in app_module.sqs_client.deleted


def test_process_message_missing_field_does_not_delete(app_module):
    message = {
        "MessageId": "msg-3",
        "ReceiptHandle": "receipt-3",
        "Body": json.dumps({"user_id": "user-1"}),  # falta flag_name/result/timestamp
    }

    app_module.process_message(message)

    assert not app_module.dynamodb_client.put_calls
    assert "receipt-3" not in app_module.sqs_client.deleted
