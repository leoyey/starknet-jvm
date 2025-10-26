# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

starknet-jvm is a Starknet SDK for JVM languages (Java, Kotlin, Scala, Clojure, Groovy). It provides abstractions for interacting with the Starknet blockchain through JSON-RPC, including account management, transaction signing, and contract interaction.

## Prerequisites

Development requires:
- `starknet-devnet-rs` - Set `DEVNET_PATH` environment variable to binary location
- `starknet-foundry` - Provides `sncast` CLI
- `asdf` version manager with `asdf-scarb` plugin
- Java 11+ with `JAVA_HOME` environment variable set
- `cmake` 3.18.1+

## Common Commands

### Building
```bash
# Standard build
./gradlew build

# Build with native crypto libraries included
./gradlew jarWithNative

# Clean build artifacts
./gradlew clean

# Build crypto libraries only (for current platform)
./gradlew BuildCrypto

# Build multi-platform JAR (Darwin + Linux x86_64 + Linux aarch64)
# This uses Docker to cross-compile Linux libraries
./build_multiarch_natives.sh
./gradlew :lib:jar :lib:publishToMavenLocal
```

**Multi-Platform Build Notes:**
- `./gradlew jarWithNative` only builds for your current platform (macOS on Mac, Linux on Linux)
- To create a JAR that works on **all platforms** (macOS, Linux x86_64, Linux aarch64):

**Option 1: Local Build (requires Docker)**
  1. Run `./build_multiarch_natives.sh` to build Linux libraries using Docker
  2. Then run `./gradlew :lib:jar :lib:publishToMavenLocal` to package everything

**Option 2: GitHub Actions Build (recommended for slow networks)**
  1. Push your changes to GitHub
  2. Go to Actions → "Build Multi-Arch JAR" workflow
  3. Click "Run workflow" button
  4. Wait ~10-15 minutes for build to complete
  5. Download the JAR artifact from the workflow run page
  6. Install to local Maven:
     ```bash
     mvn install:install-file \
       -Dfile=lib-0.16.1.jar \
       -DgroupId=com.swmansion.starknet \
       -DartifactId=starknet \
       -Dversion=0.16.1 \
       -Dpackaging=jar
     ```

### Testing
```bash
# Run all tests (requires devnet)
./gradlew :lib:test

# Run tests with network testing enabled (non-gas)
./gradlew :lib:test -PnetworkTestMode=non_gas

# Run all tests including gas tests (⚠️ consumes funds)
./gradlew :lib:test -PnetworkTestMode=all

# Run specific test class
./gradlew :lib:test --tests "ClassName"
```

**Network Test Configuration**: Copy `test_variables.env.example` to `.env` and configure:
- `NETWORK_TEST_MODE`: `disabled`, `non_gas`, or `all`
- `NETWORK_TEST_NETWORK_NAME`: `SEPOLIA_TESTNET` or `SEPOLIA_INTEGRATION`
- Network-specific variables: `{NETWORK_NAME}_RPC_URL`, `{NETWORK_NAME}_ACCOUNT_ADDRESS`, `{NETWORK_NAME}_PRIVATE_KEY`

### Code Quality
```bash
# Lint Kotlin code
./gradlew lintKotlin

# Format Kotlin code
./gradlew formatKotlin

# Install pre-push hook for linting
./gradlew installKotlinterPrePushHook
```

### Documentation
```bash
# Generate user guides from guide.md
./gradlew generateGuides

# Build Kotlin API docs
./gradlew dokkaHtml

# Build Java API docs
./gradlew dokkaHtmlJava
```

## Architecture

### Core Modules

**Provider Layer** (`com.swmansion.starknet.provider`)
- `Provider` interface: Abstract provider for Starknet interaction
- `JsonRpcProvider`: Concrete implementation using JSON-RPC
- `Request<T>`: Lazy request pattern - requests are not executed until `.send()` is called
- All provider methods return `Request<T>` for deferred execution

**Account Layer** (`com.swmansion.starknet.account`)
- `Account` interface: Transaction signing and execution abstraction
- `StandardAccount`: Default implementation supporting V3 transactions
- Handles nonce management, fee estimation, and transaction signing
- Accounts require a Provider, chain ID, address, and signing key

