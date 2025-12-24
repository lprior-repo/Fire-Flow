package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestMountWithCleanup_CompleteFlow tests the complete MountWithCleanup flow with valid config
func TestMountWithCleanup_CompleteFlow(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directories for testing
	tempDir := t.TempDir()

	// Create lower directory
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Test validation first
	err = manager.ValidateMountConfig(config)
	assert.NoError(t, err)

	// Test directory creation
	err = manager.CreateTempDirs(&config)
	assert.NoError(t, err)

	// Test cleanup
	err = manager.CleanupTempDirs(config)
	assert.NoError(t, err)
}

// TestMountWithCleanup_ValidationOnly tests only validation logic
func TestMountWithCleanup_ValidationOnly(t *testing.T) {
	manager := NewOverlayManager()

	// Test with missing lower dir
	config := MountConfig{
		LowerDir:  "",
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "lowerdir required")
}

// TestMountWithCleanup_CreateTempDirsOnly tests only temp directory creation
func TestMountWithCleanup_CreateTempDirsOnly(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directory for testing
	tempDir := t.TempDir()

	// Test with valid config
	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err := manager.CreateTempDirs(&config)

	// Assert
	assert.NoError(t, err)

	// Verify directories were created
	info, err := os.Stat(config.UpperDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())

	info, err = os.Stat(config.WorkDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())

	info, err = os.Stat(config.MergedDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())
}

// TestMountWithCleanup_CleanupOnly tests only cleanup functionality
func TestMountWithCleanup_CleanupOnly(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directory for testing
	tempDir := t.TempDir()

	// Create some directories
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	mergedDir := filepath.Join(tempDir, "merged")

	// Create directories
	err := os.MkdirAll(upperDir, 0755)
	assert.NoError(t, err)
	err = os.MkdirAll(workDir, 0755)
	assert.NoError(t, err)
	err = os.MkdirAll(mergedDir, 0755)
	assert.NoError(t, err)

	config := MountConfig{
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Act
	err = manager.CleanupTempDirs(config)

	// Assert
	assert.NoError(t, err)

	// Verify cleanup worked
	_, err = os.Stat(upperDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(workDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(mergedDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))
}
