# Command Interface

This package implements a consistent command interface for Fire-Flow CLI commands.

## Design Principles

The Command interface follows Kent Beck's principles of simplicity and consistency:

1. **Simple Interface**: The interface only defines one method `Execute()` that returns an error
2. **Consistent Design**: All commands implement the same interface
3. **Factory Pattern**: Commands are created through a factory for easy extensibility
4. **Error Handling**: All commands return errors for proper error propagation

## Package Structure

The command package is organized as follows:
- `command.go`: Contains the Command interface, CommandFactory, and all command implementations
- `utils.go`: Contains shared utility functions moved from main.go
- `README.md`: This documentation file

## Interface Definition

```go
type Command interface {
    Execute() error
}
```

## Usage

Commands are created through the CommandFactory:

```go
factory := &CommandFactory{}
cmd, err := factory.NewCommand("init")
if err != nil {
    // handle error
}
err = cmd.Execute()
```

## Adding New Commands

To add a new command:

1. Implement the Command interface
2. Add the command name to the switch statement in CommandFactory.NewCommand()
3. Add any necessary helper functions to the package