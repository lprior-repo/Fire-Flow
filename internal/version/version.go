// Package version provides version information for Fire-Flow
package version

const (
	// Version is the current version of Fire-Flow
	Version = "0.1.0"
	// Name is the application name
	Name = "Fire-Flow"
)

// Info returns formatted version information
func Info() string {
	return Name + " v" + Version
}
