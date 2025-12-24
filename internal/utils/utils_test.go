package utils

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/lprior-repo/Fire-Flow/internal/state"
	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestGetTCRPath(t *testing.T) {
	// Save and restore original env
	originalRoot := os.Getenv("FIRE_FLOW_ROOT")
	defer os.Setenv("FIRE_FLOW_ROOT", originalRoot)

	// Test with explicit root
	os.Setenv("FIRE_FLOW_ROOT", "/test/project")
	expected := "/test/project/.opencode/tcr"
	actual := GetTCRPath()
	assert.Equal(t, expected, actual)

	// Test with no env (uses cwd)
	os.Unsetenv("FIRE_FLOW_ROOT")
	cwd, _ := os.Getwd()
	expected = filepath.Join(cwd, TCRBasePath)
	actual = GetTCRPath()
	assert.Equal(t, expected, actual)
}

func TestGetConfigPath(t *testing.T) {
	expected := filepath.Join(GetTCRPath(), "config.yml")
	actual := GetConfigPath()
	assert.Equal(t, expected, actual)
}

func TestGetStatePath(t *testing.T) {
	expected := filepath.Join(GetTCRPath(), "state.json")
	actual := GetStatePath()
	assert.Equal(t, expected, actual)
}

func TestCreateDefaultConfig(t *testing.T) {
	// Arrange
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.yml")

	// Act
	err := CreateDefaultConfig(configPath)

	// Assert
	require.NoError(t, err)
	assert.FileExists(t, configPath)
}

func TestCreateDefaultState(t *testing.T) {
	// Arrange
	tmpDir := t.TempDir()
	statePath := filepath.Join(tmpDir, "state.json")

	// Act
	err := CreateDefaultState(statePath)

	// Assert
	require.NoError(t, err)
	assert.FileExists(t, statePath)
}

func TestLoadStateWithValidation(t *testing.T) {
	// Save and restore original env
	originalRoot := os.Getenv("FIRE_FLOW_ROOT")
	defer os.Setenv("FIRE_FLOW_ROOT", originalRoot)

	// Create a temp directory for state
	tmpDir := t.TempDir()
	tcrDir := filepath.Join(tmpDir, ".opencode/tcr")
	err := os.MkdirAll(tcrDir, 0755)
	require.NoError(t, err)

	os.Setenv("FIRE_FLOW_ROOT", tmpDir)

	// Create a state file
	statePath := filepath.Join(tcrDir, "state.json")
	st := state.NewState()
	err = st.SaveToFile(statePath)
	require.NoError(t, err)

	// Act
	loadedState, err := LoadStateWithValidation()

	// Assert
	require.NoError(t, err)
	assert.NotNil(t, loadedState)
	assert.NotNil(t, loadedState.ActiveMounts, "ActiveMounts should be initialized")
}

func TestLoadStateWithValidation_NoFile(t *testing.T) {
	// Save and restore original env
	originalRoot := os.Getenv("FIRE_FLOW_ROOT")
	defer os.Setenv("FIRE_FLOW_ROOT", originalRoot)

	// Create a temp directory with no state file
	tmpDir := t.TempDir()
	tcrDir := filepath.Join(tmpDir, ".opencode/tcr")
	err := os.MkdirAll(tcrDir, 0755)
	require.NoError(t, err)

	os.Setenv("FIRE_FLOW_ROOT", tmpDir)

	// Act - should return default state
	loadedState, err := LoadStateWithValidation()

	// Assert
	require.NoError(t, err)
	assert.NotNil(t, loadedState)
	assert.Equal(t, "2.0", loadedState.Version)
}

func TestLoadStateWithValidation_NilActiveMounts(t *testing.T) {
	// Save and restore original env
	originalRoot := os.Getenv("FIRE_FLOW_ROOT")
	defer os.Setenv("FIRE_FLOW_ROOT", originalRoot)

	// Create a temp directory for state
	tmpDir := t.TempDir()
	tcrDir := filepath.Join(tmpDir, ".opencode/tcr")
	err := os.MkdirAll(tcrDir, 0755)
	require.NoError(t, err)

	os.Setenv("FIRE_FLOW_ROOT", tmpDir)

	// Create a state file with nil ActiveMounts
	statePath := filepath.Join(tcrDir, "state.json")
	content := `{"version":"2.0","overlayActive":false,"activeMounts":null}`
	err = os.WriteFile(statePath, []byte(content), 0644)
	require.NoError(t, err)

	// Act
	loadedState, err := LoadStateWithValidation()

	// Assert
	require.NoError(t, err)
	assert.NotNil(t, loadedState)
	assert.NotNil(t, loadedState.ActiveMounts, "ActiveMounts should be initialized even if nil in file")
	assert.Empty(t, loadedState.ActiveMounts)
}

func TestGetStateName(t *testing.T) {
	t.Run("Nil state returns GREEN", func(t *testing.T) {
		result := GetStateName(nil)
		assert.Equal(t, "GREEN", result)
	})

	t.Run("State with passed tests returns GREEN", func(t *testing.T) {
		st := state.NewState()
		st.SetTestResult(true)
		result := GetStateName(st)
		assert.Equal(t, "GREEN", result)
	})

	t.Run("State with failed tests returns RED", func(t *testing.T) {
		st := state.NewState()
		st.SetTestResult(false)
		result := GetStateName(st)
		assert.Equal(t, "RED", result)
	})

	t.Run("New state (no tests) returns RED", func(t *testing.T) {
		st := state.NewState()
		// New state has LastTestResult = false by default
		result := GetStateName(st)
		assert.Equal(t, "RED", result)
	})
}

func TestFormatTime(t *testing.T) {
	// Test with a known time
	testTime := time.Date(2025, 12, 23, 14, 30, 45, 0, time.UTC)
	expected := "2025-12-23 14:30:45"
	actual := FormatTime(testTime)
	assert.Equal(t, expected, actual)
}

func TestFormatTime_ZeroTime(t *testing.T) {
	// Test with zero time
	var zeroTime time.Time
	result := FormatTime(zeroTime)
	assert.Equal(t, "0001-01-01 00:00:00", result)
}

func TestTCRBasePath_Constant(t *testing.T) {
	// Verify the constant value
	assert.Equal(t, ".opencode/tcr", TCRBasePath)
}
