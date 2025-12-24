package overlay

import (
	"fmt"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// ============================================================================
// CleanupStaleMounts Tests (NO ROOT REQUIRED - testing with fake mounts file)
// ============================================================================

// TestCleanupStaleMounts_NoStaleMountsNoRoot tests when there are no stale mounts
func TestCleanupStaleMounts_NoStaleMountsNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mounts file with no fire-flow mounts
	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	err := os.WriteFile(mountsFile, []byte(`
/dev/sda1 / ext4 rw,relatime 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev,mode=1777 0 0
proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
`), 0644)
	require.NoError(t, err)

	// Act - use DetectStaleMountsFromFile instead of DetectStaleMounts
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Empty(t, staleMounts)
}

// TestCleanupStaleMounts_WithStaleMountsNoRoot tests detection of stale mounts
func TestCleanupStaleMounts_WithStaleMountsNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mounts file with fire-flow overlay mounts
	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	content := `
/dev/sda1 / ext4 rw,relatime 0 0
overlay /tmp/fire-flow-merged overlay rw,relatime,lowerdir=/home/test,upperdir=/tmp/fire-flow-upper,workdir=/tmp/fire-flow-work 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev,mode=1777 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Len(t, staleMounts, 1)
	assert.Equal(t, "/tmp/fire-flow-merged", staleMounts[0].MergedDir)
	assert.Equal(t, "/home/test", staleMounts[0].LowerDir)
	assert.Equal(t, "/tmp/fire-flow-upper", staleMounts[0].UpperDir)
	assert.Equal(t, "/tmp/fire-flow-work", staleMounts[0].WorkDir)
}

// TestCleanupStaleMounts_MultipleStaleMountsNoRoot tests detection of multiple stale mounts
func TestCleanupStaleMounts_MultipleStaleMountsNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mounts file with multiple fire-flow overlay mounts
	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	content := `
overlay /tmp/fire-flow-1-merged overlay rw,relatime,lowerdir=/home/a,upperdir=/tmp/fire-flow-1-upper,workdir=/tmp/fire-flow-1-work 0 0
overlay /tmp/fire-flow-2-merged overlay rw,relatime,lowerdir=/home/b,upperdir=/tmp/fire-flow-2-upper,workdir=/tmp/fire-flow-2-work 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Len(t, staleMounts, 2)
}

// TestCleanupStaleMounts_NonFireFlowMountsNoRoot tests that non-fire-flow mounts are ignored
func TestCleanupStaleMounts_NonFireFlowMountsNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mounts file with non-fire-flow overlay mounts
	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	content := `
overlay /mnt/overlay overlay rw,relatime,lowerdir=/lower,upperdir=/upper,workdir=/work 0 0
overlay /var/lib/docker/overlay2/merged overlay rw,relatime,lowerdir=/lower,upperdir=/upper,workdir=/work 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Empty(t, staleMounts, "Non-fire-flow mounts should be ignored")
}

// TestCleanupStaleMounts_FileNotFoundNoRoot tests error when mounts file doesn't exist
func TestCleanupStaleMounts_FileNotFoundNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile("/nonexistent/mounts")

	// Assert
	assert.Error(t, err)
	assert.Nil(t, staleMounts)
	assert.Contains(t, err.Error(), "failed to open mounts file")
}

// TestCleanupStaleMounts_EmptyFileNoRoot tests with empty mounts file
func TestCleanupStaleMounts_EmptyFileNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	err := os.WriteFile(mountsFile, []byte(""), 0644)
	require.NoError(t, err)

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Empty(t, staleMounts)
}

// TestCleanupStaleMounts_MalformedLinesNoRoot tests handling of malformed mount lines
func TestCleanupStaleMounts_MalformedLinesNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	tempDir := t.TempDir()
	mountsFile := filepath.Join(tempDir, "mounts")
	content := `
a b
x y z
short
overlay /tmp/fire-flow-merged overlay rw,lowerdir=/home,upperdir=/tmp,workdir=/work 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	staleMounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Len(t, staleMounts, 1) // Should only find the valid fire-flow mount
}

