package command

import (
	"os"
	"os/exec"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestRevertCommand_Execute(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-revert-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Change to temp directory
	oldDir, err := os.Getwd()
	assert.NoError(t, err)
	defer os.Chdir(oldDir)
	err = os.Chdir(tempDir)
	assert.NoError(t, err)

	// Initialize git repo for testing
	cmd := exec.Command("git", "init")
	_, err = cmd.CombinedOutput()
	assert.NoError(t, err)

	// Create a test file
	testFile := filepath.Join(tempDir, "test.txt")
	err = os.WriteFile(testFile, []byte("test content"), 0644)
	assert.NoError(t, err)

	// Create a basic commit for the initial state
	cmd = exec.Command("git", "config", "user.email", "test@example.com")
	_, err = cmd.CombinedOutput()
	assert.NoError(t, err)

	cmd = exec.Command("git", "config", "user.name", "Test User")
	_, err = cmd.CombinedOutput()
	assert.NoError(t, err)

	cmd = exec.Command("git", "add", ".")
	_, err = cmd.CombinedOutput()
	assert.NoError(t, err)

	cmd = exec.Command("git", "commit", "-m", "initial commit")
	_, err = cmd.CombinedOutput()
	assert.NoError(t, err)

	// Test RevertCommand
	revertCmd := &RevertCommand{}

	err = revertCmd.Execute()
	assert.NoError(t, err)
}