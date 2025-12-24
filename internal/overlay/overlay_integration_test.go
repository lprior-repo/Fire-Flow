package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// Integration test for the overlay manager
func TestOverlayManager_Integration(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-overlay-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create a test file in the lower directory
	testFile := filepath.Join(tempDir, "test.txt")
	err = os.WriteFile(testFile, []byte("test content"), 0644)
	assert.NoError(t, err)

	// Create manager
	manager := NewOverlayManager()

	// Mount using kernel mounter
	kernelMounter := manager.GetMounter("kernel")
	config := MountConfig{
		LowerDir:  tempDir,
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}
	mount, err := kernelMounter.Mount(config)
	assert.NoError(t, err)
	assert.NotNil(t, mount)

	// Verify mount configuration
	assert.Equal(t, tempDir, mount.Config.LowerDir)
	assert.NotEmpty(t, mount.Config.UpperDir)
	assert.NotEmpty(t, mount.Config.WorkDir)
	assert.NotEmpty(t, mount.Config.MergedDir)

	// Test that we can commit and discard without errors
	err = kernelMounter.Commit(mount)
	assert.NoError(t, err)

	err = kernelMounter.Discard(mount)
	assert.NoError(t, err)

	// Test unmounting
	err = kernelMounter.Unmount(mount)
	assert.NoError(t, err)
}
