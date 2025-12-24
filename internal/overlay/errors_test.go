package overlay

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestOverlayError_Error(t *testing.T) {
	// Arrange
	err := &OverlayError{
		Op:  "Mount",
		Err: errors.New("test error"),
	}

	// Act
	result := err.Error()

	// Assert
	assert.Equal(t, "overlay Mount failed: test error", result)
}

func TestOverlayError_Unwrap(t *testing.T) {
	// Arrange
	baseErr := errors.New("base error")
	err := &OverlayError{
		Op:  "Mount",
		Err: baseErr,
	}

	// Act
	unwrapped := err.Unwrap()

	// Assert
	assert.Equal(t, baseErr, unwrapped)
}

func TestMountError_ErrorWithDetail(t *testing.T) {
	// Arrange
	err := &MountError{
		Reason: "permission_denied",
		Detail: errors.New("access denied"),
	}

	// Act
	result := err.Error()

	// Assert
	assert.Equal(t, "mount error (permission_denied): access denied", result)
}

func TestMountError_ErrorWithoutDetail(t *testing.T) {
	// Arrange
	err := &MountError{
		Reason: "no_device",
	}

	// Act
	result := err.Error()

	// Assert
	assert.Equal(t, "mount error: no_device", result)
}

func TestErrAlreadyMounted_Error(t *testing.T) {
	// Arrange
	err := &ErrAlreadyMounted{
		Path: "/tmp/test",
	}

	// Act
	result := err.Error()

	// Assert
	assert.Equal(t, "path already mounted: /tmp/test", result)
}

func TestErrNotMounted_Error(t *testing.T) {
	// Arrange
	err := &ErrNotMounted{
		Path: "/tmp/test",
	}

	// Act
	result := err.Error()

	// Assert
	assert.Equal(t, "path not mounted: /tmp/test", result)
}

func TestUserFriendlyError_MountError(t *testing.T) {
	// Arrange
	err := &MountError{
		Reason: "permission_denied",
	}

	// Act
	result := UserFriendlyError(err)

	// Assert
	assert.Equal(t, "Permission denied. Try: sudo fire-flow watch", result)
}

func TestUserFriendlyError_AlreadyMounted(t *testing.T) {
	// Arrange
	err := &ErrAlreadyMounted{
		Path: "/tmp/test",
	}

	// Act
	result := UserFriendlyError(err)

	// Assert
	assert.Equal(t, "Already mounted at /tmp/test. Unmount first.", result)
}

func TestUserFriendlyError_GenericError(t *testing.T) {
	// Arrange
	err := errors.New("generic error")

	// Act
	result := UserFriendlyError(err)

	// Assert
	assert.Equal(t, "generic error", result)
}