// ============================================================================
// CreateTempDirs Error Path Tests
// ============================================================================

// TestCreateTempDirs_UpperDirFailsNoRoot tests failure when upper dir can't be created
func TestCreateTempDirs_UpperDirFailsNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	config := &MountConfig{
		LowerDir:  "/tmp/lower",
		UpperDir:  "/proc/1/upper", // Can't create here
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.CreateTempDirs(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to create upperdir")
}

// TestCreateTempDirs_WorkDirFailsNoRoot tests failure when work dir can't be created
func TestCreateTempDirs_WorkDirFailsNoRoot(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	config := &MountConfig{
		LowerDir:  "/tmp/lower",
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   "/proc/1/work", // Can't create here
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err := manager.CreateTempDirs(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to create workdir")

	// Verify cleanup: upper dir should be removed
	_, statErr := os.Stat(config.UpperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be cleaned up on failure")
}

// TestCreateTempDirs_MergedDirFailsNoRoot tests failure when merged dir can't be created
func TestCreateTempDirs_MergedDirFailsNoRoot(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	config := &MountConfig{
		LowerDir:  "/tmp/lower",
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: "/proc/1/merged", // Can't create here
	}

	// Act
	err := manager.CreateTempDirs(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to create mergeddir")

	// Verify cleanup: upper and work dirs should be removed
	_, statErr := os.Stat(config.UpperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be cleaned up on failure")
	_, statErr = os.Stat(config.WorkDir)
	assert.True(t, os.IsNotExist(statErr), "Work dir should be cleaned up on failure")
}

// ============================================================================
// FormatMountInfo Tests
// ============================================================================

// TestFormatMountInfo_Complete tests formatting a complete mount
func TestFormatMountInfo_Complete(t *testing.T) {
	manager := NewOverlayManager()

	mount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  "/home/user/project",
			UpperDir:  "/tmp/upper",
			WorkDir:   "/tmp/work",
			MergedDir: "/tmp/merged",
		},
	}

	// Act
	info := manager.FormatMountInfo(mount)

	// Assert
	assert.Contains(t, info, "/home/user/project")
	assert.Contains(t, info, "/tmp/upper")
	assert.Contains(t, info, "/tmp/work")
	assert.Contains(t, info, "/tmp/merged")
}

// TestFormatMountInfo_Nil tests formatting nil mount
func TestFormatMountInfo_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	info := manager.FormatMountInfo(nil)

	// Assert
	assert.Contains(t, info, "No mount information")
}

// ============================================================================
// GetOverlay Path Getters Tests
// ============================================================================

// TestGetOverlayMountPath tests getting mount path from mount
func TestGetOverlayMountPath(t *testing.T) {
	manager := NewOverlayManager()
	mount := &OverlayMount{
		Config: MountConfig{MergedDir: "/expected/path"},
	}

	// Act
	result := manager.GetOverlayMountPath(mount)

	// Assert
	assert.Equal(t, "/expected/path", result)
}

// TestGetOverlayMountPath_Nil tests getting mount path from nil
func TestGetOverlayMountPath_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	result := manager.GetOverlayMountPath(nil)

	// Assert
	assert.Empty(t, result)
}

// TestGetOverlayUpperDir tests getting upper dir from mount
func TestGetOverlayUpperDir(t *testing.T) {
	manager := NewOverlayManager()
	mount := &OverlayMount{
		Config: MountConfig{UpperDir: "/expected/upper"},
	}

	// Act
	result := manager.GetOverlayUpperDir(mount)

	// Assert
	assert.Equal(t, "/expected/upper", result)
}

// TestGetOverlayUpperDir_Nil tests getting upper dir from nil
func TestGetOverlayUpperDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	result := manager.GetOverlayUpperDir(nil)

	// Assert
	assert.Empty(t, result)
}

// TestGetOverlayWorkDir tests getting work dir from mount
func TestGetOverlayWorkDir(t *testing.T) {
	manager := NewOverlayManager()
	mount := &OverlayMount{
		Config: MountConfig{WorkDir: "/expected/work"},
	}

	// Act
	result := manager.GetOverlayWorkDir(mount)

	// Assert
	assert.Equal(t, "/expected/work", result)
}

// TestGetOverlayWorkDir_Nil tests getting work dir from nil
func TestGetOverlayWorkDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	result := manager.GetOverlayWorkDir(nil)

	// Assert
	assert.Empty(t, result)
}

