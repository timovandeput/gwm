# GWM Architecture Design Document

## 1. Overview

GWM (Git Worktree Manager) is a command-line tool built in Dart that simplifies Git worktree management. This document
outlines the software architecture, component design, data flows, and testing strategy.

## 2. Technology Stack

### 2.1 Dart SDK Built-ins

- `dart:io` - File system operations, process spawning, platform detection
- `dart:async` - Async operations and Future handling
- `dart:convert` - JSON encoding/decoding

## 2. Architecture Layers

```mermaid
graph TB
    subgraph "Presentation Layer"
        CLI[CLI Entry Point]
        Commands[Command Handlers]
        Output[Output Formatters]
    end

    subgraph "Application Layer"
        WorktreeService[Worktree Service]
        ConfigService[Config Service]
        HookService[Hook Service]
        CopyService[Copy Service]
        ShellIntegration[Shell Integration]
    end

    subgraph "Domain Layer"
        Worktree[Worktree Model]
        Config[Config Model]
        Hook[Hook Model]
    end

    subgraph "Infrastructure Layer"
        GitClient[Git Client]
        FileSystem[File System Adapter]
        ProcessRunner[Process Runner]
        Prompt[Prompt/Selector]
    end

    CLI --> Commands
    Commands --> WorktreeService
    Commands --> ConfigService
    Commands --> HookService
    Commands --> CopyService
    Commands --> ShellIntegration
    Commands --> Output
    WorktreeService --> Worktree
    WorktreeService --> GitClient
    WorktreeService --> FileSystem
    ConfigService --> Config
    ConfigService --> FileSystem
    HookService --> Hook
    HookService --> ProcessRunner
    CopyService --> FileSystem
    CopyService --> Glob
    ShellIntegration --> Output
    GitClient --> ProcessRunner
    FileSystem --> ProcessRunner
```

## 3. Directory Structure

```
gwm/
├── bin/
│   └── gwm.dart                  # Main CLI entry point
├── lib/
│   ├── src/
│   │   ├── commands/             # Command handlers
│   │   ├── services/             # Business logic
│   │   ├── models/               # Domain models
│   │   ├── infrastructure/       # External integrations
│   │   ├── utils/                # Utilities
│   │   └── exceptions.dart       # Custom exceptions
│   └── gwm.dart                  # Library entry point
├── test/
│   ├── unit/                     # Unit tests
│   ├── integration/              # Integration tests
│   ├── fixtures/                 # Test fixtures
│   └── mock_objects/             # Test doubles
└── docs/
    ├── PRD.md
    ├── ARCHITECTURE.md           # This file
    └── TESTING.md
```

## 4. Core Components

### 4.1 Command Handlers

```mermaid
classDiagram
    class BaseCommand {
        <<abstract>>
        +ArgParser parser
        +execute(ArgResults) Future~ExitCode~
        #validate() ValidationResult
        #handleError(error) ExitCode
    }

    class AddCommand {
        +String branch
        +bool createBranch
        +execute() ExitCode
    }

    class SwitchCommand {
        +String? worktreeName
        +execute() ExitCode
    }

    class DeleteCommand {
        +bool force
        +execute() ExitCode
    }

    class ListCommand {
        +bool verbose
        +bool json
        +execute() ExitCode
    }

    BaseCommand <|-- AddCommand
    BaseCommand <|-- SwitchCommand
    BaseCommand <|-- DeleteCommand
    BaseCommand <|-- ListCommand
```

### 4.2 Worktree Service

The `WorktreeService` orchestrates worktree operations.

```mermaid
sequenceDiagram
    participant CMD as Command
    participant WS as WorktreeService
    participant GC as GitClient
    participant CS as CopyService
    participant HS as HookService
    participant FS as FileSystem
    CMD ->> WS: add(branch, createBranch)
    WS ->> WS: validateBranchExists()
    WS ->> WS: checkWorktreeNotExists()
    WS ->> GC: createBranch(createBranch)
    GC -->> WS: success
    WS ->> GC: createWorktree(path, branch)
    GC -->> WS: worktreePath
    WS ->> CS: copyFiles(config, worktreePath)
    CS ->> FS: readFiles()
    CS ->> FS: writeFiles()
    CS -->> WS: success
    WS ->> HS: executeHooks('pre_add', env)
    HS -->> WS: success
    WS ->> HS: executeHooks('post_add', env)
    HS -->> WS: success
    WS -->> CMD: ExitCode.success
```

### 4.3 Configuration Service

The `ConfigService` manages configuration loading with the 3-tier hierarchy:

```mermaid
graph LR
subgraph "Configuration Hierarchy"
G[Global Config<br/>~/.config/gwm/config.*]
R[Repo Config<br/>.gwm.*]
L[Local Config<br/>.gwm.local.*]
M[Merged Config]
end

G --> M
R --> M
L --> M

L -. override .-> R
R -. override .-> G

M -. " prepend/append " .-> L
```

