package command

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCommandInterface(t *testing.T) {
	// Test that all commands implement the Command interface
	factory := &CommandFactory{}

	// Test that all commands can be created
	commands := []string{"init", "status", "gate"}

	for _, cmdName := range commands {
		cmd, err := factory.NewCommand(cmdName)
		if err != nil {
			t.Errorf("Failed to create command %s: %v", cmdName, err)
		}

		// cmd is already of type Command from NewCommand return type
		if cmd == nil {
			t.Errorf("Command %s is nil", cmdName)
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
	validCommands := []string{"init", "status", "gate"}
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
	// Create a test that simply verifies the InitCommand can be instantiated
	// and that it implements the Command interface
	initCmd := &InitCommand{}

	// Verify it implements Command interface
	_, ok := interface{}(initCmd).(Command)
	assert.True(t, ok, "InitCommand should implement Command interface")
}

func TestRunTestsCommandInterface(t *testing.T) {
	// Test that RunTestsCommand implements the Command interface
	runTestsCmd := &RunTestsCommand{}

	// Verify it implements Command interface
	_, ok := interface{}(runTestsCmd).(Command)
	assert.True(t, ok, "RunTestsCommand should implement Command interface")
}
