package main

import (
	"fmt"
	"log"

	"github.com/lprior-repo/Fire-Flow/internal/version"
)

func main() {
	log.Printf("%s starting...", version.Info())
	fmt.Printf("Welcome to %s!\n", version.Name)
	log.Println("Fire-Flow is ready to orchestrate workflows")
}
