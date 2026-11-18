// IDE-BOOT-47: standard net API creates an actual AF_UNIX node on all native OSes.
package main

import (
	"bufio"
	"fmt"
	"net"
	"os"
)

func main() {
	listener, err := net.ListenUnix("unix", &net.UnixAddr{Name: "ipc", Net: "unix"})
	if err != nil {
		panic(err)
	}
	listener.SetUnlinkOnClose(false)
	if err := os.WriteFile("ready", []byte("ready"), 0600); err != nil {
		panic(err)
	}
	fmt.Println("ready")
	if len(os.Args) > 1 && os.Args[1] == "live" {
		if _, err := bufio.NewReader(os.Stdin).ReadString('\n'); err != nil {
			panic(err)
		}
	}
	if err := listener.Close(); err != nil {
		panic(err)
	}
}
