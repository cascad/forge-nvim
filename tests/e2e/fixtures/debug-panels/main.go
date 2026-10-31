package main

import "fmt"

type sample struct { Value int }

func main() {
	item := sample{Value: 42}
	fmt.Println("PANEL_BEFORE", item.Value)
	checkpoint(item)
	fmt.Println("PANEL_AFTER")
}

func checkpoint(item sample) {
	fmt.Println("PANEL_BREAKPOINT", item.Value) // E2E_BREAKPOINT
}
