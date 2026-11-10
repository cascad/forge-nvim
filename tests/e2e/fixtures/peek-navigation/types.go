package sample

type Named interface {
	Name() string
}

type Widget struct{}

func (Widget) Name() string {
	return "widget"
}
