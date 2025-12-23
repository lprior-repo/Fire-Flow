package overlay

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sync"
	"syscall"
	"time"
)

// KernelMounter implements Mounter using Linux OverlayFS syscalls
type KernelMounter struct {
	// Optional: track mounted paths for debugging
	activeMounts map[string]*OverlayMount
	mu           sync.RWMutex
}

// NewKernelMounter creates kernel-based mounter
func NewKernelMounter() *KernelMounter {
	return &KernelMounter{
		activeMounts: make(map[string]*OverlayMount),
	}
}

// Mount creates and mounts an overlay filesystem
func (k *KernelMounter) Mount(config MountConfig) (*OverlayMount, error) {
	// Step 1: Validate LowerDir exists
	info, err := os.Stat(config.LowerDir)
	if err != nil {
		return nil, &MountError{Reason: "invalid_config", Detail: fmt.Errorf("lowerdir not found: %w", err)}
	}
	if !info.IsDir() {
		return nil, &MountError{Reason: "invalid_config", Detail: fmt.Errorf("lowerdir must be directory: %s", config.LowerDir)}
	}

	// Step 2: Create temporary directories
	if err := os.MkdirAll(config.UpperDir, 0700); err != nil {
		return nil, &MountError{Reason: "create_upperdir", Detail: fmt.Errorf("failed to create upperdir: %w", err)}
	}

	if err := os.MkdirAll(config.WorkDir, 0700); err != nil {
		os.RemoveAll(config.UpperDir) // cleanup on failure
		return nil, &MountError{Reason: "create_workdir", Detail: fmt.Errorf("failed to create workdir: %w", err)}
	}

	if err := os.MkdirAll(config.MergedDir, 0700); err != nil {
		os.RemoveAll(config.UpperDir)
		os.RemoveAll(config.WorkDir)
		return nil, &MountError{Reason: "create_mergeddir", Detail: fmt.Errorf("failed to create mergeddir: %w", err)}
	}

	// Step 3: Build mount options
	opts := fmt.Sprintf("lowerdir=%s,upperdir=%s,workdir=%s",
		config.LowerDir, config.UpperDir, config.WorkDir)

	// Step 4: Execute mount syscall
	err = syscall.Mount("overlay", config.MergedDir, "overlay", 0, opts)
	if err != nil {
		// Cleanup on mount failure
		os.RemoveAll(config.UpperDir)
		os.RemoveAll(config.WorkDir)
		os.RemoveAll(config.MergedDir)

		// Helpful error messages
		if err == syscall.EPERM {
			return nil, &MountError{Reason: "permission_denied", Detail: err}
		}
		if err == syscall.ENODEV {
			return nil, &MountError{Reason: "no_device", Detail: err}
		}
		return nil, &MountError{Reason: "mount_failed", Detail: err}
	}

	// Step 5: Create OverlayMount record
	mount := &OverlayMount{
		Config:    config,
		MountedAt: time.Now(),
		PID:       os.Getpid(),
	}

	k.mu.Lock()
	k.activeMounts[config.MergedDir] = mount
	k.mu.Unlock()
	return mount, nil
}

// Unmount removes the mount and cleans up directories
func (k *KernelMounter) Unmount(mount *OverlayMount) error {
	if mount == nil {
		return nil // Safe to call with nil
	}

	// Try standard unmount first
	err := syscall.Unmount(mount.Config.MergedDir, 0)

	// If that fails, try with MNT_FORCE
	if err != nil {
		if err := syscall.Unmount(mount.Config.MergedDir, syscall.MNT_FORCE); err != nil {
			// Log but continue cleanup
			fmt.Fprintf(os.Stderr, "warning: forced unmount failed: %v\n", err)
		}
	}

	// Cleanup temporary directories (best effort)
	os.RemoveAll(mount.Config.MergedDir)
	os.RemoveAll(mount.Config.UpperDir)
	os.RemoveAll(mount.Config.WorkDir)

	k.mu.Lock()
	delete(k.activeMounts, mount.Config.MergedDir)
	k.mu.Unlock()
	return nil
}

// Commit merges changes from upper to lower
func (k *KernelMounter) Commit(mount *OverlayMount) error {
	if mount == nil {
		return &OverlayError{Op: "commit", Err: &ErrInvalidMount{}}
	}

	return filepath.Walk(mount.Config.UpperDir,
		func(path string, info os.FileInfo, err error) error {
			if err != nil {
				return err
			}

			// Skip the root upper directory itself
			if path == mount.Config.UpperDir {
				return nil
			}

			// Calculate relative path
			rel, err := filepath.Rel(mount.Config.UpperDir, path)
			if err != nil {
				return err
			}

			dstPath := filepath.Join(mount.Config.LowerDir, rel)

			// Handle whiteouts (deleted files)
			if isWhiteout(info) {
				// File was deleted in overlay
				os.RemoveAll(dstPath)
				return nil
			}

			// Handle directories
			if info.IsDir() {
				return os.MkdirAll(dstPath, info.Mode().Perm())
			}

			// Copy regular files
			return copyFile(path, dstPath)
		})
}

// Discard removes upper layer without committing
func (k *KernelMounter) Discard(mount *OverlayMount) error {
	if mount == nil {
		return &OverlayError{Op: "discard", Err: &ErrInvalidMount{}}
	}

	// Remove all contents of upper directory
	return os.RemoveAll(mount.Config.UpperDir)
}

// isWhiteout detects OverlayFS deletion markers
func isWhiteout(info os.FileInfo) bool {
	if info.Mode()&os.ModeCharDevice == 0 {
		return false
	}
	stat := info.Sys().(*syscall.Stat_t)
	return stat.Rdev == 0
}

// copyFile copies a file with permissions preserved
func copyFile(src, dst string) error {
	srcFile, err := os.Open(src)
	if err != nil {
		return fmt.Errorf("open source: %w", err)
	}
	defer srcFile.Close()

	srcInfo, err := srcFile.Stat()
	if err != nil {
		return fmt.Errorf("stat source: %w", err)
	}

	dstFile, err := os.Create(dst)
	if err != nil {
		return fmt.Errorf("create destination: %w", err)
	}
	defer dstFile.Close()

	if _, err := io.Copy(dstFile, srcFile); err != nil {
		return fmt.Errorf("copy contents: %w", err)
	}

	return os.Chmod(dst, srcInfo.Mode().Perm())
}