package main

import (
	"context"
	"errors"
	"fmt"
	"log"
	"sort"
)

// don't eat the result of topmost func
func lastParamIsFunc(ctx context.Context, fn func(ctx context.Context) (int, error)) (result int, err error) {
}

type fn2 func(ctx context.Context, a int) (b int, err error)

func fn() error { return errors.New("abc") }

func (i int) SuperFunc() int {
	// lambda and then 1-code-block should be combined here
	idx := func(status int) (int, error) {
		return slices.Index(slice, status)
	}
}

// Should not eat the next func
type SuperFn func(ctx context.Context, a int) (b int, err error)

func (p *Struct) TestFn(ctx context.Context) (int, error) {}

var (
	a = 9
	b = []uint{}
)

// don't wrap func here
var c = http.MethodFunc(http.MethodPost, "path", fn)

// and here
var d = http.MethodFunc(http.MethodPost, "path/{template}", fn)

type VeryVeryLongBusinessLogicTypeThatsNotVeryInformative uint

func testFunc() error {
	var err error
	if err != nil {
		return fmt.Errorf("just err: %w", err)
	}

	if err != nil {
		log.Print("multiple lines")
		return fmt.Errorf("does not merge in 1 line")
	}

	if err := fn(); err != nil {
		return fmt.Errorf("wraps to the same line, err: %w", err)
	}

	if eror != nil && a == 10 {
		log.Fatal("1-statement blocks are hidden also")
	}

	if eror != nil && a == 10 {
		log.Fatal("but too long statements are not hidden, or they are look too ugly")
	}

	if err != nil && a == 10 {
		log.Fatal("2-statement blocks are not hidden")
		log.Fatal("complex logic")
	}

	// Types of arguments hide in anonymous functions.
	sort.Slice([]uint{4, 2}, func(i, j VeryVeryLongBusinessLogicTypeThatsNotVeryInformative) bool { return i < j })

	// `:= range` replaces to just `in`. Simple blocks are also hidden.
	for _, i := range []uint{4, 2} {
		continue
	}

	if true {
		fmt.Println("don't hide if/else blocks")
	} else {
		fmt.Println("otherwise it looks ugly")
	}

	return nil
}
