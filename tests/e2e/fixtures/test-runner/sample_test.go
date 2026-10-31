package sample

import (
	"os"
	"testing"
)

func TestNearest(t *testing.T) {
	value := 42
	t.Log("NEAREST_OUTPUT", value) // E2E_BREAKPOINT
}

func TestNeighbour(t *testing.T) {
	_ = os.WriteFile("neighbour-ran.txt", []byte("executed"), 0600)
	t.Fatal("NEIGHBOUR_FAILURE")
}
