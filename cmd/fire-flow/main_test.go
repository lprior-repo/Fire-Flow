package main

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/lprior-repo/Fire-Flow/internal/command"
)

func TestCommandFactory(t *testing.T) {
	factory := &command.CommandFactory{}

	// Test that all commands can be created
	commands := []string{"init", "status", "watch", "gate"}

	for _, cmdName := range commands {
		cmd, err := factory.NewCommand(cmdName)
		assert.NoError(t, err)
		assert.NotNil(t, cmd)
	}

	// Test that unknown command returns error
	_, err := factory.NewCommand("unknown")
	assert.Error(t, err)
}