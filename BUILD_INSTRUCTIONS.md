# Building Multi-Architecture starknet-jvm JAR

This guide explains how to build a JAR that includes native libraries for all supported platforms: macOS, Linux x86_64, and Linux aarch64.

## Quick Start: Use GitHub Actions (Recommended)

If you have a slow network connection, use GitHub Actions to build the JAR remotely:

### Steps:

1. **Commit and push your changes to GitHub:**
   ```bash
   git add .
   git commit -m "Setup for multi-arch build"
   git push origin main  # or your branch name
   ```

2. **Go to GitHub Actions:**
   - Navigate to: `https://github.com/leoyey/starknet-jvm/actions`
   - Find the workflow: **"Build Multi-Arch JAR"**

3. **Run the workflow:**
   - Click on the workflow name
   - Click the **"Run workflow"** button (top right)
   - Select your branch (usually `main`)
   - Click **"Run workflow"** to start

4. **Wait for completion (~10-15 minutes):**
   - The workflow will build native libraries for:
     - macOS (darwin universal binary)
     - Linux x86_64
     - Linux aarch64
   - Then package everything into a single JAR

5. **Download the artifact:**
   - Once complete, click on the workflow run
   - Scroll down to "Artifacts" section
   - Download **"starknet-multiarch-jar"**
   - Extract the zip file

6. **Install to local Maven:**
   ```bash
   mvn install:install-file \
     -Dfile=lib-0.16.1-multiarch.jar \
     -DgroupId=com.swmansion.starknet \
     -DartifactId=starknet \
     -Dversion=0.16.1-multiarch \
     -Dpackaging=jar
   ```

7. **Use in your project:**
   ```xml
   <dependency>
       <groupId>com.swmansion.starknet</groupId>
       <artifactId>starknet</artifactId>
       <version>0.16.1-multiarch</version>
   </dependency>
   ```

## Alternative 1: Use Pre-Built Native Libraries

If you already have all native libraries built (in `native-lib/` directory):

```bash
./gradlew :lib:jarWithPrebuiltNatives :lib:publishToMavenLocal
```

This will:
1. Copy native libraries from `native-lib/` directory
2. Package them into the JAR
3. Publish to `~/.m2/repository/`

**Requirements:** `native-lib/` directory structure:
```
native-lib/
├── darwin/
│   ├── libcrypto_jni.dylib
│   ├── libposeidon_jni.dylib
│   └── libposeidon.dylib
├── linux/x86_64/
│   ├── libcrypto_jni.so
│   ├── libposeidon_jni.so
│   └── libposeidon.so
└── linux/aarch64/
    ├── libcrypto_jni.so
    ├── libposeidon_jni.so
    └── libposeidon.so
```

## Alternative 2: Local Build with Docker

If you prefer to build locally (requires Docker):

```bash
# Build Linux libraries using Docker
./build_multiarch_natives.sh

# Package JAR with all platforms
./gradlew :lib:jarWithPrebuiltNatives :lib:publishToMavenLocal
```

This will:
1. Use Docker to cross-compile Linux libraries for x86_64 and aarch64
2. Save them to `native-lib/` directory structure
3. Package everything into JAR and publish to `~/.m2/repository/`

**Note:** The Docker build downloads large images (~1GB+), so it's slower on slow networks.

## What's Included

The multi-arch JAR contains native libraries for:

```
darwin/                  # macOS (both Intel and Apple Silicon)
  ├── libcrypto_jni.dylib
  ├── libposeidon_jni.dylib
  └── libposeidon.dylib

linux/x86_64/           # Linux Intel/AMD
  ├── libcrypto_jni.so
  ├── libposeidon_jni.so
  └── libposeidon.so

linux/aarch64/          # Linux ARM (e.g., AWS Graviton)
  ├── libcrypto_jni.so
  ├── libposeidon_jni.so
  └── libposeidon.so
```

The JAR automatically loads the correct library based on your OS and architecture at runtime.

## Troubleshooting

**GitHub Actions not showing up?**
- Make sure you've pushed the `.github/workflows/build-multiarch-jar.yml` file
- Check that Actions are enabled in your repository settings

**Workflow fails?**
- Check the workflow logs for errors
- Common issues:
  - Submodules not initialized (should be automatic)
  - CMake version mismatch (workflow uses 3.18.1)

**Maven install fails?**
- Make sure the file path is correct
- Check that you've extracted the zip file first
- Verify the JAR filename matches (might be `lib-0.16.1.jar`)

## Building for Development

For local development on a single platform:

```bash
# Build for your current platform only
./gradlew :lib:jarWithNative :lib:publishToMavenLocal
```

This is faster but only works on your current OS/architecture.
