package overlay

import (
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestOverlayManager_ValidateMountConfig_Success(t *testing.T) {
	// Create temporary directories for testing
	tempDir, err := os.MkdirTemp("", "fireflow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create lower directory
	lowerDir := filepath.Join(tempDir, "lower")
	err = os.MkdirAll(lowerDir, 0755)
	assert.NoError(t, err)

	// Create upper, work, and merged directories
	upperDir := filepath.Join(tempDir, "upper")
	workDir := filepath.Join(tempDir, "work")
	mergedDir := filepath.Join(tempDir, "merged")

	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  lowerDir,
		UpperDir:  upperDir,
		WorkDir:   workDir,
		MergedDir: mergedDir,
	}

	// Act
	err = manager.ValidateMountConfig(config)

	// Assert
	assert.NoError(t, err)
}

func TestOverlayManager_ValidateMountConfig_MissingLowerDir(t *testing.T) {
	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  "", // Missing
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "lowerdir required")
}

func TestOverlayManager_ValidateMountConfig_NonExistentLowerDir(t *testing.T) {
	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  "/non/existent/path",
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	err := manager.ValidateMountConfig(config)

	// Assert
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "does not exist")
}

func TestOverlayManager_CreateTempDirs_Success(t *testing.T) {
	// Create temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fireflow-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	manager := NewOverlayManager()
	config := MountConfig{
		LowerDir:  "/tmp/lower", // Not used for this test
		UpperDir:  filepath.Join(tempDir, "upper"),
		WorkDir:   filepath.Join(tempDir, "work"),
		MergedDir: filepath.Join(tempDir, "merged"),
	}

	// Act
	err = manager.CreateTempDirs(&config)

	// Assert
	assert.NoError(t, err)

	// Verify directories were created
	upperInfo, err := os.Stat(config.UpperDir)
	assert.NoError(t, err)
	assert.True(t, upperInfo.IsDir())

	workInfo, err := os.Stat(config.WorkDir)
	assert.NoError(t, err)
	assert.True(t, workInfo.IsDir())

	mergedInfo, err := os.Stat(config.MergedDir)
	assert.NoError(t, err)
	assert.True(t, mergedInfo.IsDir())
}

func TestOverlayManager_CleanupTempDirs_Success(t *testing.T) {
	// Create temporary directory for testing
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

	manager := NewOverlayManager()
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
	_, err = os.Stat(upperDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(workDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))

	_, err = os.Stat(mergedDir)
	assert.Error(t, err)
	assert.True(t, os.IsNotExist(err))
}

func TestOverlayManager_GetOverlayMountPath(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mount
	mockMount := &OverlayMount{
		Config: MountConfig{
			MergedDir: "/tmp/test",
		},
	}

	// Act
	path := manager.GetOverlayMountPath(mockMount)

	// Assert
	assert.Equal(t, "/tmp/test", path)
}

func TestOverlayManager_GetOverlayMountPath_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	path := manager.GetOverlayMountPath(nil)

	// Assert
	assert.Equal(t, "", path)
}

func TestOverlayManager_GetOverlayUpperDir(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mount
	mockMount := &OverlayMount{
		Config: MountConfig{
			UpperDir: "/tmp/upper",
		},
	}

	// Act
	path := manager.GetOverlayUpperDir(mockMount)

	// Assert
	assert.Equal(t, "/tmp/upper", path)
}

func TestOverlayManager_GetOverlayUpperDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	path := manager.GetOverlayUpperDir(nil)

	// Assert
	assert.Equal(t, "", path)
}

func TestOverlayManager_GetOverlayWorkDir(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mount
	mockMount := &OverlayMount{
		Config: MountConfig{
			WorkDir: "/tmp/work",
		},
	}

	// Act
	path := manager.GetOverlayWorkDir(mockMount)

	// Assert
	assert.Equal(t, "/tmp/work", path)
}

func TestOverlayManager_GetOverlayWorkDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	path := manager.GetOverlayWorkDir(nil)

	// Assert
	assert.Equal(t, "", path)
}

func TestOverlayManager_GetOverlayLowerDir(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mount
	mockMount := &OverlayMount{
		Config: MountConfig{
			LowerDir: "/tmp/lower",
		},
	}

	// Act
	path := manager.GetOverlayLowerDir(mockMount)

	// Assert
	assert.Equal(t, "/tmp/lower", path)
}

func TestOverlayManager_GetOverlayLowerDir_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	path := manager.GetOverlayLowerDir(nil)

	// Assert
	assert.Equal(t, "", path)
}

func TestOverlayManager_FormatMountInfo(t *testing.T) {
	manager := NewOverlayManager()

	// Create a mock mount
	mockMount := &OverlayMount{
		Config: MountConfig{
			LowerDir:  "/tmp/lower",
			UpperDir:  "/tmp/upper",
			WorkDir:   "/tmp/work",
			MergedDir: "/tmp/merged",
		},
		MountedAt: time.Now(),
		PID:       1234,
	}

	// Act
	info := manager.FormatMountInfo(mockMount)

	// Assert
	assert.Contains(t, info, "Mount Info:")
	assert.Contains(t, info, "LowerDir: /tmp/lower")
	assert.Contains(t, info, "UpperDir: /tmp/upper")
	assert.Contains(t, info, "WorkDir: /tmp/work")
	assert.Contains(t, info, "MergedDir: /tmp/merged")
	assert.Contains(t, info, "PID: 1234")
}

func TestOverlayManager_FormatMountInfo_Nil(t *testing.T) {
	manager := NewOverlayManager()

	// Act
	info := manager.FormatMountInfo(nil)

	// Assert
	assert.Equal(t, "No mount information", info)
}