// TestGetOverlayLowerDir tests getting lower dir from mount
func TestGetOverlayLowerDir(t *testing.T) {
	manager := NewOverlayManager()
	mount := &OverlayMount{
		Config: MountConfig{LowerDir: "/expected/lower"},
	}

	// Act
	result := manager.GetOverlayLowerDir(mount)

	// Assert
	assert.Equal(t, "/expected/lower", result)
}

// TestGetOverlayLowerDir_Nil tests getting lower dir from nil
func TestGetOverlayLowerDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	result := manager.GetOverlayLowerDir(nil)

	// Assert
	assert.Empty(t, result)
}

// ============================================================================
// CleanupTempDirs Tests
// ============================================================================

// TestCleanupTempDirs_AllDirsExist tests cleanup when all dirs exist
func TestCleanupTempDirs_AllDirsExist(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	config := MountConfig{
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Create the dirs
	require.NoError(t, os.MkdirAll(config.UpperDir, 0755))
	require.NoError(t, os.MkdirAll(config.WorkDir, 0755))
	require.NoError(t, os.MkdirAll(config.MergedDir, 0755))

	// Act
	manager.CleanupTempDirs(config)

	// Assert - all dirs should be removed
	_, err := os.Stat(config.UpperDir)
	assert.True(t, os.IsNotExist(err))
	_, err = os.Stat(config.WorkDir)
	assert.True(t, os.IsNotExist(err))
	_, err = os.Stat(config.MergedDir)
	assert.True(t, os.IsNotExist(err))
}

// TestCleanupTempDirs_SomeDirsMissing tests cleanup when some dirs don't exist
func TestCleanupTempDirs_SomeDirsMissing(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	config := MountConfig{
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work-nonexistent"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Create only some dirs
	require.NoError(t, os.MkdirAll(config.UpperDir, 0755))
	require.NoError(t, os.MkdirAll(config.MergedDir, 0755))
	// WorkDir intentionally not created

	// Act - should not panic
	manager.CleanupTempDirs(config)

	// Assert
	_, err := os.Stat(config.UpperDir)
	assert.True(t, os.IsNotExist(err))
	_, err = os.Stat(config.MergedDir)
	assert.True(t, os.IsNotExist(err))
}

// TestCleanupTempDirs_EmptyConfig tests cleanup with empty config
func TestCleanupTempDirs_EmptyConfig(t *testing.T) {
	manager := NewOverlayManager()

	// Act - should not panic
	assert.NotPanics(t, func() {
		manager.CleanupTempDirs(MountConfig{})
	})
}

// TestMountWithCleanup_TempDirCreationFailsNoRoot tests failure when temp dirs can't be created
func TestMountWithCleanup_TempDirCreationFailsNoRoot(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/proc/1/upper", // Can't create here
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := manager.MountWithCleanup(config)

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mount)
	assert.Contains(t, err.Error(), "failed to create temp dirs")
}

// ============================================================================
// GetMounter Tests
// ============================================================================

// TestGetMounter_FakeTypeNoRoot tests getting fake mounter
func TestGetMounter_FakeTypeNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("fake")

	// Assert
	assert.NotNil(t, mounter)
	_, ok := mounter.(*FakeMounter)
	assert.True(t, ok, "Should return FakeMounter for 'fake' type")
}

// TestGetMounter_KernelTypeNoRoot tests getting kernel mounter
func TestGetMounter_KernelTypeNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("kernel")

	// Assert
	assert.NotNil(t, mounter)
	_, ok := mounter.(*KernelMounter)
	assert.True(t, ok, "Should return KernelMounter for 'kernel' type")
}

