package overlay

import (
	"fmt"
	"os"
	"time"
)

// MountConfig holds parameters for mounting an overlay
type MountConfig struct {
	// LowerDir is the read-only base directory (project root)
	LowerDir string

	// UpperDir is the writable overlay layer (tmpfs typically)
	// All changes go here initially
	UpperDir string

	// WorkDir is where OverlayFS stores metadata and temporary files
	// Required by kernel, must be on same filesystem as UpperDir
	WorkDir string

	// MergedDir is the union mount point where lower + upper appear as one
	// Developers see and interact with this path
	MergedDir string
}

// OverlayMount represents an active overlay filesystem
type OverlayMount struct {
	Config    MountConfig
	MountedAt time.Time // When this overlay was mounted
	PID       int       // Process ID that mounted this
	// Internal state can be added as needed
}

// Mounter is the interface for overlay operations
// Implementation can be real (KernelMounter) or fake (FakeMounter)
type Mounter interface {
	// Mount creates and mounts an overlay filesystem
	// Returns error if LowerDir doesn't exist or already mounted
	Mount(config MountConfig) (*OverlayMount, error)

	// Unmount removes the mount and cleans up temporary directories
	// Safe to call multiple times
	Unmount(mount *OverlayMount) error

	// Commit merges changes from upper layer to lower layer
	// Persists all changes to real filesystem
	Commit(mount *OverlayMount) error

	// Discard removes upper layer without merging
	// All changes are lost (unless previously committed)
	Discard(mount *OverlayMount) error
}

// FakeMounter is a mock implementation for testing
type FakeMounter struct {
	// Track mounted paths to detect double-mounts
	mounts map[string]*OverlayMount

	// Simulate upper layer file storage
	files map[string][]byte
}

// NewFakeMounter creates a new mock mounter
func NewFakeMounter() *FakeMounter {
	return &FakeMounter{
		mounts: make(map[string]*OverlayMount),
		files:  make(map[string][]byte),
	}
}

// Mount simulates mounting without actual syscalls
func (f *FakeMounter) Mount(config MountConfig) (*OverlayMount, error) {
	// Check for double-mount
	if _, exists := f.mounts[config.MergedDir]; exists {
		return nil, fmt.Errorf("already mounted at %s", config.MergedDir)
	}

	mount := &OverlayMount{
		Config:    config,
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}
	f.mounts[config.MergedDir] = mount
	return mount, nil
}

// Unmount simulates unmounting
func (f *FakeMounter) Unmount(mount *OverlayMount) error {
	if mount == nil {
		return nil // Safe to call with nil
	}
	delete(f.mounts, mount.Config.MergedDir)
	return nil
}

// Commit simulates merging upper to lower
func (f *FakeMounter) Commit(mount *OverlayMount) error {
	if mount == nil {
		return fmt.Errorf("cannot commit nil mount")
	}
	// In real impl, would copy files from upper to lower
	// Here we just mark as committed
	return nil
}

// Discard simulates discarding changes
func (f *FakeMounter) Discard(mount *OverlayMount) error {
	if mount == nil {
		return fmt.Errorf("cannot discard nil mount")
	}
	// Clear simulated files
	f.files = make(map[string][]byte)
	return nil
}
