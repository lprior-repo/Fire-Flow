package state

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestNewState_DefaultValues(t *testing.T) {
	// ARRANGE & ACT
	state := NewState()

	// ASSERT
	assert.Equal(t, "2.0", state.Version, "Version should be 2.0")
	assert.False(t, state.OverlayActive, "OverlayActive should be false by default")
	assert.Empty(t, state.OverlayMountPath, "OverlayMountPath should be empty")
	assert.Empty(t, state.OverlayUpperDir, "OverlayUpperDir should be empty")
	assert.Empty(t, state.OverlayWorkDir, "OverlayWorkDir should be empty")
	assert.Empty(t, state.OverlayMergedDir, "OverlayMergedDir should be empty")
	assert.True(t, state.OverlayMountedAt.IsZero(), "OverlayMountedAt should be zero")
	assert.False(t, state.LastTestResult, "LastTestResult should be false by default")
	assert.True(t, state.LastTestTime.IsZero(), "LastTestTime should be zero")
	assert.Empty(t, state.ActiveMounts, "ActiveMounts should be empty")
}

func TestState_SaveAndLoad_Persistence(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "state.json")
	mountTime := time.Now().Round(time.Second)
	testTime := time.Now().Round(time.Second)

	state := &State{
		Version:          "2.0",
		OverlayActive:    true,
		OverlayMountPath: "/project",
		OverlayUpperDir:  "/tmp/upper",
		OverlayWorkDir:   "/tmp/work",
		OverlayMergedDir: "/tmp/merged",
		OverlayMountedAt: mountTime,
		LastTestResult:   true,
		LastTestTime:     testTime,
		ActiveMounts: []ActiveMount{
			{MergedDir: "/tmp/merged", LowerDir: "/project", MountedSince: mountTime, PID: 1234},
		},
	}

	// ACT: Save state
	err := state.SaveToFile(stateFile)
	require.NoError(t, err, "SaveToFile should not error")

	// ASSERT: File exists
	assert.FileExists(t, stateFile, "State file should be created")

	// ACT: Load state
	loadedState, err := LoadStateFromFile(stateFile)
	require.NoError(t, err, "LoadStateFromFile should not error")

	// ASSERT: Loaded state matches saved state
	assert.Equal(t, state.Version, loadedState.Version)
	assert.Equal(t, state.OverlayActive, loadedState.OverlayActive)
	assert.Equal(t, state.OverlayMountPath, loadedState.OverlayMountPath)
	assert.Equal(t, state.OverlayUpperDir, loadedState.OverlayUpperDir)
	assert.Equal(t, state.OverlayWorkDir, loadedState.OverlayWorkDir)
	assert.Equal(t, state.OverlayMergedDir, loadedState.OverlayMergedDir)
	assert.Equal(t, state.OverlayMountedAt.Unix(), loadedState.OverlayMountedAt.Unix())
	assert.Equal(t, state.LastTestResult, loadedState.LastTestResult)
	assert.Equal(t, state.LastTestTime.Unix(), loadedState.LastTestTime.Unix())
	assert.Len(t, loadedState.ActiveMounts, 1)
	assert.Equal(t, state.ActiveMounts[0].PID, loadedState.ActiveMounts[0].PID)
}

func TestState_LoadNonexistent_DefaultState(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "nonexistent.json")

	// ACT
	state, err := LoadStateFromFile(stateFile)

	// ASSERT
	require.NoError(t, err, "Loading nonexistent file should return default state")
	assert.NotNil(t, state, "State should not be nil")
	assert.Equal(t, "2.0", state.Version)
	assert.False(t, state.OverlayActive)
	assert.Empty(t, state.ActiveMounts)
}

func TestState_SetOverlayMounted(t *testing.T) {
	// ARRANGE
	state := NewState()
	assert.False(t, state.OverlayActive)

	// ACT
	state.SetOverlayMounted("/project", "/tmp/upper", "/tmp/work", "/tmp/merged", 9999)

	// ASSERT
	assert.True(t, state.OverlayActive)
	assert.Equal(t, "/project", state.OverlayMountPath)
	assert.Equal(t, "/tmp/upper", state.OverlayUpperDir)
	assert.Equal(t, "/tmp/work", state.OverlayWorkDir)
	assert.Equal(t, "/tmp/merged", state.OverlayMergedDir)
	assert.False(t, state.OverlayMountedAt.IsZero())
	assert.Len(t, state.ActiveMounts, 1)
	assert.Equal(t, 9999, state.ActiveMounts[0].PID)
	assert.Equal(t, "/tmp/merged", state.ActiveMounts[0].MergedDir)
}

