package shared

type Provider interface {
	ForgeValue() int
}

type Counter struct{}

func (Counter) ForgeValue() int {
	return 42
}
