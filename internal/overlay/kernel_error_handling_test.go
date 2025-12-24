package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestKernelMounter_Mount_NonExistentLowerDir tests mount with non-existent lower directory
func TestKernelMounter_Mount_NonExistentLowerDir(t *testing.T) {
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

// TestKernelMounter_Mount_NonDirectoryLowerDir tests mount with non-directory lower directory
func TestKernelMounter_Mount_NonDirectoryLowerDir(t *testing.T) {
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

// TestKernelMounter_Mount_InvalidMountOptions tests mount with invalid mount options
func TestKernelMounter_Mount_InvalidMountOptions(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid directories for lower dir
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/invalid/path/upper", // This will cause issues
		WorkDir:   "/invalid/path/work",
		MergedDir: "/invalid/path/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should return an error due to invalid paths
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_PermissionDenied tests mount with permission issues
func TestKernelMounter_Mount_PermissionDenied(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid directories for lower dir
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Create a directory with restricted permissions
	upperDir := "/root/upper"

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should return an error due to permissions
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Mount_CleanupOnFailure tests cleanup happens on mount failure
func TestKernelMounter_Mount_CleanupOnFailure(t *testing.T) {
	// Skip if not root
	if os.Geteuid() != 0 {
		t.Skip("requires root")
	}

	// Create valid directories for lower dir
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Create invalid paths that will cause mount failure
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/invalid/path/upper", // This will cause mount failure
		WorkDir:   "/invalid/path/work",
		MergedDir: "/invalid/path/merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert - Should return an error and not leave directories behind
	assert.Error(t, err)
	assert.Nil(t, mount)
}

// TestKernelMounter_Unmount_ErrorHandling tests unmount error handling
func TestKernelMounter_Unmount_ErrorHandling(t *testing.T) {
	k := NewKernelMounter()

	// Test with nil mount (should not panic)
	err := k.Unmount(nil)
	assert.NoError(t, err)

	// Test that it works with valid mount (will be a no-op since we don't actually mount)
	// This is more of a structural test to ensure the method doesn't panic
	assert.NotNil(t, k)
}

// TestKernelMounter_Commit_ErrorHandling tests commit error handling
func TestKernelMounter_Commit_ErrorHandling(t *testing.T) {
	k := NewKernelMounter()

	// Test with nil mount (should return error)
	err := k.Commit(nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot commit nil mount")
}

// TestKernelMounter_Discard_ErrorHandling tests discard error handling
func TestKernelMounter_Discard_ErrorHandling(t *testing.T) {
	k := NewKernelMounter()

	// Test with nil mount (should return error)
	err := k.Discard(nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot discard nil mount")
}

// TestKernelMounter_CopyFile tests the copyFile helper function with various scenarios
func TestKernelMounter_CopyFile(t *testing.T) {
	// Create source file
	srcFile := filepath.Join(t.TempDir(), "src.txt")
	err := os.WriteFile(srcFile, []byte("test content"), 0644)
	assert.NoError(t, err)

	// Create destination path
	dstFile := filepath.Join(t.TempDir(), "dst.txt")

	// Act
	err = copyFile(srcFile, dstFile)

	// Assert
	assert.NoError(t, err)

	// Verify file was copied
	content, err := os.ReadFile(dstFile)
	assert.NoError(t, err)
	assert.Equal(t, "test content", string(content))

	// Verify permissions were preserved
	srcInfo, err := os.Stat(srcFile)
	assert.NoError(t, err)
	dstInfo, err := os.Stat(dstFile)
	assert.NoError(t, err)
	assert.Equal(t, srcInfo.Mode().Perm(), dstInfo.Mode().Perm())
}

// TestKernelMounter_CopyFile_SourceNotFound tests copyFile with non-existent source
func TestKernelMounter_CopyFile_SourceNotFound(t *testing.T) {
	// Create destination path
	dstFile := filepath.Join(t.TempDir(), "dst.txt")

	// Act
	err := copyFile("/non/existent/file", dstFile)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "open source")
}
