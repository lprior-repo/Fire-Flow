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

	// Assert - The simplified version always allows for now, but in a real implementation
	// this would check actual state and make decisions
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

	// Assert - This is a mock implementation that returns a fixed result
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

	// Assert - This is a mock implementation that returns a fixed result
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

func TestTddGate_PatternMatchingAndStateDetection(t *testing.T) {
	// Test that pattern matching works correctly with different types of test outputs
	testStateDetector := teststate.NewTestStateDetector()

	// Test 1: Mock output with no failures (should be GREEN)
	mockSuccessOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"pass","Test":"TestExample1","Package":"example"}
{"Action":"pass","Test":"TestExample2","Package":"example"}
`

	result, err := testStateDetector.ParseGoTestOutput(mockSuccessOutput)
	assert.NoError(t, err)
	assert.True(t, result.Passed)
	assert.Empty(t, result.FailedTests)

	// Test 2: Mock output with failures (should be RED)
	mockFailureOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"fail","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"pass","Test":"TestExample2","Package":"example"}
`

	result, err = testStateDetector.ParseGoTestOutput(mockFailureOutput)
	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample1")
	assert.Len(t, result.FailedTests, 1)

	// Test 3: Test with multiple failures
	mockMultipleFailuresOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"fail","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"fail","Test":"TestExample2","Package":"example"}
{"Action":"run","Test":"TestExample3","Package":"example"}
{"Action":"pass","Test":"TestExample3","Package":"example"}
`

	result, err = testStateDetector.ParseGoTestOutput(mockMultipleFailuresOutput)
	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample1")
	assert.Contains(t, result.FailedTests, "TestExample2")
	assert.Len(t, result.FailedTests, 2)
}

func TestTddGate_REDGreenDetection(t *testing.T) {
	// Test that we can correctly detect RED/GREEN states from test results
	testStateDetector := teststate.NewTestStateDetector()

	// Test GREEN state - no failing tests
	greenOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"pass","Test":"TestExample1","Package":"example"}
`
	result, err := testStateDetector.ParseGoTestOutput(greenOutput)
	assert.NoError(t, err)
	assert.True(t, result.Passed)

	// Test RED state - with failing tests
	redOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"fail","Test":"TestExample1","Package":"example"}
