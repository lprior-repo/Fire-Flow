package command

import (
	"testing"

	"github.com/lprior-repo/Fire-Flow/internal/teststate"
	"github.com/stretchr/testify/assert"
)

func TestRunTestsCommand_ParseJSONOutput(t *testing.T) {
	// Test that JSON parsing works correctly
	testDetector := teststate.NewTestStateDetector()

	// Test successful output parsing
	mockOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"pass","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"pass","Test":"TestExample2","Package":"example"}
`

	result, err := testDetector.GetTestResultFromOutput(mockOutput)
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.True(t, result.Passed)
	assert.Empty(t, result.FailedTests)

	// Test failing output parsing
	mockFailureOutput := `{"Action":"run","Test":"TestExample1","Package":"example"}
{"Action":"fail","Test":"TestExample1","Package":"example"}
{"Action":"run","Test":"TestExample2","Package":"example"}
{"Action":"pass","Test":"TestExample2","Package":"example"}
`

	result, err = testDetector.GetTestResultFromOutput(mockFailureOutput)
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample1")
}

func TestRunTestsCommand_ParseJSONOutput_Empty(t *testing.T) {
	// Test empty output
	testDetector := teststate.NewTestStateDetector()

	result, err := testDetector.GetTestResultFromOutput("")
	assert.NoError(t, err)
	assert.NotNil(t, result)
	assert.True(t, result.Passed)
	assert.Empty(t, result.FailedTests)
	assert.Empty(t, result.Output)
}

func TestRunTestsCommand_TimeoutHandling(t *testing.T) {
	// This tests the timeout logic in runTestsCommand
	// Note: This is a simplified test, actual timeout testing requires more complex setup

	// Test with a command that should timeout
	result, err := runTestsCommand("sleep 5", 1) // 1 second timeout
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "timed out")
	assert.Nil(t, result)
}

func TestRunTestsCommand_Structure(t *testing.T) {
	// Test command structure
	cmd := &RunTestsCommand{
		Timeout: 15,
	}

	assert.NotNil(t, cmd)
	assert.Equal(t, 15, cmd.Timeout)

	// Test default timeout
	cmd2 := &RunTestsCommand{}
	assert.Equal(t, 0, cmd2.Timeout)
}
