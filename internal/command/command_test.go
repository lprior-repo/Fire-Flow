package command

import (
	"testing"
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