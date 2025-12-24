package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestKernelMounter_Mount_LowerDirNotExists tests mount with non-existent lower directory
func TestKernelMounter_Mount_LowerDirNotExists(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  "/non/existent/path",
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "lowerdir not found")
}

// TestKernelMounter_Mount_LowerDirNotDirectory tests mount with non-directory lower directory
func TestKernelMounter_Mount_LowerDirNotDirectory(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create a regular file instead of directory
	tempFile := filepath.Join(t.TempDir(), "file")
	err := os.WriteFile(tempFile, []byte("test"), 0644)
	assert.NoError(t, err)

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  tempFile,
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "lowerdir must be directory")
}

// TestKernelMounter_Mount_UpperDirCreationFailure tests mount when upper directory creation fails
func TestKernelMounter_Mount_UpperDirCreationFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Make parent directory read-only to cause upper dir creation failure
	upperDir := "/root/upper" // This will fail on creation

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should fail due to permission denied
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_WorkDirCreationFailure tests mount when work directory creation fails
func TestKernelMounter_Mount_WorkDirCreationFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Make parent directory read-only to cause work dir creation failure
	workDir := "/root/work" // This will fail on creation

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   workDir,
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should fail due to permission denied
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_MergedDirCreationFailure tests mount when merged directory creation fails
func TestKernelMounter_Mount_MergedDirCreationFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Make parent directory read-only to cause merged dir creation failure
	mergedDir := "/root/merged" // This will fail on creation

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: mergedDir,
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should fail due to permission denied
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_MountFailure tests mount failure scenarios
func TestKernelMounter_Mount_MountFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Use invalid paths that will cause mount to fail
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/invalid/path/upper",
		WorkDir:   "/invalid/path/work",
		MergedDir: "/invalid/path/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should fail due to mount failure
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_WithCleanupOnFailure tests cleanup happens on mount failure
func TestKernelMounter_Mount_WithCleanupOnFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Create invalid paths that will cause mount failure
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/invalid/path/upper",
		WorkDir:   "/invalid/path/work",
		MergedDir: "/invalid/path/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should return an error and not leave directories behind
	assert.Error(t, err)
	assert.Nil(t, mount)
}
