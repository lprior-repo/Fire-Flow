package overlay

import (
	"fmt"
)

// OverlayError is the base error type for overlay operations
type OverlayError struct {
	Op  string // Operation (Mount, Unmount, Commit, Discard)
	Err error  // Underlying error
}

func (e *OverlayError) Error() string {
	return fmt.Sprintf("overlay %s failed: %v", e.Op, e.Err)
}

func (e *OverlayError) Unwrap() error {
	return e.Err
}

// MountError wraps mount-specific errors
type MountError struct {
	Reason string // "permission_denied", "no_device", "invalid_config"
	Detail error
}

func (e *MountError) Error() string {
	if e.Detail != nil {
		return fmt.Sprintf("mount error (%s): %v", e.Reason, e.Detail)
	}
	return fmt.Sprintf("mount error: %s", e.Reason)
}

// ErrAlreadyMounted indicates a path is already mounted
type ErrAlreadyMounted struct {
	Path string
}

func (e *ErrAlreadyMounted) Error() string {
	return fmt.Sprintf("path already mounted: %s", e.Path)
}

// ErrNotMounted indicates operation on non-mounted path
type ErrNotMounted struct {
	Path string
}

func (e *ErrNotMounted) Error() string {
	return fmt.Sprintf("path not mounted: %s", e.Path)
}

// UserFriendlyError returns a message suitable for CLI output
func UserFriendlyError(err error) string {
	switch e := err.(type) {
	case *MountError:
		switch e.Reason {
		case "permission_denied":
			return "Permission denied. Try: sudo fire-flow watch"
		case "no_device":
			return "OverlayFS not supported. Kernel update may be needed."
		default:
			return e.Error()
		}
	case *ErrAlreadyMounted:
		return fmt.Sprintf("Already mounted at %s. Unmount first.", e.Path)
	default:
		return err.Error()
	}
}