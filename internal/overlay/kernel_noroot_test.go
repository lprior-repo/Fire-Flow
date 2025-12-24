package overlay

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ============================================================================
// Mount Error Path Tests (NO ROOT REQUIRED)
// These tests verify error handling in Mount() before the syscall is made
// ============================================================================

// TestKernelMounter_Mount_LowerDirNotExists_NoRoot tests mount fails with non-existent lower dir
func TestKernelMounter_Mount_LowerDirNotExists_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  "/non/existent/path/that/definitely/does/not/exist",
		UpperDir:  "/tmp/test-upper",
		WorkDir:   "/tmp/test-work",
		MergedDir: "/tmp/test-merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "lowerdir not found")
}

// TestKernelMounter_Mount_LowerDirIsFile_NoRoot tests mount fails when lower dir is a file
func TestKernelMounter_Mount_LowerDirIsFile_NoRoot(t *testing.T) {
	// Create a regular file instead of directory
	tempFile := filepath.Join(t.TempDir(), "file-not-dir")
	err := os.WriteFile(tempFile, []byte("test content"), 0644)
	require.NoError(t, err)

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  tempFile,
		UpperDir:  "/tmp/test-upper",
		WorkDir:   "/tmp/test-work",
		MergedDir: "/tmp/test-merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "lowerdir must be directory")
}

// TestKernelMounter_Mount_UpperDirCreationFails_NoRoot tests mount fails when upper dir can't be created
func TestKernelMounter_Mount_UpperDirCreationFails_NoRoot(t *testing.T) {
	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Try to create upper dir in a non-existent parent that we can't create
	// Use /proc/1 which exists but we can't write to
	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/proc/1/nonexistent-upper", // Can't create dirs here
		WorkDir:   "/tmp/test-work",
		MergedDir: "/tmp/test-merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "failed to create upperdir")
}

// TestKernelMounter_Mount_WorkDirCreationFails_NoRoot tests mount fails when work dir can't be created
func TestKernelMounter_Mount_WorkDirCreationFails_NoRoot(t *testing.T) {
	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Upper dir can be created in temp
	upperDir := filepath.Join(tempDir, "upper")

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   "/proc/1/nonexistent-work", // Can't create dirs here
		MergedDir: "/tmp/test-merged",
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "failed to create workdir")

	// Verify cleanup: upper dir should be removed
	_, statErr := os.Stat(upperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be cleaned up on failure")
}

// TestKernelMounter_Mount_MergedDirCreationFails_NoRoot tests mount fails when merged dir can't be created
func TestKernelMounter_Mount_MergedDirCreationFails_NoRoot(t *testing.T) {
	// Create valid lower directory
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Upper and work dirs can be created in temp
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")

	k := NewKernelMounter()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: "/proc/1/nonexistent-merged", // Can't create dirs here
	}

	// Act
	mount, err := k.Mount(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "failed to create mergeddir")

	// Verify cleanup: upper and work dirs should be removed
	_, statErr := os.Stat(upperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be cleaned up on failure")
	_, statErr = os.Stat(workDir)
	assert.True(t, os.IsNotExist(statErr), "Work dir should be cleaned up on failure")
}

// ============================================================================
// Unmount Tests (NO ROOT REQUIRED - testing behavior not syscalls)
// ============================================================================

// TestKernelMounter_Unmount_NilMount_NoRoot tests unmount with nil is safe
func TestKernelMounter_Unmount_NilMount_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Unmount(nil)

	// Assert - should be safe to call with nil
	assert.NoError(t, err)
}

// TestKernelMounter_Unmount_NonExistentMount_NoRoot tests unmount with non-mounted path
func TestKernelMounter_Unmount_NonExistentMount_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	// Create a mount struct that was never actually mounted
	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  "/tmp/nonexistent-lower",
			UpperDir:  "/tmp/nonexistent-upper",
			WorkDir:   "/tmp/nonexistent-work",
			MergedDir: "/tmp/nonexistent-merged",
		},
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}

	// Act - unmount should handle non-existent paths gracefully
	err := k.Unmount(mount)

	// Assert - returns nil even for non-mounted paths (best effort cleanup)
	assert.NoError(t, err)
}

// ============================================================================
// Commit Tests (NO ROOT REQUIRED - testing file operations)
// ============================================================================

// TestKernelMounter_Commit_NilMount_NoRoot tests commit with nil returns error
func TestKernelMounter_Commit_NilMount_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Commit(nil)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot commit nil mount")
}

// TestKernelMounter_Commit_EmptyUpperDir_NoRoot tests commit with empty upper dir
func TestKernelMounter_Commit_EmptyUpperDir_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	tempDir := t.TempDir()

	// Create empty upper and lower directories
	upperDir := filepath.Join(tempDir, "upper")
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(upperDir, 0755)
	require.NoError(t, err)
	err = os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  lowerDir,
			UpperDir:  upperDir,
			WorkDir:   filepath.Join(tempDir, "work"),
			MergedDir: filepath.Join(tempDir, "merged"),
		},
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}

	// Act
	err = k.Commit(mount)

	// Assert - should succeed with no files to copy
	assert.NoError(t, err)
}

