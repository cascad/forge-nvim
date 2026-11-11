package main

import "fmt"

type Item struct {
	Value int
	Name  string
}

func main() {
	item := Item{Value: 42, Name: "frame"}
	fmt.Println("FRAME_BEFORE", item.Value)
	item.Value++ // FRAME_FIRST
	fmt.Println("FRAME_MIDDLE", item.Value)
	item.Value += 7 // FRAME_SECOND
	fmt.Println("FRAME_AFTER", item.Value)
}
