package overlay

import (
	"errors"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestOverlayError_Error(t *testing.T) {
	innerErr := errors.New("inner error")
	err := &OverlayError{
		Op:  "mount",
		Err: innerErr,
	}

	expected := "overlay mount failed: inner error"
	assert.Equal(t, expected, err.Error())
	assert.Equal(t, innerErr, err.Unwrap())
}

func TestMountError_Error(t *testing.T) {
	innerErr := errors.New("detailed error")
	err := &MountError{
		Reason: "permission_denied",
		Detail: innerErr,
	}

	expected := "mount error (permission_denied): detailed error"
	assert.Equal(t, expected, err.Error())
}

func TestMountError_ErrorNoDetail(t *testing.T) {
	err := &MountError{
		Reason: "no_device",
	}

	expected := "mount error: no_device"
	assert.Equal(t, expected, err.Error())
}

func TestErrAlreadyMounted_Error(t *testing.T) {
	err := &ErrAlreadyMounted{
		Path: "/tmp/test",
	}

	expected := "path already mounted: /tmp/test"
	assert.Equal(t, expected, err.Error())
}

func TestErrNotMounted_Error(t *testing.T) {
	err := &ErrNotMounted{
		Path: "/tmp/test",
	}

	expected := "path not mounted: /tmp/test"
	assert.Equal(t, expected, err.Error())
}

func TestUserFriendlyError_MountError(t *testing.T) {
	err := &MountError{
		Reason: "permission_denied",
	}

	expected := "Permission denied. Try: sudo fire-flow watch"
	assert.Equal(t, expected, UserFriendlyError(err))
}

func TestUserFriendlyError_AlreadyMounted(t *testing.T) {
	err := &ErrAlreadyMounted{
		Path: "/tmp/test",
	}

	expected := "Already mounted at /tmp/test. Unmount first."
	assert.Equal(t, expected, UserFriendlyError(err))
}

func TestUserFriendlyError_GenericError(t *testing.T) {
	err := errors.New("generic error")

	expected := "generic error"
	assert.Equal(t, expected, UserFriendlyError(err))
}