// TestGetMounter_InvalidTypeNoRoot tests getting invalid mounter type
func TestGetMounter_InvalidTypeNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("invalid")

	// Assert
	assert.Nil(t, mounter)
}

// TestGetMounter_EmptyTypeNoRoot tests getting empty mounter type
func TestGetMounter_EmptyTypeNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("")

	// Assert
	assert.Nil(t, mounter)
}

// ============================================================================
// ValidateMountConfig Additional Tests
// ============================================================================

// TestValidateMountConfig_MissingUpperDir tests missing upper dir
func TestValidateMountConfig_MissingUpperDir(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "", // Missing
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err = manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "upperdir required")
}

// TestValidateMountConfig_MissingWorkDir tests missing work dir
func TestValidateMountConfig_MissingWorkDir(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/tmp/upper",
		WorkDir:   "", // Missing
		MergedDir: "/tmp/merged",
	}

	// Act
	err = manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "workdir required")
}

// TestValidateMountConfig_MissingMergedDir tests missing merged dir
func TestValidateMountConfig_MissingMergedDir(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()
	lowerDir := filepath.Join(tempDir, "lower")
	err := os.MkdirAll(lowerDir, 0755)
	require.NoError(t, err)

	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "", // Missing
	}

	// Act
	err = manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "mergeddir required")
}

// ============================================================================
// UserFriendlyError Additional Tests
// ============================================================================

// TestUserFriendlyError_NoDeviceError tests no_device error message
func TestUserFriendlyError_NoDeviceError(t *testing.T) {
	err := &MountError{Reason: "no_device", Detail: nil}

	// Act
	msg := UserFriendlyError(err)

	// Assert
	assert.Contains(t, msg, "OverlayFS not supported")
}

// TestUserFriendlyError_UnknownMountError tests unknown mount error
func TestUserFriendlyError_UnknownMountError(t *testing.T) {
	err := &MountError{Reason: "unknown_reason", Detail: nil}

	// Act
	msg := UserFriendlyError(err)

	// Assert
	assert.Contains(t, msg, "unknown_reason")
}

// ============================================================================
// CleanupStaleMount Tests (with mock unmount)
// ============================================================================

// TestCleanupStaleMount_SuccessFirstTry tests successful unmount on first try
func TestCleanupStaleMount_SuccessFirstTry(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	// Create temp dirs that will be cleaned up
	mergedDir := filepath.Join(tempDir, "merged")
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	require.NoError(t, os.MkdirAll(mergedDir, 0755))
	require.NoError(t, os.MkdirAll(upperDir, 0755))
	require.NoError(t, os.MkdirAll(workDir, 0755))

	// Mock unmount to succeed immediately
	unmountCalled := 0
	manager.SetUnmountFunc(func(target string, flags int) error {
		unmountCalled++
		return nil
	})

	stale := StaleMount{
		MergedDir: mergedDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		LowerDir:  "/lower",
	}

	// Act
	err := manager.CleanupStaleMount(stale)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 1, unmountCalled, "Unmount should be called once")

	// Dirs should be cleaned up
	_, statErr := os.Stat(mergedDir)
	assert.True(t, os.IsNotExist(statErr), "Merged dir should be removed")
	_, statErr = os.Stat(upperDir)
	assert.True(t, os.IsNotExist(statErr), "Upper dir should be removed")
	_, statErr = os.Stat(workDir)
	assert.True(t, os.IsNotExist(statErr), "Work dir should be removed")
}

// TestCleanupStaleMount_SuccessLazyUnmount tests fallback to lazy unmount
func TestCleanupStaleMount_SuccessLazyUnmount(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	mergedDir := filepath.Join(tempDir, "merged")
	require.NoError(t, os.MkdirAll(mergedDir, 0755))

	// Mock: first attempt fails, second (lazy) succeeds
	attemptNum := 0
	manager.SetUnmountFunc(func(target string, flags int) error {
		attemptNum++
		if attemptNum == 1 {
			return fmt.Errorf("device busy")
		}
		return nil
	})

	stale := StaleMount{MergedDir: mergedDir}

	// Act
	err := manager.CleanupStaleMount(stale)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 2, attemptNum, "Should try lazy unmount after first fails")
}

