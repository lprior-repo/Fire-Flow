package command

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCommandFactory_NewCommand(t *testing.T) {
	factory := &CommandFactory{}

	// Test that all known commands can be created
	commands := []string{"init", "status", "gate", "tdd-gate", "run-tests", "commit", "revert"}

	for _, cmdName := range commands {
		cmd, err := factory.NewCommand(cmdName)
		assert.NoError(t, err, "Failed to create command: %s", cmdName)
		assert.NotNil(t, cmd, "Command should not be nil: %s", cmdName)
	}
}

func TestCommandFactory_NewCommand_Unknown(t *testing.T) {
	factory := &CommandFactory{}

	cmd, err := factory.NewCommand("unknown-command")
	assert.Error(t, err)
	assert.Nil(t, cmd)
}
