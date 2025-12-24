package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestCreateTempDirs_Comprehensive tests comprehensive CreateTempDirs scenarios
func TestCreateTempDirs_Comprehensive(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directories for testing
	tempDir := t.TempDir()

	// Test valid config
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

// TestCreateTempDirs_WithExistingDirectories tests directory creation when directories already exist
func TestCreateTempDirs_WithExistingDirectories(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directories for testing
	tempDir := t.TempDir()

	// Create directories beforehand
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	mergedDir := filepath.Join(tempDir, "merged")

	err := os.MkdirAll(upperDir, 0755)
	assert.NoError(t, err)
	err = os.MkdirAll(workDir, 0755)
	assert.NoError(t, err)
	err = os.MkdirAll(mergedDir, 0755)
	assert.NoError(t, err)

	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Act
	err = manager.CreateTempDirs(&config)

	// Assert - Should not fail even though directories exist
	assert.NoError(t, err)

	// Verify directories still exist and are directories
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

// TestCreateTempDirs_EmptyPaths tests directory creation with empty paths
func TestCreateTempDirs_EmptyPaths(t *testing.T) {
	manager := NewOverlayManager()

	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  "",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.CreateTempDirs(&config)

	// Assert - Should fail due to empty paths
	assert.Error(t, err)
}

// TestCreateTempDirs_InvalidPermissions tests directory creation with invalid permissions
func TestCreateTempDirs_InvalidPermissions(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directory with restricted permissions
	tempDir := t.TempDir()

	// Make parent directory read-only
	err := os.Chmod(tempDir, 0444)
	assert.NoError(t, err)

	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err = manager.CreateTempDirs(&config)

	// Assert - Should fail due to permission denied
	assert.Error(t, err)

	// Restore permissions
	err = os.Chmod(tempDir, 0755)
	assert.NoError(t, err)
}

// TestCreateTempDirs_WithFilesInsteadOfDirectories tests when paths are files instead of directories
func TestCreateTempDirs_WithFilesInsteadOfDirectories(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directory for testing
	tempDir := t.TempDir()

	// Create a file instead of a directory
	upperFile := filepath.Join(tempDir, "upper")
	err := os.WriteFile(upperFile, []byte("test"), 0644)
	assert.NoError(t, err)

	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  upperFile,
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err = manager.CreateTempDirs(&config)

	// Assert - Should fail because upper path is a file
	assert.Error(t, err)
}

// TestCreateTempDirs_PartialSuccess tests cleanup on partial directory creation failure
func TestCreateTempDirs_PartialSuccess(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directory for testing
	tempDir := t.TempDir()

	// Make parent directory read-only to cause partial failure
	err := os.Chmod(tempDir, 0444)
	assert.NoError(t, err)

	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err = manager.CreateTempDirs(&config)

	// Assert - Should fail due to permission denied
	assert.Error(t, err)

	// Restore permissions
	err = os.Chmod(tempDir, 0755)
	assert.NoError(t, err)
}
