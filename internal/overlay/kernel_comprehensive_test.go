package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestKernelMounter_Unmount_Success_Comprehensive tests successful unmount
func TestKernelMounter_Unmount_Success_Comprehensive(t *testing.T) {
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

// TestKernelMounter_Unmount_Nil tests unmount with nil mount
func TestKernelMounter_Unmount_Nil(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Unmount(nil)

	// Assert
	assert.NoError(t, err)
}

// TestKernelMounter_Commit_Success_Comprehensive tests successful commit
func TestKernelMounter_Commit_Success_Comprehensive(t *testing.T) {
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
}

// TestKernelMounter_Commit_Nil tests commit with nil mount
func TestKernelMounter_Commit_Nil(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Commit(nil)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot commit nil mount")
}

// TestKernelMounter_Discard_Success_Comprehensive tests successful discard
func TestKernelMounter_Discard_Success_Comprehensive(t *testing.T) {
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
}

// TestKernelMounter_Discard_Nil tests discard with nil mount
func TestKernelMounter_Discard_Nil(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Discard(nil)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot discard nil mount")
}

// TestKernelMounter_Commit_Discard_Nil tests that both commit and discard with nil mounts return appropriate errors
func TestKernelMounter_Commit_Discard_Nil(t *testing.T) {
	k := NewKernelMounter()

	// Test commit with nil
	err := k.Commit(nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot commit nil mount")

	// Test discard with nil
	err = k.Discard(nil)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot discard nil mount")
}

// TestKernelMounter_isWhiteout tests the isWhiteout helper function
func TestKernelMounter_isWhiteout(t *testing.T) {
	// We can't easily test this without actually creating a whiteout file,
	// but we can at least test that the function exists and doesn't panic

	// Test with a regular file
	regularFile := filepath.Join(t.TempDir(), "regular.txt")
	err := os.WriteFile(regularFile, []byte("test"), 0644)
	assert.NoError(t, err)

	// Get file info
	info, err := os.Stat(regularFile)
	assert.NoError(t, err)

	// Should return false for regular file
	result := isWhiteout(info)
	assert.False(t, result)
}

// TestKernelMounter_copyFile tests the copyFile helper function
func TestKernelMounter_copyFile(t *testing.T) {
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
