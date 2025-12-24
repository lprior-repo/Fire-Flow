package command

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/lprior-repo/Fire-Flow/internal/utils"
	"github.com/stretchr/testify/assert"
)

func TestCommandInterface(t *testing.T) {
	// Test that all commands implement the Command interface
	factory := &CommandFactory{}

	// Test that all commands can be created
	commands := []string{"init", "status", "watch", "gate"}

	for _, cmdName := range commands {
		cmd, err := factory.NewCommand(cmdName)
		if err != nil {
			t.Errorf("Failed to create command %s: %v", cmdName, err)
		}

		// Verify it implements Command interface
		_, ok := cmd.(Command)
		if !ok {
			t.Errorf("Command %s does not implement Command interface", cmdName)
		}
	}
}

func TestUnknownCommand(t *testing.T) {
	factory := &CommandFactory{}
	_, err := factory.NewCommand("unknown")
	if err == nil {
		t.Error("Expected error for unknown command")
	}
}

func TestCommandFactoryNewCommand(t *testing.T) {
	factory := &CommandFactory{}

	// Test valid commands
	validCommands := []string{"init", "status", "watch", "gate"}
	for _, cmdName := range validCommands {
		cmd, err := factory.NewCommand(cmdName)
		if err != nil {
			t.Errorf("Failed to create command %s: %v", cmdName, err)
		}
		if cmd == nil {
			t.Errorf("Command %s is nil", cmdName)
		}
	}

	// Test invalid command
	_, err := factory.NewCommand("invalid")
	if err == nil {
		t.Error("Expected error for invalid command")
	}
}

func TestInitCommand_Execute(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-init-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Override the TCR path to use the temp directory
	originalTCRPath := utils.GetTCRPath()
	originalConfigPath := utils.GetConfigPath()
	originalStatePath := utils.GetStatePath()

	// Mock paths to use temp directory
	utils.GetTCRPath = func() string { return tempDir }
	utils.GetConfigPath = func() string { return filepath.Join(tempDir, "config.yml") }
	utils.GetStatePath = func() string { return filepath.Join(tempDir, "state.json") }

	// Create InitCommand
	initCmd := &InitCommand{}

	// Execute init command
	err = initCmd.Execute()
	assert.NoError(t, err)

	// Verify directory was created
	_, err = os.Stat(tempDir)
	assert.NoError(t, err)

	// Verify config file was created
	configPath := filepath.Join(tempDir, "config.yml")
	_, err = os.Stat(configPath)
	assert.NoError(t, err)

	// Verify state file was created
	statePath := filepath.Join(tempDir, "state.json")
	_, err = os.Stat(statePath)
	assert.NoError(t, err)

	// Restore original functions
	utils.GetTCRPath = func() string { return originalTCRPath }
	utils.GetConfigPath = func() string { return originalConfigPath }
	utils.GetStatePath = func() string { return originalStatePath }
}