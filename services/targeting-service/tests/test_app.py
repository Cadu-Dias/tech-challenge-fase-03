"""Testes de unidade para os endpoints do targeting-service."""


def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_create_rule_requires_auth_header(client):
    resp = client.post("/rules", json={"flag_name": "demo", "rules": {}})
    assert resp.status_code == 401


def test_create_rule_requires_fields(client):
    resp = client.post(
        "/rules", json={}, headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 400


def test_create_rule_success(client):
    resp = client.post(
        "/rules",
        json={"flag_name": "demo", "rules": {"type": "PERCENTAGE", "value": 50}},
        headers={"Authorization": "Bearer tm_key_x"},
    )
    assert resp.status_code == 201
    assert resp.get_json()["flag_name"] == "demo"


def test_get_rule_not_found(client, app_module):
    fake_conn = app_module.pool.getconn()
    fake_conn.fake_row = None
    resp = client.get(
        "/rules/inexistente", headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 404


def test_update_rule_requires_fields(client):
    resp = client.put(
        "/rules/demo", json={}, headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 400


def test_delete_rule_success(client):
    resp = client.delete("/rules/demo", headers={"Authorization": "Bearer tm_key_x"})
    assert resp.status_code == 204
