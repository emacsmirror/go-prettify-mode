package main

import (
	"fmt"
)

func testFunc() error {
	var err error
	if err != nil {
		return fmt.Errorf("just err: %w", err)
	}

	err = fn()
	if err != nil {
		log.Print("multiple lines")
		return fmt.Errorf("merges in 1 line")
	}

	if err := fn(); err != nil {
		return fmt.Errorf("the same line, err: %w", err)
	}

	if err != nil {
		return fmt.Errorf("too long strings shorten")
	}

	if err != nil {
		return fmt.Errorf("can't instead of can t")
	}

	a := 9
	if err != nil && a == 10 {
		log.Errorf("It won't be fold")
	}
}
