package command

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/state"
)

const (
	TCRDir     = ".fire-flow"
	ConfigFile = "config.yaml"
	StateFile  = "state.json"
)

// Command interface defines the contract for all Fire-Flow commands
type Command interface {
	Execute() error
}

// CommandFactory creates command instances
type CommandFactory struct{}

// NewCommand creates a new command instance based on the command name
func (f *CommandFactory) NewCommand(name string) (Command, error) {
	switch name {
	case "init":
		return &InitCommand{}, nil
	case "status":
		return &StatusCommand{}, nil
	default:
		return nil, fmt.Errorf("unknown command: %s", name)
	}
}

// Helper functions
func getTCRPath() string {
	return filepath.Join(".", TCRDir)
}

func getConfigPath() string {
	return filepath.Join(getTCRPath(), ConfigFile)
}

func getStatePath() string {
	return filepath.Join(getTCRPath(), StateFile)
}

// InitCommand initializes Fire-Flow
type InitCommand struct{}

func (cmd *InitCommand) Execute() error {
	tcrPath := getTCRPath()
	if err := os.MkdirAll(tcrPath, 0755); err != nil {
		return fmt.Errorf("failed to create directory %s: %w", tcrPath, err)
	}

	// Create default config
	configPath := getConfigPath()
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		cfg := config.DefaultConfig()
		if err := cfg.SaveToFile(configPath); err != nil {
			return fmt.Errorf("failed to create config: %w", err)
		}
		fmt.Printf("Created config at %s\n", configPath)
	}

	// Create default state
	statePath := getStatePath()
	if _, err := os.Stat(statePath); os.IsNotExist(err) {
		st := state.NewState()
		if err := st.SaveToFile(statePath); err != nil {
			return fmt.Errorf("failed to create state: %w", err)
		}
		fmt.Printf("Created state at %s\n", statePath)
	}

	fmt.Println("Fire-Flow initialized successfully!")
	return nil
}

// StatusCommand shows current state
type StatusCommand struct{}

func (cmd *StatusCommand) Execute() error {
	statePath := getStatePath()
	st, err := state.LoadStateFromFile(statePath)
	if err != nil {
		return fmt.Errorf("failed to load state: %w", err)
	}

	fmt.Printf("State: %s\n", strings.ToUpper(st.Mode))
	fmt.Printf("RevertStreak: %d\n", st.RevertStreak)
	fmt.Printf("LastCommit: %s\n", st.LastCommitTime.Format("2006-01-02 15:04:05"))
	fmt.Printf("FailingTests: %v\n", st.FailingTests)

	return nil
}
