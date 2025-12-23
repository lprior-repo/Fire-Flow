package overlay

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestOverlayManager_Mount(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-test")
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
	
	// Verify mount was created
	assert.True(t, mount.MountedAt.Before(now()))
}

func TestOverlayManager_Unmount(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Mount first
	mount, err := manager.Mount(tempDir)
	assert.NoError(t, err)

	// Unmount
	err = manager.Unmount(mount)
	assert.NoError(t, err)
}

func TestOverlayManager_Commit(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Mount first
	mount, err := manager.Mount(tempDir)
	assert.NoError(t, err)

	// Commit
	err = manager.Commit(mount)
	assert.NoError(t, err)
}

func TestOverlayManager_Discard(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Mount first
	mount, err := manager.Mount(tempDir)
	assert.NoError(t, err)

	// Discard
	err = manager.Discard(mount)
	assert.NoError(t, err)
}

func TestOverlayManager_GetMountInfo(t *testing.T) {
	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Mount first
	mount, err := manager.Mount(tempDir)
	assert.NoError(t, err)

	// Get info
	info := manager.GetMountInfo(mount)
	assert.Contains(t, info, "Mount: ")
	assert.Contains(t, info, "Lower: ")
	assert.Contains(t, info, "Upper: ")
	assert.Contains(t, info, "Work: ")
	assert.Contains(t, info, "Merged: ")
	assert.Contains(t, info, "Mounted At: ")
}

func TestOverlayManager_GetMountInfoNil(t *testing.T) {
	// Create manager with fake mounter
	manager := NewOverlayManager(NewFakeMounter())

	// Get info for nil mount
	info := manager.GetMountInfo(nil)
	assert.Equal(t, "No mount active", info)
}

// Helper to get current time for comparison
func now() time.Time {
	return time.Now()
}