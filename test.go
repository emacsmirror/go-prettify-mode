package main

import (
	"errors"
	"fmt"
	"log"
	"sort"
)

func fn() error { return errors.New("abc") }

var (
	a = 9
	b = []uint{}
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

	if err != nil && a == 10 {
		log.Fatal("1-statement blocks are also hide")
	}

	// Types of arguments hide in anonymous functions.
	sort.Slice([]uint{4, 2}, func(i, j int) bool { return i < j })

	// `:= range` replaces to just `in`. Simple blocks are also hide.
	for _, i := range []uint{4, 2} {
		b = append(b, i)
	}

	return nil
}