**Data Types** (`com.swmansion.starknet.data.types`)
- `Felt`: Fundamental field element type (252-bit integer)
- `Uint256`, `Uint128`, `Uint64`: Unsigned integer types
- `Call`: Represents a contract function call
- `Transaction`, `TransactionReceipt`: Transaction types and receipts
- Complex types use kotlinx.serialization with custom serializers

**Crypto** (`com.swmansion.starknet.crypto`)
- Native library bindings for Pedersen and Poseidon hash functions
- `StarknetCurve`: Elliptic curve operations for signing
- Libraries built from C++ sources in `crypto/` directory
- Native libraries loaded via JNI at runtime

**Serialization** (`com.swmansion.starknet.data.serializers`)
- Extensive custom serializers for JSON-RPC communication
- Polymorphic serializers for handling different transaction/block types
- Handles hex encoding/decoding, numeric conversions

### Key Architectural Patterns

**Request Pattern**: All provider methods return `Request<T>` which enables:
- Deferred execution (build request, execute later with `.send()`)
- Request composition and transformation
- Consistent error handling via `RequestFailedException`

**Type Safety**: Strong typing throughout:
- `Felt` instead of raw strings for addresses/hashes
- Typed transaction versions (V1, V3)
- Enum types for chain IDs, transaction status, etc.

**Java Interoperability**: Library designed for both Kotlin and Java users:
- Use `@file:JvmName(NAME)` for file-level functions
- Use `@JvmStatic` on companion object members
- Use `@field:JvmField` for constants
- Prefer function overloading over default arguments
- Test Java compatibility by importing into Java classes

### Native Library Integration

The SDK includes native Pedersen and Poseidon hash implementations:
1. C++ sources in `crypto/pedersen/` and `crypto/poseidon/`
2. Built via `lib/build_crypto.sh` (called by `BuildCrypto` task)
3. JNI bindings in `lib/src/main/kotlin/com/swmansion/starknet/crypto/`
4. Libraries copied to `lib/build/libs/shared/{platform}/{arch}/`
5. Loaded at runtime via `NativeLoader`

**Platform Support & Directory Structure:**
The JAR packages native libraries for multiple platforms:
```
darwin/                  # macOS universal binary (x86_64 + arm64)
  ├── libcrypto_jni.dylib
  ├── libposeidon_jni.dylib
  └── libposeidon.dylib
linux/x86_64/           # Linux AMD64
  ├── libcrypto_jni.so
  ├── libposeidon_jni.so
  └── libposeidon.so
linux/aarch64/          # Linux ARM64
  ├── libcrypto_jni.so
  ├── libposeidon_jni.so
  └── libposeidon.so
```

**Important**: The directory names must match `System.getProperty("os.arch")` values:
- Linux x86_64 uses `x86_64` (not `amd64`)
- Linux ARM64 uses `aarch64` (not `arm64`)
- macOS uses universal binary (no arch subdirectory)

The `NativeLoader` automatically detects the OS and architecture at runtime and loads the appropriate library from the JAR.

### Documentation Generation

Documentation uses a custom system defined in `lib/build.gradle.kts`:
- `lib/guide.md` is the source of truth
- Contains both inline code snippets and code section tags
- Code sections reference actual test functions: `<!-- codeSection(path="...", function="...", language="...") -->`
- Functions use `// docsStart` and `// docsEnd` comments to mark documented sections
- `./gradlew generateGuides` processes guide.md to create kotlin-guide.md and java-guide.md
- Language-specific code blocks are filtered out for the other language

### Testing Structure

- Unit tests in `lib/src/test/kotlin/starknet/`
- Tests mirror main source structure (account, provider, crypto, etc.)
- Network tests in `lib/src/test/kotlin/network/` (disabled by default)
- Test contracts compiled via `lib/src/test/resources/compileContracts.sh`
- Parallel test execution with `maxParallelForks` based on CPU cores

## Important Notes

- Version is defined in `lib/build.gradle.kts` and follows semantic versioning
- The main module is `lib/` - other modules (android, javademo, androiddemo) are demos
- Tests require native crypto libraries to be built first (handled by `dependsOn(buildCrypto)`)
- Contract compilation requires `scarb` from starknet-foundry
- When adding Kotlin APIs, always verify Java compatibility
