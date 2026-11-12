package main

import (
	"os"
	"strconv"
	"testing"

	"example.test/forge/shared"
)

func TestApp(t *testing.T) {
	data, _ := os.ReadFile("app-runs.txt")
	n, _ := strconv.Atoi(string(data))
	if err := os.WriteFile("app-runs.txt", []byte(strconv.Itoa(n+1)), 0600); err != nil {
		t.Fatal(err)
	}
	t.Log("APP_WORK_TEST")
	if shared.Answer() != 42 {
		t.Fatal("APP_WORK_VALUE")
	}
}
