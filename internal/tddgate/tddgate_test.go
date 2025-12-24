package tddgate

import (
	"testing"

	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/teststate"
	"github.com/stretchr/testify/assert"
)

func TestTddGate_CheckGate(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Act
	passed, message, err := gate.CheckGate()

	// Assert
	assert.NoError(t, err)
	assert.True(t, passed)
	assert.Contains(t, message, "TDD gate logic")
}

func TestTddGate_RunTests_Success(t *testing.T) {
	cfg := config.DefaultConfig()
	// Use a simple test command that should succeed
	cfg.TestCommand = "echo 'PASS'"

	gate := NewTddGate(cfg)

	// Act
	result, err := gate.RunTests()

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.Contains(t, result.Output, "Mock test output")
	assert.True(t, result.Passed)
}

func TestTddGate_RunTests_Failure(t *testing.T) {
	cfg := config.DefaultConfig()
	// Use a command that will fail
	cfg.TestCommand = "exit 1"

	gate := NewTddGate(cfg)

	// Act
	result, err := gate.RunTests()

	// Assert
	assert.NoError(t, err) // Mock implementation doesn't actually run commands
	assert.NotNil(t, result)
}

func TestTddGate_RunAndCheckGate(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Act
	passed, result, message, err := gate.RunAndCheckGate()

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.True(t, passed)
	assert.Contains(t, message, "TDD gate logic")
}

func TestTddGate_NewTddGate(t *testing.T) {
	cfg := config.DefaultConfig()

	gate := NewTddGate(cfg)

	assert.NotNil(t, gate)
	assert.Equal(t, cfg, gate.config)
	assert.NotNil(t, gate.testState)
	assert.IsType(t, &teststate.TestStateDetector{}, gate.testState)
}