// TestKernelMounter_Commit_WithFiles_NoRoot tests commit copies files from upper to lower
func TestKernelMounter_Commit_WithFiles_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	tempDir := t.TempDir()

	// Create upper and lower directories
	upperDir := filepath.Join(tempDir, "upper")
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(upperDir, 0755)
	require.NoError(t, err)
	err = os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Create a file in upper directory
	testContent := []byte("test file content")
	err = os.WriteFile(filepath.Join(upperDir, "test.txt"), testContent, 0644)
	require.NoError(t, err)

	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  lowerDir,
			UpperDir:  upperDir,
			WorkDir:   filepath.Join(tempDir, "work"),
			MergedDir: filepath.Join(tempDir, "merged"),
		},
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}

	// Act
	err = k.Commit(mount)

	// Assert
	assert.NoError(t, err)

	// Verify file was copied to lower
	content, err := os.ReadFile(filepath.Join(lowerDir, "test.txt"))
	assert.NoError(t, err)
	assert.Equal(t, testContent, content)
}

// TestKernelMounter_Commit_WithNestedDirs_NoRoot tests commit copies nested directories
func TestKernelMounter_Commit_WithNestedDirs_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	tempDir := t.TempDir()

	// Create upper and lower directories
	upperDir := filepath.Join(tempDir, "upper")
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(upperDir, 0755)
	require.NoError(t, err)
	err = os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Create nested structure in upper
	nestedDir := filepath.Join(upperDir, "subdir", "nested")
	err = os.MkdirAll(nestedDir, 0755)
	require.NoError(t, err)
	err = os.WriteFile(filepath.Join(nestedDir, "deep.txt"), []byte("deep content"), 0644)
	require.NoError(t, err)

	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  lowerDir,
			UpperDir:  upperDir,
			WorkDir:   filepath.Join(tempDir, "work"),
			MergedDir: filepath.Join(tempDir, "merged"),
		},
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}

	// Act
	err = k.Commit(mount)

	// Assert
	assert.NoError(t, err)

	// Verify nested structure was created in lower
	content, err := os.ReadFile(filepath.Join(lowerDir, "subdir", "nested", "deep.txt"))
	assert.NoError(t, err)
	assert.Equal(t, []byte("deep content"), content)
}

// TestKernelMounter_Commit_PreservesPermissions_NoRoot tests commit preserves file permissions
func TestKernelMounter_Commit_PreservesPermissions_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	tempDir := t.TempDir()

	upperDir := filepath.Join(tempDir, "upper")
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(upperDir, 0755)
	require.NoError(t, err)
	err = os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	// Create file with specific permissions
	testFile := filepath.Join(upperDir, "executable.sh")
	err = os.WriteFile(testFile, []byte("#!/bin/bash"), 0755)
	require.NoError(t, err)

	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir: lowerDir,
			UpperDir: upperDir,
		},
	}

	// Act
	err = k.Commit(mount)

	// Assert
	assert.NoError(t, err)

	// Verify permissions
	info, err := os.Stat(filepath.Join(lowerDir, "executable.sh"))
	assert.NoError(t, err)
	assert.Equal(t, os.FileMode(0755), info.Mode().Perm())
}

// ============================================================================
// Discard Tests (NO ROOT REQUIRED)
// ============================================================================

// TestKernelMounter_Discard_NilMount_NoRoot tests discard with nil returns error
func TestKernelMounter_Discard_NilMount_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	// Act
	err := k.Discard(nil)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "cannot discard nil mount")
}

// TestKernelMounter_Discard_RemovesUpperDir_NoRoot tests discard removes upper directory
func TestKernelMounter_Discard_RemovesUpperDir_NoRoot(t *testing.T) {
	k := NewKernelMounter()
	tempDir := t.TempDir()

	upperDir := filepath.Join(tempDir, "upper")
	err := os.MkdirAll(upperDir, 0755)
	require.NoError(t, err)

	// Create some files in upper
	err = os.WriteFile(filepath.Join(upperDir, "file1.txt"), []byte("content1"), 0644)
	require.NoError(t, err)
	err = os.WriteFile(filepath.Join(upperDir, "file2.txt"), []byte("content2"), 0644)
	require.NoError(t, err)

	mount := &OverlayMount{
		Config: MountConfig{
			UpperDir: upperDir,
		},
	}

	// Act
	err = k.Discard(mount)

	// Assert
	assert.NoError(t, err)

	// Verify upper dir was removed
	_, statErr := os.Stat(upperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be removed after discard")
}

// TestKernelMounter_Discard_NonExistentUpperDir_NoRoot tests discard with non-existent upper dir
func TestKernelMounter_Discard_NonExistentUpperDir_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	mount := &OverlayMount{
		Config: MountConfig{
			UpperDir: "/nonexistent/upper/dir",
		},
	}

	// Act
	err := k.Discard(mount)

	// Assert - should succeed even if dir doesn't exist
	assert.NoError(t, err)
}