func TestState_SetOverlayUnmounted(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.SetOverlayMounted("/project", "/tmp/upper", "/tmp/work", "/tmp/merged", 1234)
	assert.True(t, state.OverlayActive)
	assert.Len(t, state.ActiveMounts, 1)

	// ACT
	state.SetOverlayUnmounted()

	// ASSERT
	assert.False(t, state.OverlayActive)
	assert.Empty(t, state.OverlayMountPath)
	assert.Empty(t, state.OverlayUpperDir)
	assert.Empty(t, state.OverlayWorkDir)
	assert.Empty(t, state.OverlayMergedDir)
	assert.True(t, state.OverlayMountedAt.IsZero())
	assert.Empty(t, state.ActiveMounts)
}

func TestState_SetTestResult(t *testing.T) {
	t.Run("Set test passed", func(t *testing.T) {
		// ARRANGE
		state := NewState()
		assert.False(t, state.LastTestResult)

		// ACT
		state.SetTestResult(true)

		// ASSERT
		assert.True(t, state.LastTestResult)
		assert.False(t, state.LastTestTime.IsZero())
	})

	t.Run("Set test failed", func(t *testing.T) {
		// ARRANGE
		state := NewState()
		state.SetTestResult(true) // First pass
		assert.True(t, state.LastTestResult)

		// ACT
		state.SetTestResult(false)

		// ASSERT
		assert.False(t, state.LastTestResult)
		assert.False(t, state.LastTestTime.IsZero())
	})
}

func TestState_IsOverlayActive(t *testing.T) {
	t.Run("Inactive by default", func(t *testing.T) {
		state := NewState()
		assert.False(t, state.IsOverlayActive())
	})

	t.Run("Active after mount", func(t *testing.T) {
		state := NewState()
		state.SetOverlayMounted("/project", "/upper", "/work", "/merged", 1000)
		assert.True(t, state.IsOverlayActive())
	})

	t.Run("Inactive after unmount", func(t *testing.T) {
		state := NewState()
		state.SetOverlayMounted("/project", "/upper", "/work", "/merged", 1000)
		state.SetOverlayUnmounted()
		assert.False(t, state.IsOverlayActive())
	})
}

func TestState_HasPassedTests(t *testing.T) {
	t.Run("False by default", func(t *testing.T) {
		state := NewState()
		assert.False(t, state.HasPassedTests())
	})

	t.Run("True after passing tests", func(t *testing.T) {
		state := NewState()
		state.SetTestResult(true)
		assert.True(t, state.HasPassedTests())
	})

	t.Run("False after failing tests", func(t *testing.T) {
		state := NewState()
		state.SetTestResult(true)
		state.SetTestResult(false)
		assert.False(t, state.HasPassedTests())
	})
}

func TestState_GetActiveMountCount(t *testing.T) {
	// ARRANGE
	state := NewState()
	assert.Equal(t, 0, state.GetActiveMountCount())

	// ACT: Add mounts
	state.SetOverlayMounted("/p1", "/u1", "/w1", "/m1", 1001)
	assert.Equal(t, 1, state.GetActiveMountCount())

	// Add another mount by appending to ActiveMounts directly
	state.ActiveMounts = append(state.ActiveMounts, ActiveMount{
		MergedDir: "/m2", LowerDir: "/p2", PID: 1002, MountedSince: time.Now(),
	})
	assert.Equal(t, 2, state.GetActiveMountCount())
}

func TestState_RemoveActiveMount(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
		{MergedDir: "/m2", LowerDir: "/p2", PID: 1002},
		{MergedDir: "/m3", LowerDir: "/p3", PID: 1003},
	}
	assert.Equal(t, 3, state.GetActiveMountCount())

	// ACT: Remove middle mount
	state.RemoveActiveMount("/m2")

	// ASSERT
	assert.Equal(t, 2, state.GetActiveMountCount())
	for _, m := range state.ActiveMounts {
		assert.NotEqual(t, "/m2", m.MergedDir)
	}
}

func TestState_RemoveActiveMount_NotFound(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
	}

	// ACT: Remove non-existent mount
	state.RemoveActiveMount("/nonexistent")

	// ASSERT: No change
	assert.Equal(t, 1, state.GetActiveMountCount())
}

func TestState_GetStaleMounts(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
		{MergedDir: "/m2", LowerDir: "/p2", PID: 1002},
		{MergedDir: "/m3", LowerDir: "/p3", PID: 1003},
	}

	// checkPID returns true only for PID 1002 (simulating running process)
	checkPID := func(pid int) bool {
		return pid == 1002
	}

	// ACT
	staleMounts := state.GetStaleMounts(checkPID)

	// ASSERT
	assert.Len(t, staleMounts, 2)
	pids := []int{staleMounts[0].PID, staleMounts[1].PID}
	assert.Contains(t, pids, 1001)
	assert.Contains(t, pids, 1003)
}

