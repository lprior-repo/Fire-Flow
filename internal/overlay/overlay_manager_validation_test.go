package overlay

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestOverlayManager_ValidateMountConfig_Comprehensive tests various validation scenarios
func TestOverlayManager_ValidateMountConfig_Comprehensive(t *testing.T) {
	manager := NewOverlayManager()

	// Create temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fireflow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create lower directory
	lowerDir := filepath.Join(tempDir, "lower")
	err = os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Test cases with table-driven approach
	testCases := []struct {
		name    string
		config  MountConfig
		wantErr bool
		errMsg  string
	}{
		{
			name: "valid config",
			config: MountConfig{
				LowerDir:  lowerDir,
				UpperDir:  filepath.Join(tempDir, "upper"),
				WorkDir:   filepath.Join(tempDir, "work"),
				MergedDir: filepath.Join(tempDir, "merged"),
			},
			wantErr: false,
		},
		{
			name: "missing lowerdir",
			config: MountConfig{
				LowerDir:  "",
				UpperDir:  "/tmp/upper",
				WorkDir:   "/tmp/work",
				MergedDir: "/tmp/merged",
			},
			wantErr: true,
			errMsg:  "lowerdir required",
		},
		{
			name: "missing upperdir",
			config: MountConfig{
				LowerDir:  lowerDir,
				UpperDir:  "",
				WorkDir:   "/tmp/work",
				MergedDir: "/tmp/merged",
			},
			wantErr: true,
			errMsg:  "upperdir required",
		},
		{
			name: "missing workdir",
			config: MountConfig{
				LowerDir:  lowerDir,
				UpperDir:  "/tmp/upper",
				WorkDir:   "",
				MergedDir: "/tmp/merged",
			},
			wantErr: true,
			errMsg:  "workdir required",
		},
		{
			name: "missing mergeddir",
			config: MountConfig{
				LowerDir:  lowerDir,
				UpperDir:  "/tmp/upper",
				WorkDir:   "/tmp/work",
				MergedDir: "",
			},
			wantErr: true,
			errMsg:  "mergeddir required",
		},
		{
			name: "non-existent lowerdir",
			config: MountConfig{
				LowerDir:  "/non/existent/path",
				UpperDir:  "/tmp/upper",
				WorkDir:   "/tmp/work",
				MergedDir: "/tmp/merged",
			},
			wantErr: true,
			errMsg:  "does not exist",
		},
	}

	for _, tt := range testCases {
		t.Run(tt.name, func(t *testing.T) {
			// Act
			err := manager.ValidateMountConfig(tt.config)

			// Assert
			if tt.wantErr {
				assert.Error(t, err)
				assert.Contains(t, err.Error(), tt.errMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}

// TestOverlayManager_CreateTempDirs_Comprehensive tests CreateTempDirs functionality
func TestOverlayManager_CreateTempDirs_Comprehensive(t *testing.T) {
	manager := NewOverlayManager()

	// Create temp directories
	tempDir := t.TempDir()

	// Test valid config
	config := MountConfig{
		LowerDir:  "/tmp", // Not used for this test
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err := manager.CreateTempDirs(&config)

	// Assert
	assert.NoError(t, err)

	// Verify directories were created
	info, err := os.Stat(config.UpperDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())

	info, err = os.Stat(config.WorkDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())

	info, err = os.Stat(config.MergedDir)
	assert.NoError(t, err)
	assert.True(t, info.IsDir())
}

// TestOverlayManager_CreateTempDirs_InvalidConfig tests CreateTempDirs with invalid config
func TestOverlayManager_CreateTempDirs_InvalidConfig(t *testing.T) {
	manager := NewOverlayManager()

	// Test invalid config with empty paths
	config := MountConfig{
		LowerDir:  "/tmp",
		UpperDir:  "",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.CreateTempDirs(&config)

	// Assert
	assert.Error(t, err)
}

// TestOverlayManager_CleanupTempDirs_Comprehensive tests various CleanupTempDirs scenarios
func TestOverlayManager_CleanupTempDirs_Comprehensive(t *testing.T) {
	manager := NewOverlayManager()

	// Create temporary directories for testing
	tempDir, err := os.MkdirTemp("", "fireflow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create some test files in directories
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	mergedDir := filepath.Join(tempDir, "merged")

	for _, dir := range []string{upperDir, workDir, mergedDir} {
		err = os.MkdirAll(dir, 0755)
		assert.NoError(t, err)
		// Add a test file
		testFile := filepath.Join(dir, "test.txt")
		err = os.WriteFile(testFile, []byte("test"), 0644)
		assert.NoError(t, err)
	}

	config := MountConfig{
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Act
	err = manager.CleanupTempDirs(config)

	// Assert
	assert.NoError(t, err)

	// Verify directories were cleaned up
	for _, dir := range []string{upperDir, workDir, mergedDir} {
		_, err = os.Stat(dir)
		assert.Error(t, err)
		assert.True(t, os.IsNotExist(err))
	}
}
