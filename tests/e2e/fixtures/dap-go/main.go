package main

import (
	"fmt"
	"os"
	"time"
)

func main() {
	marker := os.Args[1]
	fmt.Println("STDOUT_BEFORE_" + marker)
	fmt.Fprintln(os.Stderr, "STDERR_BEFORE_"+marker)
	checkpoint(marker)
	if marker == "hidden" {
		fmt.Println("WAITING_FOR_GATE")
		for {
			if _, err := os.Stat("continue.flag"); err == nil {
				break
			}
			time.Sleep(10 * time.Millisecond)
		}
		checkpoint(marker)
	}
	if marker == "panic" {
		panic("FORGE_PANIC_MESSAGE")
	}
	fmt.Println("STDOUT_AFTER_" + marker)
}

func checkpoint(marker string) {
	fmt.Println("BREAKPOINT_" + marker) // E2E_BREAKPOINT
}
