package main

import (
	"fmt"
	"os"

	"github.com/lprior-repo/Fire-Flow/internal/command"
	"github.com/lprior-repo/Fire-Flow/internal/version"
)

func main() {
	fmt.Printf("[*] %s starting...\n", version.Info())
	fmt.Printf("Welcome to %s!\n", version.Name)
	fmt.Println("[*] Fire-Flow is ready to orchestrate workflows")

	// Handle command parsing
	if len(os.Args) < 2 {
		printUsage()
		os.Exit(1)
	}

	commandName := os.Args[1]

	// Create command factory and get command
	factory := &command.CommandFactory{}
	cmd, err := factory.NewCommand(commandName)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		printUsage()
		os.Exit(1)
	}

	// Execute command
	if err := cmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: fire-flow <command> [args]")
	fmt.Println("Available commands:")
	fmt.Println("  init       - Initialize Fire-Flow state and config")
	fmt.Println("  status     - Show current TCR state")
}
