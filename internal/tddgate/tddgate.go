package tddgate

import (
	"github.com/lprior-repo/Fire-Flow/internal/config"
	"github.com/lprior-repo/Fire-Flow/internal/teststate"
)

// TddGate represents the TDD gate system
type TddGate struct {
	config    *config.Config
	testState *teststate.TestStateDetector
}

// NewTddGate creates a new TDD gate instance
func NewTddGate(cfg *config.Config) *TddGate {
	return &TddGate{
		config:    cfg,
		testState: teststate.NewTestStateDetector(),
	}
}

// CheckGate evaluates whether to allow or block implementation based on test results
// Returns true if the gate passes (implementation allowed), false if blocked
func (g *TddGate) CheckGate() (bool, string, error) {
	// This is a simplified version - in a real implementation, this would
	// check the current state of the system
	// For now, we'll just return that the gate passes (implementation allowed)
	// This is just a placeholder for what would be the core logic

	// In a real system, this would check if the system is in a GREEN or RED state
	// and make a decision based on that

	return true, "TDD gate logic: Implementation is allowed (simplified for now)", nil
}

// RunTests executes the configured test command and returns the result
func (g *TddGate) RunTests() (*teststate.TestResult, error) {
	// This is a simplified implementation that just creates a mock result
	// A real implementation would execute the actual command

	// Create a mock result for testing purposes
	result := &teststate.TestResult{
		Output:   "Mock test output",
		Passed:   true,
		Duration: g.config.Timeout,
	}

	return result, nil
}

// RunAndCheckGate executes tests and then checks the TDD gate
func (g *TddGate) RunAndCheckGate() (bool, *teststate.TestResult, string, error) {
	// Run tests
	testResult, err := g.RunTests()
	if err != nil {
		return false, testResult, "", err
	}

	// Check the gate
	passed, message, err := g.CheckGate()
	if err != nil {
		return false, testResult, "", err
	}

	return passed, testResult, message, nil
}
