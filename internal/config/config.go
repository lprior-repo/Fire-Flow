package config

import (
	"os"
	"path/filepath"
	"strconv"
	"strings"

	"gopkg.in/yaml.v3"
)

// Config holds the TCR enforcer configuration.
type Config struct {
	TestCommand    string   `yaml:"testCommand"`
	TestPatterns   []string `yaml:"testPatterns"`
	ProtectedPaths []string `yaml:"protectedPaths"`
	Timeout        int      `yaml:"timeout"`
	AutoCommitMsg  string   `yaml:"autoCommitMsg"`
	OverlayWorkDir string   `yaml:"overlayWorkDir"`
	WatchDebounce  int      `yaml:"watchDebounce"`
	WatchIgnore    []string `yaml:"watchIgnore"`
}

// DefaultConfig returns the default configuration.
func DefaultConfig() *Config {
	return &Config{
		TestCommand:    "go test -json ./...",
		TestPatterns:   []string{"_test\\.go$"},
		ProtectedPaths: []string{"opencode.json", ".opencode/tcr"},
		Timeout:        30,
		AutoCommitMsg:  "WIP",
		OverlayWorkDir: "/tmp/fire-flow-overlay-work",
		WatchDebounce:  500,
		WatchIgnore:    []string{".git", "node_modules", ".opencode"},
	}
}

// LoadFromFile loads configuration from a YAML file.
// If the file doesn't exist, returns default config with no error.
func LoadFromFile(filePath string) (*Config, error) {
	// Load from file
	data, err := os.ReadFile(filePath)
	if err != nil {
		if os.IsNotExist(err) {
			return DefaultConfig(), nil
		}
		return nil, err
	}

	cfg := DefaultConfig()
	if err := yaml.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	// Override with environment variables if set
	if testCommand := os.Getenv("TDD_TEST_COMMAND"); testCommand != "" {
		cfg.TestCommand = testCommand
	}
	
	if timeoutStr := os.Getenv("TDD_TIMEOUT"); timeoutStr != "" {
		if timeout, err := strconv.Atoi(timeoutStr); err == nil {
			cfg.Timeout = timeout
		}
	}
	
	if autoCommitMsg := os.Getenv("TDD_AUTO_COMMIT_MSG"); autoCommitMsg != "" {
		cfg.AutoCommitMsg = autoCommitMsg
	}

	return cfg, nil
}

// SaveToFile persists configuration to a YAML file.
func (c *Config) SaveToFile(filePath string) error {
	data, err := yaml.Marshal(c)
	if err != nil {
		return err
	}
	return os.WriteFile(filePath, data, 0644)
}

// IsProtected checks if a file path is in the protected paths list.
// It supports basic glob patterns (e.g., ".opencode/tcr" matches ".opencode/tcr/config.yml").
func (c *Config) IsProtected(filePath string) bool {
	for _, protectedPath := range c.ProtectedPaths {
		// Exact match
		if filePath == protectedPath {
			return true
		}
		// Check if file is within a protected directory
		if strings.HasPrefix(filePath, protectedPath+"/") {
			return true
		}
		// Glob pattern matching (simple)
		if matched, _ := filepath.Match(protectedPath, filePath); matched {
			return true
		}
	}
	return false
}