**Configuration Merging Logic:**

1. Load global config (lowest priority)
2. Load repo config, override global settings
3. Load local config, apply override strategies:
    - Direct field: Complete override
    - `_prepend`: Add items before existing list
    - `_append`: Add items after existing list

### 4.4 Hook Service

The `HookService` executes shell commands with proper error handling:

```mermaid
flowchart TD
    Start[Execute Hook] --> Parse[Parse Hook Command]
    Parse --> Expand[Expand Environment Variables]
    Expand --> Timeout{Timeout Configured?}
    Timeout -->|Yes| UseTimeout[Use Per-Hook Timeout]
    Timeout -->|No| UseDefault[Use Global Timeout]
    UseTimeout --> Spawn[Spawn Process]
    UseDefault --> Spawn[Spawn Process]
    Spawn --> Stream[Stream stdout/stderr]
    Stream --> Monitor{Monitor Exit Code}
    Monitor -->|0| Success[Success]
    Monitor -->|Non - zero| Fail[Hook Failed]
    Fail --> Display[Display Error Output]
    Display --> Return[Return ExitCode.hookFailed]
    Success --> Return[Return ExitCode.success]
```

**Hook Execution Rules:**

- Execute commands sequentially
- Stop immediately on first failure
- Display all output (stdout + stderr)
- Terminate on timeout
- Exit with code 5 on failure

### 4.5 Copy Service

The `CopyService` handles file/directory copying with CoW optimization:

```mermaid
flowchart TD
    Start[Copy Files] --> Detect{Detect Platform}
    Detect -->|macOS + APFS| TryCoW[Try Clone]
    Detect -->|Linux + Btrfs/XFS| TryRefLink[Try Reflink]
    Detect -->|Other| Standard[Standard Copy]
    TryCoW --> CoWCheck{Clone Works?}
    CoWCheck -->|Yes| CoWSuccess[CoW Success]
    CoWCheck -->|No| Standard
    TryRefLink --> RefCheck{Reflink Works?}
    RefCheck -->|Yes| RefSuccess[Reflink Success]
    RefCheck -->|No| Standard
    Standard --> GlobMatch[Match Glob Patterns]
    GlobMatch --> CopyRecursive[Copy Recursively]
    CoWSuccess --> Done[Done]
    RefSuccess --> Done
    CopyRecursive --> Done
```

### 4.6 Git Client

The `GitClient` wraps all Git CLI operations:

```mermaid
classDiagram
    class GitClient {
        -ProcessWrapper _process
        -String _gitPath
        +createBranch(name) Future~void~
        +createWorktree(path, branch) Future~String~
        +listWorktrees() Future~List~Worktree~~
        +removeWorktree(path) Future~void~
        +getCurrentBranch() Future~String~
        +branchExists(branch) Future~bool~
        +hasUncommittedChanges() Future~bool~
    }

    class ProcessWrapper {
        <<interface>>
        +run(command, args) ProcessResult
        +runStreamed(command, args) Stream~String~
    }

    class DartProcessWrapper {
        +run(command, args) ProcessResult
        +runStreamed(command, args) Stream~String~
    }

GitClient --> ProcessWrapper
ProcessWrapper <|.. DartProcessWrapper
```

### 4.7 Shell Integration

Shell integration uses eval-output for directory switching:

```mermaid
sequenceDiagram
    participant User
    participant Shell
    participant GWM
    participant Output
    User ->> Shell: gwm switch feature-auth
    Shell ->> GWM: Execute with shell wrapper
    Note over Shell: Shell wrapper function with eval
    GWM->>GWM: Process command
    GWM->>Output: Generate eval output
    Note over Output: cd ~/work/worktrees/project_feature-auth
    Output-->>Shell: Return shell command
    Shell->>Shell: eval output
    Shell-->>User: Directory changed
```

## 5. Data Models

### 6.1 Worktree Model

The Worktree model represents a Git worktree with properties for name, branch, path, status, and timestamps. See `lib/src/models/worktree.dart` for the complete class definition.

### 6.2 Configuration Model

The configuration system uses hierarchical loading with global, repo, and local configs. It includes settings for copy operations, hooks, and shell integration. See `lib/src/models/config.dart` for the complete configuration model definitions.

## 6. Error Handling

### 6.1 Exception Hierarchy

```mermaid
classDiagram
    class GwmException {
        <<abstract>>
        +ExitCode exitCode
        +String message
    }

    class WorktreeExistsException {
        +String worktreeName
    }

    class BranchNotFoundException {
        +String branch
    }

    class HookExecutionException {
        +String hookName
        +String command
        +String output
    }

    class ConfigException {
        +String configPath
        +String reason
    }

    class GitException {
        +String command
        +String arguments
        +String output
    }

    GwmException <|-- WorktreeExistsException
    GwmException <|-- BranchNotFoundException
    GwmException <|-- HookExecutionException
    GwmException <|-- ConfigException
    GwmException <|-- GitException
```