// ============================================================================
// copyFile Tests (NO ROOT REQUIRED)
// ============================================================================

// TestCopyFile_Success_NoRoot tests successful file copy
func TestCopyFile_Success_NoRoot(t *testing.T) {
	tempDir := t.TempDir()

	srcFile := filepath.Join(tempDir, "source.txt")
	dstFile := filepath.Join(tempDir, "dest.txt")

	content := []byte("file content for copy test")
	err := os.WriteFile(srcFile, content, 0644)
	require.NoError(t, err)

	// Act
	err = copyFile(srcFile, dstFile)

	// Assert
	assert.NoError(t, err)

	// Verify content
	copied, err := os.ReadFile(dstFile)
	assert.NoError(t, err)
	assert.Equal(t, content, copied)
}

// TestCopyFile_SourceNotFound_NoRoot tests copy with non-existent source
func TestCopyFile_SourceNotFound_NoRoot(t *testing.T) {
	tempDir := t.TempDir()
	dstFile := filepath.Join(tempDir, "dest.txt")

	// Act
	err := copyFile("/nonexistent/source", dstFile)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "open source")
}

// TestCopyFile_DestDirNotExists_NoRoot tests copy when dest dir doesn't exist
func TestCopyFile_DestDirNotExists_NoRoot(t *testing.T) {
	tempDir := t.TempDir()

	srcFile := filepath.Join(tempDir, "source.txt")
	err := os.WriteFile(srcFile, []byte("content"), 0644)
	require.NoError(t, err)

	// Dest in non-existent directory
	dstFile := filepath.Join(tempDir, "nonexistent", "dest.txt")

	// Act
	err = copyFile(srcFile, dstFile)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "create destination")
}

// TestCopyFile_LargeFile_NoRoot tests copying a larger file
func TestCopyFile_LargeFile_NoRoot(t *testing.T) {
	tempDir := t.TempDir()

	srcFile := filepath.Join(tempDir, "large.txt")
	dstFile := filepath.Join(tempDir, "large-copy.txt")

	// Create ~100KB file
	content := make([]byte, 100*1024)
	for i := range content {
		content[i] = byte(i % 256)
	}
	err := os.WriteFile(srcFile, content, 0644)
	require.NoError(t, err)

	// Act
	err = copyFile(srcFile, dstFile)

	// Assert
	assert.NoError(t, err)

	copied, err := os.ReadFile(dstFile)
	assert.NoError(t, err)
	assert.Equal(t, content, copied)
}

// ============================================================================
// isWhiteout Tests (NO ROOT REQUIRED - testing logic not real whiteouts)
// ============================================================================

// TestIsWhiteout_RegularFile_NoRoot tests isWhiteout returns false for regular file
func TestIsWhiteout_RegularFile_NoRoot(t *testing.T) {
	tempDir := t.TempDir()
	file := filepath.Join(tempDir, "regular.txt")
	err := os.WriteFile(file, []byte("content"), 0644)
	require.NoError(t, err)

	info, err := os.Stat(file)
	require.NoError(t, err)

	// Act
	result := isWhiteout(info)

	// Assert
	assert.False(t, result)
}

// TestIsWhiteout_Directory_NoRoot tests isWhiteout returns false for directory
func TestIsWhiteout_Directory_NoRoot(t *testing.T) {
	tempDir := t.TempDir()

	info, err := os.Stat(tempDir)
	require.NoError(t, err)

	// Act
	result := isWhiteout(info)

	// Assert
	assert.False(t, result)
}

// TestIsWhiteout_Symlink_NoRoot tests isWhiteout returns false for symlink
func TestIsWhiteout_Symlink_NoRoot(t *testing.T) {
	tempDir := t.TempDir()
	target := filepath.Join(tempDir, "target.txt")
	link := filepath.Join(tempDir, "link")

	err := os.WriteFile(target, []byte("target"), 0644)
	require.NoError(t, err)
	err = os.Symlink(target, link)
	require.NoError(t, err)

	info, err := os.Lstat(link)
	require.NoError(t, err)

	// Act
	result := isWhiteout(info)

	// Assert
	assert.False(t, result)
}

// ============================================================================
// KernelMounter Concurrency Tests (NO ROOT REQUIRED)
// ============================================================================

// TestKernelMounter_NewKernelMounter_NoRoot tests mounter creation
func TestKernelMounter_NewKernelMounter_NoRoot(t *testing.T) {
	k := NewKernelMounter()

	assert.NotNil(t, k)
	assert.NotNil(t, k.activeMounts)
}

// TestKernelMounter_MultipleMounterInstances_NoRoot tests multiple mounter instances
func TestKernelMounter_MultipleMounterInstances_NoRoot(t *testing.T) {
	k1 := NewKernelMounter()
	k2 := NewKernelMounter()

	assert.NotNil(t, k1)
	assert.NotNil(t, k2)
	// Each should have its own map (different pointers)
	assert.NotSame(t, k1, k2)
}
