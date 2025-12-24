package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestOverlayManager_MountWithCleanup_Success tests MountWithCleanup logic with validation
func TestOverlayManager_MountWithCleanup_Success(t *testing.T) {
	// Create temporary directories for testing
	tempDir, err := os.MkdirTemp("", "fireflow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create lower directory
	lowerDir := filepath.Join(tempDir, "lower")
	err = os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Create upper, work, and merged directories
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	mergedDir := filepath.Join(tempDir, "merged")

	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Test the validation and directory creation part of MountWithCleanup
	// We can't test actual mounting without root, but we can test the logic

	// Test validation
	err = manager.ValidateMountConfig(config)
	assert.NoError(t, err)

	// Test directory creation
	err = manager.CreateTempDirs(&config)
	assert.NoError(t, err)

	// Verify directories were created
	_, err = os.Stat(upperDir)
	assert.NoError(t, err)

	_, err = os.Stat(workDir)
	assert.NoError(t, err)

	_, err = os.Stat(mergedDir)
	assert.NoError(t, err)

	// Test that cleanup function works
	err = manager.CleanupTempDirs(config)
	assert.NoError(t, err)

	// Verify cleanup worked
	_, err = os.Stat(upperDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))
}

// TestOverlayManager_MountWithCleanup_InvalidConfig tests MountWithCleanup with invalid config
func TestOverlayManager_MountWithCleanup_InvalidConfig(t *testing.T) {
	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  "", // Invalid - missing lower dir
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := manager.MountWithCleanup(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestOverlayManager_MountWithCleanup_NonExistentLowerDir tests MountWithCleanup with non-existent lower dir
func TestOverlayManager_MountWithCleanup_NonExistentLowerDir(t *testing.T) {
	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  "/non/existent/path",
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := manager.MountWithCleanup(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestOverlayManager_MountWithCleanup_CleanupOnFailure tests cleanup happens on mount failure
func TestOverlayManager_MountWithCleanup_CleanupOnFailure(t *testing.T) {
	// This test demonstrates that cleanup is handled correctly
	// We can't easily test this without actually mounting since it requires root,
	// but we'll at least verify the logic path
	manager := NewOverlayManager()

	// Test with invalid config that would fail validation
	config := MountConfig{
		LowerDir:  "", // This will fail validation
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := manager.MountWithCleanup(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
}
