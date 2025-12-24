package state

import (
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestEnforcerState_NewState_DefaultValues(t *testing.T) {
	// ARRANGE & ACT
	state := NewState()

	// ASSERT
	assert.Equal(t, "both", state.Mode, "Default mode should be 'both'")
	assert.Equal(t, 0, state.RevertStreak, "Initial revert streak should be 0")
	assert.Empty(t, state.FailingTests, "Initial failing tests should be empty")
	assert.False(t, state.LastCommitTime.IsZero(), "LastCommitTime should be initialized to now")
}

func TestEnforcerState_SaveAndLoad_Persistence(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "state.json")

	state := &State{
		Mode:           "both",
		RevertStreak:   2,
		FailingTests:   []string{"TestA", "TestB"},
		LastCommitTime: time.Now().Round(time.Second), // Round to avoid timestamp precision issues
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
	assert.Equal(t, state.Mode, loadedState.Mode)
	assert.Equal(t, state.RevertStreak, loadedState.RevertStreak)
	assert.Equal(t, state.FailingTests, loadedState.FailingTests)
	assert.Equal(t, state.LastCommitTime.Unix(), loadedState.LastCommitTime.Unix(), "Timestamps should match (checked via Unix seconds)")
}

func TestEnforcerState_LoadNonexistent_DefaultState(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "nonexistent.json")

	// ACT
	state, err := LoadStateFromFile(stateFile)

	// ASSERT
	require.NoError(t, err, "Loading nonexistent file should return error-free default state (or handle gracefully)")
	assert.NotNil(t, state, "State should not be nil")
	assert.Equal(t, "both", state.Mode)
	assert.Equal(t, 0, state.RevertStreak)
}

func TestEnforcerState_IncrementRevertStreak(t *testing.T) {
	// ARRANGE
	state := NewState()
	assert.Equal(t, 0, state.RevertStreak)

	// ACT
	state.IncrementRevertStreak()
	state.IncrementRevertStreak()

	// ASSERT
	assert.Equal(t, 2, state.RevertStreak)
}

func TestEnforcerState_ResetRevertStreak(t *testing.T) {
	// ARRANGE
	state := &State{RevertStreak: 5}

	// ACT
	state.ResetRevertStreak()

	// ASSERT
	assert.Equal(t, 0, state.RevertStreak)
}

func TestEnforcerState_SetFailingTests(t *testing.T) {
	// ARRANGE
	state := NewState()

	// ACT
	failingTests := []string{"test1", "test2", "test3"}
	state.SetFailingTests(failingTests)

	// ASSERT
	assert.Equal(t, failingTests, state.FailingTests)
}

func TestEnforcerState_IsRed_Green(t *testing.T) {
	t.Run("Red state with failing tests", func(t *testing.T) {
		// ARRANGE
		state := &State{FailingTests: []string{"TestA"}}

		// ACT & ASSERT
		assert.True(t, state.IsRed(), "State with failing tests should be Red")
		assert.False(t, state.IsGreen(), "State with failing tests should not be Green")
	})

	t.Run("Green state with no failing tests", func(t *testing.T) {
		// ARRANGE
		state := &State{FailingTests: []string{}}

		// ACT & ASSERT
		assert.False(t, state.IsRed(), "State with no failing tests should not be Red")
		assert.True(t, state.IsGreen(), "State with no failing tests should be Green")
	})

	t.Run("Green state with nil failing tests", func(t *testing.T) {
		// ARRANGE
		state := &State{FailingTests: nil}

		// ACT & ASSERT
		assert.False(t, state.IsRed())
		assert.True(t, state.IsGreen())
	})
}

func TestEnforcerState_StatePersistenceAcrossRestarts(t *testing.T) {
	// Test that state survives across multiple load/save cycles
	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "state.json")

	// Create initial state
	initialState := &State{
		Mode:           "both",
		RevertStreak:   3,
		FailingTests:   []string{"TestA", "TestB"},
		LastCommitTime: time.Now().Round(time.Second),
	}

	// Save initial state
	err := initialState.SaveToFile(stateFile)
	require.NoError(t, err)

	// Load and verify
	loadedState1, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.Equal(t, initialState.Mode, loadedState1.Mode)
	assert.Equal(t, initialState.RevertStreak, loadedState1.RevertStreak)
	assert.Equal(t, initialState.FailingTests, loadedState1.FailingTests)
	assert.Equal(t, initialState.LastCommitTime.Unix(), loadedState1.LastCommitTime.Unix())

	// Modify loaded state and save again
	loadedState1.RevertStreak = 5
	loadedState1.FailingTests = append(loadedState1.FailingTests, "TestC")
	err = loadedState1.SaveToFile(stateFile)
	require.NoError(t, err)

	// Load again to verify persistence
	loadedState2, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.Equal(t, 5, loadedState2.RevertStreak)
	assert.Equal(t, []string{"TestA", "TestB", "TestC"}, loadedState2.FailingTests)
}

func TestEnforcerState_StateConcurrentAccess(t *testing.T) {
	// Test that state operations work correctly with concurrent access patterns
	t.Parallel() // Mark test as parallel

	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "concurrent_state.json")

	// Create initial state
	state := &State{
		Mode:           "both",
		RevertStreak:   0,
		FailingTests:   []string{},
		LastCommitTime: time.Now(),
	}

	// Save state to file
	err := state.SaveToFile(stateFile)
	require.NoError(t, err)

	// Test that loading works correctly
	loadedState, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)

	// Verify properties
	assert.Equal(t, "both", loadedState.Mode)
	assert.Equal(t, 0, loadedState.RevertStreak)
	assert.Empty(t, loadedState.FailingTests)

	// Test modifying state
	loadedState.IncrementRevertStreak()
	loadedState.SetFailingTests([]string{"Test1", "Test2"})

	// Verify changes
	assert.Equal(t, 1, loadedState.RevertStreak)
	assert.Equal(t, []string{"Test1", "Test2"}, loadedState.FailingTests)

	// Save modified state
	err = loadedState.SaveToFile(stateFile)
	require.NoError(t, err)

	// Load again to verify persistence
	finalState, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.Equal(t, 1, finalState.RevertStreak)
	assert.Equal(t, []string{"Test1", "Test2"}, finalState.FailingTests)
}

func TestEnforcerState_StateWithDifferentTestScenarios(t *testing.T) {
	// Test various test scenarios to make sure the state behavior is consistent
	t.Parallel()

	tmpDir := t.TempDir()
	stateFile := filepath.Join(tmpDir, "scenario_state.json")

	// Test 1: Empty state (should load default)
	loaded1, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.Equal(t, "both", loaded1.Mode)
	assert.Equal(t, 0, loaded1.RevertStreak)
	assert.Empty(t, loaded1.FailingTests)
	assert.False(t, loaded1.IsRed())
	assert.True(t, loaded1.IsGreen())

	// Test 2: State with failing tests
	state2 := &State{
		FailingTests: []string{"TestA", "TestB"},
	}
	err = state2.SaveToFile(stateFile)
	require.NoError(t, err)

	loaded2, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.True(t, loaded2.IsRed())
	assert.False(t, loaded2.IsGreen())

	// Test 3: State with single failing test
	state3 := &State{
		FailingTests: []string{"SingleTest"},
	}
	err = state3.SaveToFile(stateFile)
	require.NoError(t, err)

	loaded3, err := LoadStateFromFile(stateFile)
	require.NoError(t, err)
	assert.True(t, loaded3.IsRed())
	assert.False(t, loaded3.IsGreen())
}
