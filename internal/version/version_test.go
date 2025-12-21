package version

import "testing"

func TestInfo(t *testing.T) {
	expected := "Fire-Flow v0.1.0"
	actual := Info()

	if actual != expected {
		t.Errorf("Info() = %q, want %q", actual, expected)
	}
}

func TestVersion(t *testing.T) {
	if Version == "" {
		t.Error("Version should not be empty")
	}
}

func TestName(t *testing.T) {
	if Name != "Fire-Flow" {
		t.Errorf("Name = %q, want %q", Name, "Fire-Flow")
	}
}
