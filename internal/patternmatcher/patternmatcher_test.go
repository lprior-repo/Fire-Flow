package patternmatcher

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestPatternMatcher_Matches(t *testing.T) {
	// Test with basic patterns
	patterns := []string{"*_test.go", "*.spec.ts"}
	pm := NewPatternMatcher(patterns)

	// Test matching
	assert.True(t, pm.Matches("main_test.go"))
	assert.True(t, pm.Matches("utils_test.go"))
	assert.True(t, pm.Matches("component.spec.ts"))
	assert.False(t, pm.Matches("main.go"))
	assert.False(t, pm.Matches("README.md"))
}

func TestPatternMatcher_MatchesExact(t *testing.T) {
	// Test with exact patterns
	patterns := []string{"*_test.go", "test_*.go"}
	pm := NewPatternMatcher(patterns)

	// Test exact matching
	assert.True(t, pm.MatchesExact("main_test.go"))
	assert.True(t, pm.MatchesExact("test_main.go"))
	assert.False(t, pm.MatchesExact("main.go"))
	assert.False(t, pm.MatchesExact("README.md"))
}

func TestPatternMatcher_IsTestFile(t *testing.T) {
	// Test with test patterns
	patterns := []string{"*_test.go"}
	pm := NewPatternMatcher(patterns)

	// Test test file detection
	assert.True(t, pm.IsTestFile("main_test.go"))
	assert.False(t, pm.IsTestFile("main.go"))
	assert.False(t, pm.IsTestFile("README.md"))
}

func TestPatternMatcher_EmptyPatterns(t *testing.T) {
	// Test with empty patterns
	pm := NewPatternMatcher([]string{})

	// Should not match anything
	assert.False(t, pm.Matches("main_test.go"))
	assert.False(t, pm.IsTestFile("main_test.go"))
}
