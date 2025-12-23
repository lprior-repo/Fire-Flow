package main

import (
	"testing"

	"github.com/lprior-repo/Fire-Flow/internal/overlay"
	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/state"
	"github.com/stretchr/testify/assert"
)

func TestMain(t *testing.T) {
	// Test that the main function can be called without error
	// We're mainly testing that our code compiles and doesn't panic
	// This is a placeholder for more comprehensive tests
	assert.NotNil(t, t)
}

func TestGetPaths(t *testing.T) {
	// Test path functions
	assert.NotEmpty(t, GetTCRPath())
	assert.NotEmpty(t, GetConfigPath())
	assert.NotEmpty(t, GetStatePath())
}

func TestLoadConfig(t *testing.T) {
	// Test loading config from default path
	cfg, err := loadConfig()
	assert.NoError(t, err)
	assert.NotNil(t, cfg)
}

func TestLoadState(t *testing.T) {
	// Test loading state from default path
	st, err := loadState()
	assert.NoError(t, err)
	assert.NotNil(t, st)
}

func TestOverlayManager(t *testing.T) {
	// Test overlay manager creation
	manager := overlay.NewOverlayManager(overlay.NewFakeMounter())
	assert.NotNil(t, manager)
}

func TestDefaultConfig(t *testing.T) {
	// Test default config creation
	cfg := config.DefaultConfig()
	assert.NotNil(t, cfg)
	assert.NotEmpty(t, cfg.TestCommand)
	assert.NotEmpty(t, cfg.TestPatterns)
	assert.NotEmpty(t, cfg.ProtectedPaths)
	assert.Greater(t, cfg.Timeout, 0)
}

func TestDefaultState(t *testing.T) {
	// Test default state creation
	st := state.NewState()
	assert.NotNil(t, st)
	assert.Equal(t, "both", st.Mode)
	assert.Equal(t, 0, st.RevertStreak)
	assert.Empty(t, st.FailingTests)
	assert.NotZero(t, st.LastCommitTime)
}

func TestIsRed(t *testing.T) {
	// Test state IsRed method
	st := state.NewState()
	st.SetRed()
	assert.True(t, st.IsRed())
	assert.False(t, st.IsGreen())
}

func TestIsGreen(t *testing.T) {
	// Test state IsGreen method
	st := state.NewState()
	st.SetGreen()
	assert.True(t, st.IsGreen())
	assert.False(t, st.IsRed())
}

func TestGetStateName(t *testing.T) {
	// Test state name getter
	st := state.NewState()
	st.SetRed()
	assert.Equal(t, "RED", getStateName(st))
	
	st.SetGreen()
	assert.Equal(t, "GREEN", getStateName(st))
}

func TestGetStateNameNil(t *testing.T) {
	// Test with nil state (should not panic)
	assert.Equal(t, "GREEN", getStateName(nil))
}