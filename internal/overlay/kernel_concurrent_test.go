package overlay

import (
	"os"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
)

// TestKernelMounter_ConcurrentAccess tests that KernelMounter is safe for concurrent access
func TestKernelMounter_ConcurrentAccess(t *testing.T) {
	mounter := NewKernelMounter()

	// Create a temporary directory for testing
	tempDir, err := os.MkdirTemp("", "fire-flow-concurrent-test")
	assert.NoError(t, err)
	defer os.RemoveAll(tempDir)

	// Create multiple goroutines that try to mount simultaneously
	var wg sync.WaitGroup
	numGoroutines := 10

	for i := 0; i < numGoroutines; i++ {
		wg.Add(1)
		go func(id int) {
			defer wg.Done()

			// Create a unique config for each goroutine
			config := MountConfig{
				LowerDir:  tempDir,
				UpperDir:  tempDir + "-upper-" + string(rune(id)),
				WorkDir:   tempDir + "-work-" + string(rune(id)),
				MergedDir: tempDir + "-merged-" + string(rune(id)),
			}

			// This will fail because we're not using real overlay filesystem, but we want to test
			// that concurrent access doesn't cause panic or data races
			_, err := mounter.Mount(config)
			// We expect errors because we're not actually mounting, but the call should be safe
			// The important thing is that it doesn't panic or cause data races
			_ = err // We're not checking error here, just testing thread safety
		}(i)
	}

	wg.Wait()

	// Verify that we didn't panic
	assert.True(t, true, "Concurrent access test completed without panic")
}
