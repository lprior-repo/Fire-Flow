package config

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestConfig_LoadFromFile_DefaultsApplied(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.yml")

	// Write minimal config
	yamlContent := `
testCommand: "go test -json ./..."
testPatterns:
  - "_test\\.go$"
protectedPaths:
  - "opencode.json"
  - ".opencode/tcr"
`
	err := writeTestFile(configFile, yamlContent)
	require.NoError(t, err)

	// ACT
	cfg, err := LoadFromFile(configFile)

	// ASSERT
	require.NoError(t, err)
	require.NotNil(t, cfg)
	assert.Equal(t, "go test -json ./...", cfg.TestCommand)
	assert.Equal(t, []string{"_test\\.go$"}, cfg.TestPatterns)
	assert.Equal(t, []string{"opencode.json", ".opencode/tcr"}, cfg.ProtectedPaths)
	assert.Equal(t, 30, cfg.Timeout, "Default timeout should be 30 seconds")
	assert.Equal(t, "WIP", cfg.AutoCommitMsg, "Default commit message should be WIP")
	assert.Equal(t, "/tmp/fire-flow-overlay-work", cfg.OverlayWorkDir, "Default overlay work dir should be set")
	assert.Equal(t, 500, cfg.WatchDebounce, "Default watch debounce should be 500ms")
	assert.Equal(t, []string{".git", "node_modules", ".opencode"}, cfg.WatchIgnore, "Default watch ignore patterns should be set")
}

func TestConfig_LoadFromFile_CustomTimeout(t *testing.T) {
	// ARRANGE
	tmpDir := t.TempDir()
	configFile := filepath.Join(tmpDir, "config.yml")

	yamlContent := `
testCommand: "npm test"
testPatterns:
  - "\\.(test|spec)\\.ts$"
timeout: 60
autoCommitMsg: "feat: auto-commit"
overlayWorkDir: "/custom/overlay/work"
watchDebounce: 1000
watchIgnore:
  - ".git"
  - "node_modules"
`
	err := writeTestFile(configFile, yamlContent)
	require.NoError(t, err)

	// ACT
	cfg, err := LoadFromFile(configFile)

	// ASSERT
	require.NoError(t, err)
	assert.Equal(t, "npm test", cfg.TestCommand)
	assert.Equal(t, 60, cfg.Timeout)
	assert.Equal(t, "feat: auto-commit", cfg.AutoCommitMsg)
	assert.Equal(t, "/custom/overlay/work", cfg.OverlayWorkDir)
	assert.Equal(t, 1000, cfg.WatchDebounce)
	assert.Equal(t, []string{".git", "node_modules"}, cfg.WatchIgnore)
}

func TestConfig_LoadFromFile_Nonexistent_DefaultConfig(t *testing.T) {
	// ARRANGE
	configFile := "/nonexistent/path/config.yml"

	// ACT
	cfg, err := LoadFromFile(configFile)

	// ASSERT
	// Should return default config without error (or with specific error handling)
	require.NoError(t, err, "Loading nonexistent file should return default config")
	require.NotNil(t, cfg)
	assert.Equal(t, "go test -json ./...", cfg.TestCommand)
	assert.Equal(t, 30, cfg.Timeout)
	assert.Equal(t, "WIP", cfg.AutoCommitMsg)
}

func TestConfig_DefaultConfig(t *testing.T) {
	// ARRANGE & ACT
	cfg := DefaultConfig()

	// ASSERT
	assert.Equal(t, "go test -json ./...", cfg.TestCommand)
	assert.Equal(t, []string{"_test\\.go$"}, cfg.TestPatterns)
	assert.Equal(t, []string{"opencode.json", ".opencode/tcr"}, cfg.ProtectedPaths)
	assert.Equal(t, 30, cfg.Timeout)
	assert.Equal(t, "WIP", cfg.AutoCommitMsg)
}

func TestConfig_IsProtected_Path(t *testing.T) {
	testCases := []struct {
		name     string
		path     string
		expected bool
	}{
		{"Protected: opencode.json", "opencode.json", true},
		{"Protected: config file", ".opencode/tcr/config.yml", true},
		{"Not protected: test file", "pkg/auth/auth_test.go", false},
		{"Not protected: impl file", "pkg/auth/auth.go", false},
	}

	cfg := DefaultConfig()

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			result := cfg.IsProtected(tc.path)
			assert.Equal(t, tc.expected, result)
		})
	}
}

// Helper function to write test file
func writeTestFile(path, content string) error {
	return os.WriteFile(path, []byte(content), 0644)
}