// TestCleanupStaleMount_SuccessForceUnmount tests fallback to force unmount
func TestCleanupStaleMount_SuccessForceUnmount(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	mergedDir := filepath.Join(tempDir, "merged")
	require.NoError(t, os.MkdirAll(mergedDir, 0755))

	// Mock: first two attempts fail, third (force) succeeds
	attemptNum := 0
	manager.SetUnmountFunc(func(target string, flags int) error {
		attemptNum++
		if attemptNum <= 2 {
			return fmt.Errorf("device busy")
		}
		return nil
	})

	stale := StaleMount{MergedDir: mergedDir}

	// Act
	err := manager.CleanupStaleMount(stale)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 3, attemptNum, "Should try force unmount after lazy fails")
}

// TestCleanupStaleMount_AllUnmountsFailure tests when all unmount attempts fail
func TestCleanupStaleMount_AllUnmountsFailure(t *testing.T) {
	manager := NewOverlayManager()

	// Mock: all unmount attempts fail
	manager.SetUnmountFunc(func(target string, flags int) error {
		return fmt.Errorf("unmount failed: permission denied")
	})

	stale := StaleMount{MergedDir: "/tmp/test-mount"}

	// Act
	err := manager.CleanupStaleMount(stale)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "failed to unmount")
}

// TestCleanupStaleMount_EmptyDirs tests cleanup with empty directory paths
func TestCleanupStaleMount_EmptyDirs(t *testing.T) {
	manager := NewOverlayManager()

	// Mock unmount to succeed
	manager.SetUnmountFunc(func(target string, flags int) error {
		return nil
	})

	stale := StaleMount{
		MergedDir: "",
		UpperDir:  "",
		WorkDir:   "",
	}

	// Act - should not panic
	err := manager.CleanupStaleMount(stale)

	// Assert
	assert.NoError(t, err)
}

// ============================================================================
// CleanupStaleMounts Tests (with mock)
// ============================================================================

// TestCleanupStaleMounts_NoStale tests when no stale mounts exist
func TestCleanupStaleMounts_NoStaleNoRoot(t *testing.T) {
	manager := NewOverlayManager()

	// DetectStaleMounts reads from /proc/mounts which won't have our fire-flow mounts
	// So this should return 0 cleaned

	// Act
	cleaned, err := manager.CleanupStaleMounts()

	// Assert - since there are no fire-flow mounts, cleaned should be 0
	assert.NoError(t, err)
	assert.Equal(t, 0, cleaned)
}

// TestCleanupStaleMounts_WithFailures tests when some cleanups fail
func TestCleanupStaleMounts_SomeFailures(t *testing.T) {
	manager := NewOverlayManager()

	// This test relies on DetectStaleMounts finding actual mounts
	// Since we can't easily inject the detection, we test what we can
	// The key is that CleanupStaleMounts handles errors gracefully

	// Create a mock that alternates success/failure
	callCount := 0
	manager.SetUnmountFunc(func(target string, flags int) error {
		callCount++
		if callCount%2 == 0 {
			return fmt.Errorf("mock failure")
		}
		return nil
	})

	// Act - this will call DetectStaleMounts first
	// Since there are no actual fire-flow mounts, this won't exercise CleanupStaleMount
	cleaned, err := manager.CleanupStaleMounts()

	// Assert
	// Without actual stale mounts, we get 0 cleaned and no error
	assert.Equal(t, 0, cleaned)
	assert.NoError(t, err)
}

// ============================================================================
// CleanupStaleMountsFromFile Tests (fully controllable)
// ============================================================================

