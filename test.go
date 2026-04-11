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

type VeryVeryLongBusinessLogicTypeThatsNotVeryInformative uint

func testFunc() error {
	var err error
	if err != nil {
		return fmt.Errorf("just err: %w", err)
	}

	err = fn()
	if err != nil {
		log.Print("multiple lines")
		return fmt.Errorf("does not merge in 1 line")
	}

	if err := fn(); err != nil {
		return fmt.Errorf("wraps to the same line, err: %w", err)
	}

	if err != nil && a == 10 {
		log.Fatal("1-statement blocks are hidden also")
	}

	if err != nil && a == 10 {
		log.Fatal("2-statement blocks are not hidden")
		log.Fatal("complex logic")
	}

	// Types of arguments hide in anonymous functions.
	sort.Slice([]uint{4, 2}, func(i, j VeryVeryLongBusinessLogicTypeThatsNotVeryInformative) bool { return i < j })

	// `:= range` replaces to just `in`. Simple blocks are also hide.
	for _, i := range []uint{4, 2} {
		b = append(b, i)
	}

	// don't wrap func here
	http.MethodFunc(http.MethodPost, "path", fn)

	// and here
	http.MethodFunc(http.MethodPost, "path/{template}", fn)

	// hiding if/else looks ugly, therefore we don't wrap them
	if true {
		fmt.Println(5)
	} else {
		fmt.Println(6)
	}

	return nil
}
