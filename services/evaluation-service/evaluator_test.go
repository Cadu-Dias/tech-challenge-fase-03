package main

import "testing"

func TestGetDeterministicBucketIsStable(t *testing.T) {
	b1 := getDeterministicBucket("user-123demo")
	b2 := getDeterministicBucket("user-123demo")
	if b1 != b2 {
		t.Errorf("getDeterministicBucket não é determinístico: %d != %d", b1, b2)
	}
	if b1 < 0 || b1 > 99 {
		t.Errorf("bucket fora do intervalo [0,99]: %d", b1)
	}
}

func TestGetDeterministicBucketVariesWithInput(t *testing.T) {
	seen := map[int]bool{}
	for i := 0; i < 20; i++ {
		b := getDeterministicBucket(string(rune('a'+i)) + "-flag")
		seen[b] = true
	}
	if len(seen) < 2 {
		t.Errorf("esperava buckets variados para entradas diferentes, obteve apenas %d valores distintos", len(seen))
	}
}

func TestRunEvaluationLogicFlagDisabled(t *testing.T) {
	app := &App{}
	info := &CombinedFlagInfo{
		Flag: &Flag{Name: "demo", IsEnabled: false},
	}
	if got := app.runEvaluationLogic(info, "user-1"); got != false {
		t.Errorf("flag desabilitada deveria retornar false, obteve %v", got)
	}
}

func TestRunEvaluationLogicNoRuleMeansEnabled(t *testing.T) {
	app := &App{}
	info := &CombinedFlagInfo{
		Flag: &Flag{Name: "demo", IsEnabled: true},
		Rule: nil,
	}
	if got := app.runEvaluationLogic(info, "user-1"); got != true {
		t.Errorf("sem regra de targeting, flag habilitada deveria retornar true, obteve %v", got)
	}
}

func TestRunEvaluationLogicPercentageZeroAlwaysFalse(t *testing.T) {
	app := &App{}
	info := &CombinedFlagInfo{
		Flag: &Flag{Name: "demo", IsEnabled: true},
		Rule: &TargetingRule{
			IsEnabled: true,
			Rules:     Rule{Type: "PERCENTAGE", Value: float64(0)},
		},
	}
	if got := app.runEvaluationLogic(info, "qualquer-user"); got != false {
		t.Errorf("percentage=0 deveria sempre retornar false, obteve %v", got)
	}
}

func TestRunEvaluationLogicPercentageHundredAlwaysTrue(t *testing.T) {
	app := &App{}
	info := &CombinedFlagInfo{
		Flag: &Flag{Name: "demo", IsEnabled: true},
		Rule: &TargetingRule{
			IsEnabled: true,
			Rules:     Rule{Type: "PERCENTAGE", Value: float64(100)},
		},
	}
	if got := app.runEvaluationLogic(info, "qualquer-user"); got != true {
		t.Errorf("percentage=100 deveria sempre retornar true, obteve %v", got)
	}
}