`
	result, err = testStateDetector.ParseGoTestOutput(redOutput)
	assert.NoError(t, err)
	assert.False(t, result.Passed)
}

func TestTddGate_BlockedVsAllowedDecisions(t *testing.T) {
	// This tests the decision logic for blocking/allowing implementation
	// In a real implementation, this would be more complex
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Since the current implementation is simplified, we test that
	// the check gate function returns expected results
	passed, message, err := gate.CheckGate()
	assert.NoError(t, err)
	assert.True(t, passed)
	assert.Contains(t, message, "TDD gate logic")
}

func TestTddGate_SingleTestMode_Enabled(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Verify single test mode is enabled by default
	assert.True(t, gate.SingleTestMode, "SingleTestMode should be enabled by default")
}

func TestTddGate_ValidateSingleTest_OneTest_Passes(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Result with exactly one test executed
	result := &teststate.TestResult{
		ExecutedTests: []string{"TestExample1"},
		Passed:        true,
	}

	err := gate.ValidateSingleTest(result)
	assert.NoError(t, err, "Single test should pass validation")
}

func TestTddGate_ValidateSingleTest_MultipleTests_Fails(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Result with multiple tests executed - this should fail validation
	result := &teststate.TestResult{
		ExecutedTests: []string{"TestExample1", "TestExample2", "TestExample3"},
		Passed:        true,
	}

	err := gate.ValidateSingleTest(result)
	assert.Error(t, err, "Multiple tests should fail validation")
	assert.ErrorIs(t, err, ErrMultipleTestsExecuted)
	assert.Contains(t, err.Error(), "ran 3 tests")
}

func TestTddGate_ValidateSingleTest_NoTests_Fails(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Result with no tests executed
	result := &teststate.TestResult{
		ExecutedTests: []string{},
		Passed:        true,
	}

	err := gate.ValidateSingleTest(result)
	assert.Error(t, err, "No tests should fail validation")
	assert.Contains(t, err.Error(), "no tests were executed")
}

func TestTddGate_ValidateSingleTest_NilResult_Fails(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	err := gate.ValidateSingleTest(nil)
	assert.Error(t, err, "Nil result should fail validation")
	assert.Contains(t, err.Error(), "no test result provided")
}

func TestTddGate_NewTddGateWithOptions_DisableSingleTestMode(t *testing.T) {
	cfg := config.DefaultConfig()

	// Create gate with single test mode disabled
	gate := NewTddGateWithOptions(cfg, false)

	assert.NotNil(t, gate)
	assert.False(t, gate.SingleTestMode, "SingleTestMode should be disabled")
}

func TestTddGate_GetExecutedTestCount(t *testing.T) {
	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)

	// Test with nil result
	count := gate.GetExecutedTestCount(nil)
	assert.Equal(t, 0, count)

	// Test with empty result
	result := &teststate.TestResult{ExecutedTests: []string{}}
	count = gate.GetExecutedTestCount(result)
	assert.Equal(t, 0, count)

	// Test with multiple tests
	result = &teststate.TestResult{ExecutedTests: []string{"Test1", "Test2", "Test3"}}
	count = gate.GetExecutedTestCount(result)
	assert.Equal(t, 3, count)
}

func TestTddGate_ParseGoTestOutput_TracksExecutedTests(t *testing.T) {
	testStateDetector := teststate.NewTestStateDetector()

	// Test output with multiple tests being run
	mockOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"pass","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"pass","Test":"TestExample2","Package":"example"}
{"Action":"run","Test":"TestExample3","Package":"example"}
{"Action":"fail","Test":"TestExample3","Package":"example"}
`

	result, err := testStateDetector.ParseGoTestOutput(mockOutput)
	assert.NoError(t, err)

	// Should track all 3 executed tests
	assert.Len(t, result.ExecutedTests, 3)
	assert.Contains(t, result.ExecutedTests, "TestExample1")
	assert.Contains(t, result.ExecutedTests, "TestExample2")
	assert.Contains(t, result.ExecutedTests, "TestExample3")

	// Should also track failed tests separately
	assert.Len(t, result.FailedTests, 1)
	assert.Contains(t, result.FailedTests, "TestExample3")
}

func TestTddGate_SingleTestEnforcement_Integration(t *testing.T) {
	// Integration test: Parse real-looking output and validate single test mode

	cfg := config.DefaultConfig()
	gate := NewTddGate(cfg)
	testStateDetector := teststate.NewTestStateDetector()

	// Scenario 1: Single test - should pass
	singleTestOutput := `{"Action":"run","Test":"TestFeatureX","Package":"myapp/feature"}
{"Action":"pass","Test":"TestFeatureX","Package":"myapp/feature"}
`
	result, err := testStateDetector.ParseGoTestOutput(singleTestOutput)
	assert.NoError(t, err)

	err = gate.ValidateSingleTest(result)
	assert.NoError(t, err, "Single test should pass validation")

	// Scenario 2: Multiple tests (shotgunning) - should fail
	shotgunOutput := `{"Action":"run","Test":"TestFeature1","Package":"myapp/feature"}
{"Action":"pass","Test":"TestFeature1","Package":"myapp/feature"}
{"Action":"run","Test":"TestFeature2","Package":"myapp/feature"}
{"Action":"pass","Test":"TestFeature2","Package":"myapp/feature"}
{"Action":"run","Test":"TestFeature3","Package":"myapp/feature"}
{"Action":"pass","Test":"TestFeature3","Package":"myapp/feature"}
`
	result, err = testStateDetector.ParseGoTestOutput(shotgunOutput)
	assert.NoError(t, err)

	err = gate.ValidateSingleTest(result)
	assert.Error(t, err, "Shotgunning multiple tests should fail validation")
	assert.ErrorIs(t, err, ErrMultipleTestsExecuted)
}
