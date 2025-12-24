package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// TestOverlayManager_Create tests creating an overlay manager
func TestOverlayManager_Create(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act & Assert
	assert.NotNil(t, manager)
	assert.NotNil(t, manager.fakeMounter)
	assert.NotNil(t, manager.kernelMounter)
}

// TestOverlayManager_GetMounter tests getting the correct mounter
func TestOverlayManager_GetMounter(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act
	fakeMounter := manager.GetMounter("fake")
	kernelMounter := manager.GetMounter("kernel")

	// Assert
	assert.NotNil(t, fakeMounter)
	assert.NotNil(t, kernelMounter)
	assert.IsType(t, &FakeMounter{}, fakeMounter)
	assert.IsType(t, &KernelMounter{}, kernelMounter)
}

// TestOverlayManager_GetMounter_InvalidType tests getting invalid mounter type
func TestOverlayManager_GetMounter_InvalidType(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act
	mounter := manager.GetMounter("invalid")

	// Assert
	assert.Nil(t, mounter)
}

// ============== Stale Mount Recovery Tests ==============

func TestOverlayManager_DetectStaleMounts_EmptyFile(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create empty mounts file
	err := os.WriteFile(mountsFile, []byte(""), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Empty(t, mounts)
}

func TestOverlayManager_DetectStaleMounts_NoOverlayMounts(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create mounts file with non-overlay entries
	content := `proc /proc proc rw,nosuid,nodev,noexec,relatime 0 0
sysfs /sys sysfs rw,nosuid,nodev,noexec,relatime 0 0
/dev/sda1 / ext4 rw,relatime 0 0
tmpfs /tmp tmpfs rw,nosuid,nodev 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Empty(t, mounts)
}

func TestOverlayManager_DetectStaleMounts_NonFireFlowOverlay(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create mounts file with overlay that is NOT fire-flow
	content := `overlay /some/other/path overlay rw,relatime,lowerdir=/lower,upperdir=/upper,workdir=/work 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Empty(t, mounts, "Non-fire-flow overlay mounts should be ignored")
}

func TestOverlayManager_DetectStaleMounts_FireFlowOverlay(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create mounts file with fire-flow overlay mount
	content := `overlay /tmp/fire-flow-merged overlay rw,relatime,lowerdir=/project,upperdir=/tmp/fire-flow-upper,workdir=/tmp/fire-flow-work 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	require.Len(t, mounts, 1)
	assert.Equal(t, "/tmp/fire-flow-merged", mounts[0].MergedDir)
	assert.Equal(t, "/project", mounts[0].LowerDir)
	assert.Equal(t, "/tmp/fire-flow-upper", mounts[0].UpperDir)
	assert.Equal(t, "/tmp/fire-flow-work", mounts[0].WorkDir)
}

func TestOverlayManager_DetectStaleMounts_MultipleFireFlowMounts(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create mounts file with multiple fire-flow overlay mounts
	content := `proc /proc proc rw 0 0
overlay /tmp/fire-flow-merged-1 overlay rw,lowerdir=/p1,upperdir=/u1,workdir=/w1 0 0
overlay /tmp/fire-flow-merged-2 overlay rw,lowerdir=/p2,upperdir=/u2,workdir=/w2 0 0
tmpfs /tmp tmpfs rw 0 0
overlay /other/mount overlay rw,lowerdir=/a,upperdir=/b,workdir=/c 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Len(t, mounts, 2, "Should find exactly 2 fire-flow mounts")

	// Verify first mount
	assert.Equal(t, "/tmp/fire-flow-merged-1", mounts[0].MergedDir)
	assert.Equal(t, "/p1", mounts[0].LowerDir)

	// Verify second mount
	assert.Equal(t, "/tmp/fire-flow-merged-2", mounts[1].MergedDir)
	assert.Equal(t, "/p2", mounts[1].LowerDir)
}

func TestOverlayManager_DetectStaleMounts_FireFlowInOptions(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Mount path doesn't have fire-flow but options do
	content := `overlay /merged overlay rw,lowerdir=/fire-flow-project,upperdir=/u,workdir=/w 0 0
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Len(t, mounts, 1, "Should detect mount with fire-flow in options")
}

func TestOverlayManager_DetectStaleMounts_FileNotFound(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act
	mounts, err := manager.DetectStaleMountsFromFile("/nonexistent/path/mounts")

	// Assert
	assert.Error(t, err)
	assert.Nil(t, mounts)
}

func TestOverlayManager_DetectStaleMounts_MalformedLine(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()
	tmpDir := t.TempDir()
	mountsFile := filepath.Join(tmpDir, "mounts")

	// Create mounts file with malformed lines
	content := `short line
overlay /tmp/fire-flow-merged overlay rw,lowerdir=/p,upperdir=/u,workdir=/w 0 0
another short
`
	err := os.WriteFile(mountsFile, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	mounts, err := manager.DetectStaleMountsFromFile(mountsFile)

	// Assert
	require.NoError(t, err)
	assert.Len(t, mounts, 1, "Should skip malformed lines and still find valid mount")
}

func TestIsPIDRunning_CurrentProcess(t *testing.T) {
	// Current process should be running
	currentPID := os.Getpid()
	assert.True(t, IsPIDRunning(currentPID), "Current process should be running")
}

func TestIsPIDRunning_InvalidPID(t *testing.T) {
	// Invalid PIDs
	assert.False(t, IsPIDRunning(0), "PID 0 should not be running")
	assert.False(t, IsPIDRunning(-1), "Negative PID should not be running")
}

func TestIsPIDRunning_NonExistentPID(t *testing.T) {
	// Very high PID that almost certainly doesn't exist
	assert.False(t, IsPIDRunning(999999999), "Non-existent PID should not be running")
}

func TestOverlayManager_GetStaleMountCount(t *testing.T) {
	// Arrange
	manager := NewOverlayManager()

	// Act - this will read /proc/mounts on Linux
	count, err := manager.GetStaleMountCount()

	// Assert
	// We can't predict the count, but it should not error on Linux
	// and should return a non-negative number
	require.NoError(t, err)
	assert.GreaterOrEqual(t, count, 0)
}

func TestStaleMount_Struct(t *testing.T) {
	// Test StaleMount struct fields
	stale := StaleMount{
		MergedDir: "/merged",
		LowerDir:  "/lower",
		UpperDir:  "/upper",
		WorkDir:   "/work",
	}

	assert.Equal(t, "/merged", stale.MergedDir)
	assert.Equal(t, "/lower", stale.LowerDir)
	assert.Equal(t, "/upper", stale.UpperDir)
	assert.Equal(t, "/work", stale.WorkDir)
}
