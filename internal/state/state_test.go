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
