package main

import "example.test/forge/shared"

func WorkspaceValue(p shared.Provider) int {
	return p.ForgeValue()
}

var WorkspaceProvider shared.Provider = shared.Counter{}
