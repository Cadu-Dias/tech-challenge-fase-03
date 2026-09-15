package main

import "testing"

func TestGenerateAPIKeyHasExpectedPrefixAndLength(t *testing.T) {
	key, err := generateAPIKey()
	if err != nil {
		t.Fatalf("generateAPIKey retornou erro inesperado: %v", err)
	}

	const prefix = "tm_key_"
	if len(key) <= len(prefix) || key[:len(prefix)] != prefix {
		t.Errorf("chave gerada não possui o prefixo esperado %q: %q", prefix, key)
	}

	// prefixo (7) + 32 bytes em hex (64 chars) = 71 chars
	expectedLen := len(prefix) + 64
	if len(key) != expectedLen {
		t.Errorf("tamanho da chave = %d, esperado %d", len(key), expectedLen)
	}
}

func TestGenerateAPIKeyIsRandom(t *testing.T) {
	key1, err := generateAPIKey()
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	key2, err := generateAPIKey()
	if err != nil {
		t.Fatalf("erro inesperado: %v", err)
	}
	if key1 == key2 {
		t.Errorf("duas chamadas geraram a mesma chave: %q", key1)
	}
}

func TestHashAPIKeyIsDeterministic(t *testing.T) {
	h1 := hashAPIKey("minha-chave-de-teste")
	h2 := hashAPIKey("minha-chave-de-teste")
	if h1 != h2 {
		t.Errorf("hashAPIKey não é determinístico: %q != %q", h1, h2)
	}
	if len(h1) != 64 {
		t.Errorf("tamanho do hash sha256 hex = %d, esperado 64", len(h1))
	}
}

func TestHashAPIKeyDiffersForDifferentInputs(t *testing.T) {
	h1 := hashAPIKey("chave-a")
	h2 := hashAPIKey("chave-b")
	if h1 == h2 {
		t.Errorf("hashes de entradas diferentes colidiram: %q", h1)
	}
}