func TestState_ClearStaleMounts(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
		{MergedDir: "/m2", LowerDir: "/p2", PID: 1002},
		{MergedDir: "/m3", LowerDir: "/p3", PID: 1003},
	}

	// checkPID returns true only for PID 1002
	checkPID := func(pid int) bool {
		return pid == 1002
	}

	// ACT
	removed := state.ClearStaleMounts(checkPID)

	// ASSERT
	assert.Equal(t, 2, removed)
	assert.Equal(t, 1, state.GetActiveMountCount())
	assert.Equal(t, 1002, state.ActiveMounts[0].PID)
}

func TestState_ClearStaleMounts_AllStale(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
		{MergedDir: "/m2", LowerDir: "/p2", PID: 1002},
	}

	// All processes dead
	checkPID := func(pid int) bool {
		return false
	}

	// ACT
	removed := state.ClearStaleMounts(checkPID)

	// ASSERT
	assert.Equal(t, 2, removed)
	assert.Equal(t, 0, state.GetActiveMountCount())
}

func TestState_ClearStaleMounts_NoStale(t *testing.T) {
	// ARRANGE
	state := NewState()
	state.ActiveMounts = []ActiveMount{
		{MergedDir: "/m1", LowerDir: "/p1", PID: 1001},
		{MergedDir: "/m2", LowerDir: "/p2", PID: 1002},
	}

	// All processes running
	checkPID := func(pid int) bool {
		return true
	}

	// ACT
	removed := state.ClearStaleMounts(checkPID)

	// ASSERT
	assert.Equal(t, 0, removed)
	assert.Equal(t, 2, state.GetActiveMountCount())
}

func TestState_PersistenceAcrossRestarts(t *testing.T) {
	// Test that state survives across multiple load/save cycles
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "state.json")

	// Create initial state with overlay mounted
	initialState := NewState()
	initialState.SetOverlayMounted("/project", "/upper", "/work", "/merged", 5000)
	initialState.SetTestResult(true)

	// Save initial state
	err := initialState.SaveToFile(stateFile)
	require.NoError(t, err)

	// Load and verify
	loadedState1, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.True(t, loadedState1.IsOverlayActive())
	assert.True(t, loadedState1.HasPassedTests())
	assert.Equal(t, 1, loadedState1.GetActiveMountCount())

	// Modify loaded state: unmount and fail tests
	loadedState1.SetOverlayUnmounted()
	loadedState1.SetTestResult(false)
	err = loadedState1.SaveToFile(stateFile)
	require.NoError(t, err)

	// Load again to verify persistence
	loadedState2, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.False(t, loadedState2.IsOverlayActive())
	assert.False(t, loadedState2.HasPassedTests())
	assert.Equal(t, 0, loadedState2.GetActiveMountCount())
}

func TestState_MultipleMountsTracking(t *testing.T) {
	t.Parallel()

	// Test tracking multiple overlay mounts
	state := NewState()

	// Mount first overlay
	state.SetOverlayMounted("/p1", "/u1", "/w1", "/m1", 2001)
	assert.Equal(t, 1, state.GetActiveMountCount())

	// Manually add more mounts (simulating parallel sessions)
	state.ActiveMounts = append(state.ActiveMounts, ActiveMount{
		MergedDir: "/m2", LowerDir: "/p2", PID: 2002, MountedSince: time.Now(),
	})
	state.ActiveMounts = append(state.ActiveMounts, ActiveMount{
		MergedDir: "/m3", LowerDir: "/p3", PID: 2003, MountedSince: time.Now(),
	})
	assert.Equal(t, 3, state.GetActiveMountCount())

	// Remove one mount
	state.RemoveActiveMount("/m2")
	assert.Equal(t, 2, state.GetActiveMountCount())

	// Verify remaining mounts
	var pids []int
	for _, m := range state.ActiveMounts {
		pids = append(pids, m.PID)
	}
	assert.Contains(t, pids, 2001)
	assert.Contains(t, pids, 2003)
	assert.NotContains(t, pids, 2002)
}

func TestActiveMountStruct(t *testing.T) {
	// Test ActiveMount struct fields
	now := time.Now()
	mount := ActiveMount{
		MergedDir:    "/merged",
		LowerDir:     "/lower",
		MountedSince: now,
		PID:          12345,
	}

	assert.Equal(t, "/merged", mount.MergedDir)
	assert.Equal(t, "/lower", mount.LowerDir)
	assert.Equal(t, now, mount.MountedSince)
	assert.Equal(t, 12345, mount.PID)
}
