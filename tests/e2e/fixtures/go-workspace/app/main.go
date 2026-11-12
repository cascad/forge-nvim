package main

import (
	"fmt"
	"os"

	"example.test/forge/shared"
)

func main() {
	value := shared.Answer()
	fmt.Printf("WORK_BEFORE %d\n", value)
	fmt.Fprintf(os.Stderr, "WORK_STDERR %d\n", value)
	observed := value // E2E_BREAKPOINT
	fmt.Printf("WORK_AFTER %d\n", observed)
}
