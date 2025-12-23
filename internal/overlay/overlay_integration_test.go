package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Integration test for the overlay manager
func TestOverlayManager_Integration(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-overlay-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create a test file in the lower directory
	testFile := filepath.Join(tempDir, "test.txt")
	err = os.WriteFile(testFile, []byte("test content"), 0644)
	assert.NoError(t, err)

	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Mount
	mount, err := manager.Mount(tempDir)
	assert.NoError(t, err)
	assert.NotNil(t, mount)

	// Verify mount configuration
	assert.Equal(t, tempDir, mount.Config.LowerDir)
	assert.NotEmpty(t, mount.Config.UpperDir)
	assert.NotEmpty(t, mount.Config.WorkDir)
	assert.NotEmpty(t, mount.Config.MergedDir)

	// Test that we can commit and discard without errors
	err = manager.Commit(mount)
	assert.NoError(t, err)

	err = manager.Discard(mount)
	assert.NoError(t, err)

	// Test unmounting
	err = manager.Unmount(mount)
	assert.NoError(t, err)
}