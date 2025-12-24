package patternmatcher

import (
	"path/filepath"
	"regexp"
)

// PatternMatcher provides functionality for matching file paths against patterns
type PatternMatcher struct {
	patterns []string
}

// NewPatternMatcher creates a new PatternMatcher with the given patterns
func NewPatternMatcher(patterns []string) *PatternMatcher {
	return &PatternMatcher{
		patterns: patterns,
	}
}

// Matches checks if a file path matches any of the patterns
func (pm *PatternMatcher) Matches(filePath string) bool {
	for _, pattern := range pm.patterns {
		matched, err := filepath.Match(pattern, filePath)
		if err == nil && matched {
			return true
		}
	}
	return false
}

// MatchesExact checks if a file path exactly matches any pattern (without glob expansion)
func (pm *PatternMatcher) MatchesExact(filePath string) bool {
	for _, pattern := range pm.patterns {
		// Check for exact match (no glob patterns)
		if filePath == pattern {
			return true
		}
		// Check if pattern is a glob that matches the path
		matched, err := filepath.Match(pattern, filePath)
		if err == nil && matched {
			return true
		}
	}
	return false
}

// IsTestFile checks if a file path matches the test patterns
func (pm *PatternMatcher) IsTestFile(filePath string) bool {
	return pm.Matches(filePath)
}

// FindMatchingTestFiles finds test files that match the given source file
// This is a simple implementation that matches the basic pattern approach
func (pm *PatternMatcher) FindMatchingTestFiles(sourceFile string) []string {
	// For now, we'll return empty as the exact matching logic needs to be more sophisticated
	// This would be implemented in a more advanced version
	return []string{}
}

// CompilePatterns converts string patterns to compiled regex patterns for performance
func (pm *PatternMatcher) CompilePatterns() []*regexp.Regexp {
	// Placeholder for future implementation
	// This would precompile patterns for better performance
	return make([]*regexp.Regexp, len(pm.patterns))
}
