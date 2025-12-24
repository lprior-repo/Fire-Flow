package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestKernelMounter_Mount_Success tests successful mount
func TestKernelMounter_Mount_Success(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create temp directories
	tmpDir := t.TempDir()
	lowerDir := filepath.Join(tmpDir, "lower")
	upperDir := filepath.Join(tmpDir, "upper")
	workDir := filepath.Join(tmpDir, "work")
	mergedDir := filepath.Join(tmpDir, "merged")

	// Create lower directory with some content
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)
	err = os.WriteFile(filepath.Join(lowerDir, "test.txt"), []byte("test"), 0644)
	assert.NoError(t, err)

	// Create mounter and config
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, mount)
	assert.Equal(t, config, mount.Config)
	assert.NotEqual(t, mount.MountedAt, mount.Config.MergedDir)

	// Cleanup
	err = k.Unmount(mount)
	assert.NoError(t, err)
}

// TestKernelMounter_Mount_Failures tests various mount failure cases
func TestKernelMounter_Mount_Failures(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Test with non-existent lower directory
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
}

// TestKernelMounter_Unmount_Success tests successful unmount
func TestKernelMounter_Unmount_Success(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create temp directories
	tmpDir := t.TempDir()
	lowerDir := filepath.Join(tmpDir, "lower")
	upperDir := filepath.Join(tmpDir, "upper")
	workDir := filepath.Join(tmpDir, "work")
	mergedDir := filepath.Join(tmpDir, "merged")

	// Create lower directory with some content
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)
	err = os.WriteFile(filepath.Join(lowerDir, "test.txt"), []byte("test"), 0644)
	assert.NoError(t, err)

	// Create mounter and config
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Mount first
	mount, err := k.Mount(config)
	assert.NoError(t, err)
	assert.NotNil(t, mount)

	// Act
	err = k.Unmount(mount)

	// Assert
	assert.NoError(t, err)
}

// TestKernelMounter_Commit_Success tests successful commit
func TestKernelMounter_Commit_Success(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create temp directories
	tmpDir := t.TempDir()
	lowerDir := filepath.Join(tmpDir, "lower")
	upperDir := filepath.Join(tmpDir, "upper")
	workDir := filepath.Join(tmpDir, "work")
	mergedDir := filepath.Join(tmpDir, "merged")

	// Create lower directory with some content
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)
	err = os.WriteFile(filepath.Join(lowerDir, "test.txt"), []byte("test"), 0644)
	assert.NoError(t, err)

	// Create mounter and config
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Mount first
	mount, err := k.Mount(config)
	assert.NoError(t, err)
	assert.NotNil(t, mount)

	// Write a file to the upper layer
	testFile := filepath.Join(upperDir, "new_file.txt")
	err = os.WriteFile(testFile, []byte("new content"), 0644)
	assert.NoError(t, err)

	// Act
	err = k.Commit(mount)

	// Assert
	assert.NoError(t, err)

	// Verify file was committed
	committedFile := filepath.Join(lowerDir, "new_file.txt")
	_, err = os.Stat(committedFile)
	assert.NoError(t, err)

	// Cleanup
	err = k.Unmount(mount)
	assert.NoError(t, err)
}

// TestKernelMounter_Discard_Success tests successful discard
func TestKernelMounter_Discard_Success(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create temp directories
	tmpDir := t.TempDir()
	lowerDir := filepath.Join(tmpDir, "lower")
	upperDir := filepath.Join(tmpDir, "upper")
	workDir := filepath.Join(tmpDir, "work")
	mergedDir := filepath.Join(tmpDir, "merged")

	// Create lower directory with some content
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)
	err = os.WriteFile(filepath.Join(lowerDir, "test.txt"), []byte("test"), 0644)
	assert.NoError(t, err)

	// Create mounter and config
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Mount first
	mount, err := k.Mount(config)
	assert.NoError(t, err)
	assert.NotNil(t, mount)

	// Write a file to the upper layer
	testFile := filepath.Join(upperDir, "new_file.txt")
	err = os.WriteFile(testFile, []byte("new content"), 0644)
	assert.NoError(t, err)

	// Act
	err = k.Discard(mount)

	// Assert
	assert.NoError(t, err)

	// Verify file was discarded
	discardedFile := filepath.Join(upperDir, "new_file.txt")
	_, err = os.Stat(discardedFile)
	assert.Error(t, err)

	// Cleanup
	err = k.Unmount(mount)
	assert.NoError(t, err)
}

// TestKernelMounter_InterfaceImplementation tests that KernelMounter implements Mounter interface
func TestKernelMounter_InterfaceImplementation(t *testing.T) {
	var _ Mounter = (*KernelMounter)(nil)
	// If KernelMounter doesn't implement Mounter, compilation fails
}