package teststate

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestTestStateDetector_ParseGoTestOutput_Success(t *testing.T) {
	// Sample go test -json output with passing tests
	output := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"pass","Test":"TestExample","Package":"example","Time":1000000000}
{"Action":"run","Test":"TestAnother","Package":"example"}
{"Action":"pass","Test":"TestAnother","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	result, err := detector.ParseGoTestOutput(output)

	assert.NoError(t, err)
	assert.True(t, result.Passed)
	assert.Empty(t, result.FailedTests)
	assert.Equal(t, output, result.Output)
}

func TestTestStateDetector_ParseGoTestOutput_Failure(t *testing.T) {
	// Sample go test -json output with failing tests
	output := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}
{"Action":"run","Test":"TestAnother","Package":"example"}
{"Action":"pass","Test":"TestAnother","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	result, err := detector.ParseGoTestOutput(output)

	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample")
	assert.Len(t, result.FailedTests, 1)
	assert.Equal(t, output, result.Output)
}

func TestTestStateDetector_ParseGoTestOutput_Mixed(t *testing.T) {
	// Sample go test -json output with mixed results
	output := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}
{"Action":"run","Test":"TestAnother","Package":"example"}
{"Action":"fail","Test":"TestAnother","Package":"example","Time":1000000000}
{"Action":"run","Test":"TestThird","Package":"example"}
{"Action":"pass","Test":"TestThird","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	result, err := detector.ParseGoTestOutput(output)

	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample")
	assert.Contains(t, result.FailedTests, "TestAnother")
	assert.Len(t, result.FailedTests, 2)
	assert.Equal(t, output, result.Output)
}

func TestTestStateDetector_ExtractFailedTests(t *testing.T) {
	// Sample go test -json output with failing tests
	output := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}
{"Action":"run","Test":"TestAnother","Package":"example"}
{"Action":"pass","Test":"TestAnother","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	failedTests := detector.ExtractFailedTests(output)

	assert.Contains(t, failedTests, "TestExample")
	assert.Len(t, failedTests, 1)
}

func TestTestStateDetector_IsTestPassing(t *testing.T) {
	// Test passing output
	passingOutput := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"pass","Test":"TestExample","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	passing, failedTests, err := detector.IsTestPassing(passingOutput)

	assert.NoError(t, err)
	assert.True(t, passing)
	assert.Empty(t, failedTests)
}

func TestTestStateDetector_IsTestPassing_Failure(t *testing.T) {
	// Test failing output
	failingOutput := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	passing, failedTests, err := detector.IsTestPassing(failingOutput)

	assert.NoError(t, err)
	assert.False(t, passing)
	assert.Contains(t, failedTests, "TestExample")
}

func TestTestStateDetector_GetTestResultFromOutput(t *testing.T) {
	// Test with failing output
	failingOutput := `{"Action":"run","Test":"TestExample","Package":"example"}
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	result, err := detector.GetTestResultFromOutput(failingOutput)

	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample")
	assert.Equal(t, failingOutput, result.Output)
}

func TestTestStateDetector_ParseGoTestOutput_Empty(t *testing.T) {
	detector := NewTestStateDetector()
	result, err := detector.ParseGoTestOutput("")

	assert.NoError(t, err)
	assert.True(t, result.Passed)
	assert.Empty(t, result.FailedTests)
	assert.Equal(t, "", result.Output)
}

func TestTestStateDetector_ParseGoTestOutput_InvalidJSON(t *testing.T) {
	// Test with invalid JSON lines mixed in
	output := `{"Action":"run","Test":"TestExample","Package":"example"}
invalid json line
{"Action":"fail","Test":"TestExample","Package":"example","Time":1000000000}
{"Action":"pass","Test":"TestAnother","Package":"example","Time":1000000000}`

	detector := NewTestStateDetector()
	result, err := detector.ParseGoTestOutput(output)

	assert.NoError(t, err)
	assert.False(t, result.Passed)
	assert.Contains(t, result.FailedTests, "TestExample")
	assert.Len(t, result.FailedTests, 1)
}