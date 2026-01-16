# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Retriever is an iOS application built with SwiftUI, managed using Tuist for project generation.

## Build Commands

All commands should be run from the `Retriever/` directory.

```bash
# Install Tuist (via mise)
mise install

# Generate Xcode project
tuist generate

# Build the project
tuist build

# Run tests
tuist test

# Clean build artifacts
tuist clean
```

## Architecture

- **Tuist-managed project**: Project configuration is defined in `Project.swift`, not in `.xcodeproj` files (which are gitignored and generated)
- **Dependencies**: External dependencies are declared in `Tuist/Package.swift` using Swift Package Manager format
- **Tuist configuration**: `Tuist.swift` contains Tuist-specific settings

### Directory Structure

```
Retriever/
├── Project.swift           # Tuist project definition
├── Tuist.swift             # Tuist configuration
├── Tuist/
│   └── Package.swift       # SPM dependencies
└── Retriever/
    ├── Sources/            # App source code
    ├── Resources/          # Assets, previews
    └── Tests/              # Unit tests
```

### Targets

- **Retriever**: Main iOS app target (bundleId: `dev.tuist.Retriever`)
- **RetrieverTests**: Unit test target

## Testing

Tests use the Swift Testing framework (`import Testing`) with `@Test` macro syntax.
