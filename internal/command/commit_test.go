package command

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestCommitCommand_Execute(t *testing.T) {
	// This test simply verifies that the commit command can be instantiated
	// and implements the Command interface
	commitCmd := &CommitCommand{
		Message: "Test commit message",
	}

	// Verify it implements Command interface
	_, ok := interface{}(commitCmd).(Command)
	assert.True(t, ok, "CommitCommand should implement Command interface")
}