### 6.2 Error Recovery Strategy

The PRD specifies: **Leave partial state with clear error message**

```mermaid
flowchart TD
    Operation[Start Operation] --> Step1[Step 1: Create Branch]
    Step1 --> Step2[Step 2: Create Worktree]
    Step2 --> Step3[Step 3: Copy Files]
    Step3 --> Step4[Step 4: Execute Hooks]
    Step4 --> HookResult{Hook Success?}
    HookResult -->|Yes| Complete[Complete]
    HookResult -->|No| Partial[Partial State]
    Partial --> Message[Display Clear Error]
    Message --> Guidance[Provide Recovery Guidance]
    Guidance --> Exit[Exit with Non-Zero Code]
    Complete --> Exit[Exit with Code 0]
```

**Recovery Guidance Examples:**

- Hook failed: `npm install exited with status 1` → Run manually or fix issue and retry
- Git failed: `branch not found` → Use `-b` flag to create branch
- Copy failed: `Source file not found` → Check config and source path

## 7. Testing Strategy

### 7.1 Testing Philosophy

**Core Principle: Never invoke actual external tools in tests**

All tests use test doubles and mocks to ensure:

- Fast test execution
- Deterministic behavior
- Cross-platform test consistency
- No side effects on user environment

### 7.2 Test Pyramid

```mermaid
graph TD
    subgraph Pyramid["GWM Test Pyramid"]
        AT["Acceptance Tests<br/>10%<br/>User-facing behavior<br/>CLI interface"]
        UT["Unit Tests<br/>80%<br/>Service logic<br/>Model validation<br/>Utility functions"]
        IT["Integration Tests<br/>10%<br/>Full workflow scenarios<br/>End-to-end command execution"]
    end

    AT --- UT
    UT --- IT

    style UT fill:#90EE90,color:#000000
    style IT fill:#87CEEB,color:#000000
    style AT fill:#FFB6C1,color:#000000
```

### 7.3 Unit Testing

Unit tests focus on individual components with mocked dependencies. External tools like Git and file system operations are mocked to avoid side effects.

### 7.4 Integration Testing

Integration tests verify end-to-end command workflows using fake implementations for all external dependencies.

### 7.5 Test Coverage Goals

| Component      | Target Coverage |
|----------------|-----------------|
| Commands       | 90%+            |
| Services       | 95%+            |
| Models         | 100%            |
| Infrastructure | 90%+            |
| Utils          | 95%+            |
| Overall        | 90%+            |

### 7.6 Running Tests

```bash
# Run all tests
dart test

# Run with coverage
dart test --coverage=coverage

# Run unit tests only
dart test test/unit/

# Run integration tests only
dart test test/integration/

# Run specific test
dart test test/unit/services/worktree_service_test.dart

# Run tests matching pattern
dart test -n "add worktree"
```

## 8. Cross-Platform Considerations

### 8.1 Platform Detection

Platform detection identifies the operating system to enable appropriate filesystem and process handling. See `lib/src/infrastructure/platform_detector.dart` for platform detection logic.

### 8.2 Path Handling

```mermaid
flowchart TD
    Input[Path Input] --> Detect{Detect Platform}
    Detect -->|Windows| WinStyle[Use Backslashes]
    Detect -->|Unix| UnixStyle[Use Forward Slashes]
    WinStyle --> Normalize[Normalize Path]
    UnixStyle --> Normalize
    Normalize --> Output[Platform Path]
```

### 8.3 Shell Detection

Shell detection automatically identifies the user's shell environment for proper command execution. See `lib/src/utils/shell_detector.dart` for the shell detection implementation.

## 9. Security Considerations

### 9.1 Command Injection Prevention

Input validation prevents command injection by rejecting dangerous shell metacharacters and path traversal attempts. See `lib/src/utils/validation.dart` for command validation logic.

### 9.2 Path Validation

Path validation ensures all file operations stay within allowed directories to prevent directory traversal attacks. See `lib/src/utils/validation.dart` for path validation utilities.

### 9.3 Config Validation

Configuration validation ensures all settings are within safe bounds, including timeout limits and safe glob patterns. See `lib/src/utils/validation.dart` for configuration validation logic.

## 10. Performance Optimization

### 10.1 Copy-on-Write Detection

Copy operations automatically detect filesystem capabilities to use efficient copy-on-write techniques where available (APFS clone on macOS, reflink on Linux). See `lib/src/services/copy_service.dart` for copy strategy selection.

### 10.2 Lazy Configuration Loading

Configuration loading uses lazy initialization and caching to minimize I/O operations during repeated access. See `lib/src/services/config_service.dart` for configuration loading implementation.


