package sample

func Use() int {
	return Double(21)
}

func OtherUse() int {
	return Double(2)
}

func TypeUse() string {
	item := Widget{}
	var named Named = item
	return named.Name()
}
