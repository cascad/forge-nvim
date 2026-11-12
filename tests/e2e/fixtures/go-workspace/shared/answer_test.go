package shared

import (
	"os"
	"strconv"
	"testing"
)

func recordRun(t *testing.T, file string) {
	t.Helper()
	data, _ := os.ReadFile(file)
	n, _ := strconv.Atoi(string(data))
	if err := os.WriteFile(file, []byte(strconv.Itoa(n+1)), 0600); err != nil {
		t.Fatal(err)
	}
}

func TestShared(t *testing.T) {
	recordRun(t, "shared-runs.txt")
	t.Log("SHARED_WORK_TEST")
	if Answer() != 42 {
		t.Fatal("SHARED_WORK_VALUE")
	}
}

func TestExpected(t *testing.T) {
	recordRun(t, "expected-runs.txt")
	if got := Answer(); got != 43 {
		t.Fatalf("WORK_EXPECT_FAILURE got=%d", got)
	}
}
