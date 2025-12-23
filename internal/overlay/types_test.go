package overlay

import (
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestFakeMounter_Mount_Success(t *testing.T) {
	// Arrange
	m := NewFakeMounter()
	config := MountConfig{
		LowerDir:  "/tmp/lower",
		UpperDir:  "/tmp/upper",
		WorkDir:   "/tmp/work",
		MergedDir: "/tmp/merged",
	}

	// Act
	mount, err := m.Mount(config)

	// Assert
	assert.NoError(t, err)
	assert.NotNil(t, mount)
	assert.Equal(t, config, mount.Config)
	assert.True(t, mount.MountedAt.Before(time.Now().Add(1*time.Second)))
}

func TestFakeMounter_Mount_DoubleMountFails(t *testing.T) {
	m := NewFakeMounter()
	config := MountConfig{MergedDir: "/tmp/merged"}

	m.Mount(config)
	_, err := m.Mount(config) // Second mount

	assert.Error(t, err)
	assert.Contains(t, err.Error(), "already mounted")
}

func TestFakeMounter_Unmount_Success(t *testing.T) {
	m := NewFakeMounter()
	config := MountConfig{MergedDir: "/tmp/merged"}
	mount, _ := m.Mount(config)

	err := m.Unmount(mount)

	assert.NoError(t, err)
	_, exists := m.mounts["/tmp/merged"]
	assert.False(t, exists)
}

func TestFakeMounter_Unmount_SafeToCallTwice(t *testing.T) {
	m := NewFakeMounter()
	mount, _ := m.Mount(MountConfig{MergedDir: "/tmp/merged"})

	err1 := m.Unmount(mount)
	err2 := m.Unmount(mount) // Second call

	assert.NoError(t, err1)
	assert.NoError(t, err2) // Should not error
}

func TestFakeMounter_Unmount_NilSafe(t *testing.T) {
	m := NewFakeMounter()

	err := m.Unmount(nil)

	assert.NoError(t, err)
}

func TestMounterInterface_AllMethodsExist(t *testing.T) {
	var _ Mounter = (*FakeMounter)(nil)
	// If FakeMounter doesn't implement Mounter, compilation fails
}