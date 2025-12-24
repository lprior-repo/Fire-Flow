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

	// Parse command-specific arguments
	switch c := cmd.(type) {
	case *command.CommitCommand:
		if len(os.Args) > 2 {
			c.Message = os.Args[2]
		}
	case *command.SyncBeadsCommand:
		if len(os.Args) > 2 {
			c.SourceDir = os.Args[2]
		}
		if len(os.Args) > 3 {
			c.WorkingDir = os.Args[3]
		}
	case *command.NextBeadCommand:
		if len(os.Args) > 2 {
			c.WorkingDir = os.Args[2]
		}
	case *command.RunAICommand:
		if len(os.Args) > 2 {
			c.BeadID = os.Args[2]
		}
		if len(os.Args) > 3 {
			c.Model = os.Args[3]
		}
	case *command.PushChangesCommand:
		if len(os.Args) > 2 {
			c.Message = os.Args[2]
		}
	}

	// Execute command
	if err := cmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Println("Usage: fire-flow <command> [args]")
	fmt.Println("\nTCR Commands:")
	fmt.Println("  init         - Initialize TCR state")
	fmt.Println("  status       - Show TCR status")
	fmt.Println("  tdd-gate     - Run TDD gate check")
	fmt.Println("  run-tests    - Execute test suite")
	fmt.Println("  commit [msg] - Commit changes")
	fmt.Println("  revert       - Revert changes")
	fmt.Println("  watch        - Watch for changes")
	fmt.Println("\nOrchestration Commands (for Kestra):")
	fmt.Println("  sync-beads [source] [working]  - Sync beads database")
	fmt.Println("  next-bead [working]            - Get next ready bead ID (JSON)")
	fmt.Println("  run-ai <bead-id> [model]       - Run AI on a bead")
	fmt.Println("  push-changes [msg]             - Push changes to remote")
}