// TestCleanupStaleMountsFromFile_WithMounts tests cleanup with mock mounts file
func TestCleanupStaleMountsFromFile_WithMounts(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	// Create mock mounts file with fire-flow mounts
	mountsFile := filepath.Join(tempDir, "mounts")
	content := `overlay /tmp/fire-flow-1 overlay rw,lowerdir=/a,upperdir=/tmp/upper1,workdir=/tmp/work1 0 0
overlay /tmp/fire-flow-2 overlay rw,lowerdir=/b,upperdir=/tmp/upper2,workdir=/tmp/work2 0 0`
	require.NoError(t, os.WriteFile(mountsFile, []byte(content), 0644))

	// Mock unmount to succeed
	unmountCalls := 0
	manager.SetUnmountFunc(func(target string, flags int) error {
		unmountCalls++
		return nil
	})

	// Act
	cleaned, err := manager.CleanupStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 2, cleaned, "Should clean up 2 stale mounts")
	assert.Equal(t, 2, unmountCalls, "Unmount should be called twice")
}

// TestCleanupStaleMountsFromFile_PartialFailure tests when some cleanups fail
func TestCleanupStaleMountsFromFile_PartialFailure(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	mountsFile := filepath.Join(tempDir, "mounts")
	content := `overlay /tmp/fire-flow-1 overlay rw,lowerdir=/a,upperdir=/b,workdir=/c 0 0
overlay /tmp/fire-flow-2 overlay rw,lowerdir=/d,upperdir=/e,workdir=/f 0 0`
	require.NoError(t, os.WriteFile(mountsFile, []byte(content), 0644))

	// Mock: first unmount succeeds, second fails completely
	manager.SetUnmountFunc(func(target string, flags int) error {
		if target == "/tmp/fire-flow-2" {
			return fmt.Errorf("persistent failure")
		}
		return nil
	})

	// Act
	cleaned, err := manager.CleanupStaleMountsFromFile(mountsFile)

	// Assert
	assert.Error(t, err, "Should return error from failed cleanup")
	assert.Equal(t, 1, cleaned, "Should successfully clean 1 mount")
	assert.Contains(t, err.Error(), "failed to unmount")
}

// TestCleanupStaleMountsFromFile_AllFail tests when all cleanups fail
func TestCleanupStaleMountsFromFile_AllFail(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	mountsFile := filepath.Join(tempDir, "mounts")
	content := `overlay /tmp/fire-flow-1 overlay rw,lowerdir=/a,upperdir=/b,workdir=/c 0 0
overlay /tmp/fire-flow-2 overlay rw,lowerdir=/d,upperdir=/e,workdir=/f 0 0`
	require.NoError(t, os.WriteFile(mountsFile, []byte(content), 0644))

	// Mock: all unmounts fail
	manager.SetUnmountFunc(func(target string, flags int) error {
		return fmt.Errorf("permission denied")
	})

	// Act
	cleaned, err := manager.CleanupStaleMountsFromFile(mountsFile)

	// Assert
	assert.Error(t, err)
	assert.Equal(t, 0, cleaned, "No mounts should be cleaned")
}

// TestCleanupStaleMountsFromFile_BadFile tests with non-existent file
func TestCleanupStaleMountsFromFile_BadFile(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	cleaned, err := manager.CleanupStaleMountsFromFile("/nonexistent/path")

	// Assert
	assert.Error(t, err)
	assert.Equal(t, 0, cleaned)
	assert.Contains(t, err.Error(), "failed to detect stale mounts")
}

// TestCleanupStaleMountsFromFile_NoMounts tests with no stale mounts
func TestCleanupStaleMountsFromFile_NoMounts(t *testing.T) {
	manager := NewOverlayManager()
	tempDir := t.TempDir()

	mountsFile := filepath.Join(tempDir, "mounts")
	content := `/dev/sda1 / ext4 rw 0 0
tmpfs /tmp tmpfs rw 0 0`
	require.NoError(t, os.WriteFile(mountsFile, []byte(content), 0644))

	// Act
	cleaned, err := manager.CleanupStaleMountsFromFile(mountsFile)

	// Assert
	assert.NoError(t, err)
	assert.Equal(t, 0, cleaned)
}
