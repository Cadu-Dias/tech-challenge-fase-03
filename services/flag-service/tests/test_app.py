"""Testes de unidade para os endpoints do flag-service."""


def test_health_returns_ok(client):
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.get_json() == {"status": "ok"}


def test_create_flag_requires_auth_header(client):
    resp = client.post("/flags", json={"name": "demo"})
    assert resp.status_code == 401


def test_create_flag_requires_name(client):
    resp = client.post(
        "/flags", json={}, headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 400
    assert "name" in resp.get_json()["error"]


def test_create_flag_success(client):
    resp = client.post(
        "/flags",
        json={"name": "demo", "is_enabled": True},
        headers={"Authorization": "Bearer tm_key_x"},
    )
    assert resp.status_code == 201
    body = resp.get_json()
    assert body["name"] == "demo"


def test_get_flags_returns_list(client):
    resp = client.get("/flags", headers={"Authorization": "Bearer tm_key_x"})
    assert resp.status_code == 200
    assert isinstance(resp.get_json(), list)


def test_get_flag_not_found(client, app_module, monkeypatch):
    # Simula um cursor que não encontra nenhuma linha
    fake_conn = app_module.pool.getconn()
    fake_conn.fake_row = None

    resp = client.get(
        "/flags/inexistente", headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 404


def test_update_flag_requires_body_fields(client):
    resp = client.put(
        "/flags/demo", json={}, headers={"Authorization": "Bearer tm_key_x"}
    )
    assert resp.status_code == 400


def test_delete_flag_success(client):
    resp = client.delete("/flags/demo", headers={"Authorization": "Bearer tm_key_x"})
    assert resp.status_code == 204
