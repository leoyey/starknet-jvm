#!/usr/bin/env bash
set -e

echo "=== Building Multi-Architecture Native Libraries ==="
echo ""

# Check Docker is available
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed or not in PATH"
    exit 1
fi

# Check if Docker is running
if ! docker info &> /dev/null; then
    echo "Error: Docker daemon is not running"
    exit 1
fi

PROJECT_ROOT=$(pwd)
BUILD_DIR="$PROJECT_ROOT/native-lib"

echo "Project root: $PROJECT_ROOT"
echo "Build directory: $BUILD_DIR"
echo "Note: Native libraries will be saved to native-lib/ for use with jarWithPrebuiltNatives"
echo ""

# Build for each platform - using arrays instead of associative arrays for compatibility
DOCKER_PLATFORMS=("linux/amd64" "linux/arm64")
JAVA_ARCHS=("x86_64" "aarch64")

for i in "${!DOCKER_PLATFORMS[@]}"; do
    DOCKER_PLATFORM="${DOCKER_PLATFORMS[$i]}"
    ARCH="${JAVA_ARCHS[$i]}"
    echo "=== Building for $DOCKER_PLATFORM (Java arch: $ARCH) ==="
    echo "Note: Using GCC 7 for Ubuntu 18.04 compatibility"

    # Build Docker image for this platform
    echo "Building Docker image..."
    docker buildx build \
        --platform "$DOCKER_PLATFORM" \
        --file .github/workflows/Dockerfile.multiarch \
        --tag starknet-jvm-build:$ARCH \
        --load \
        .

    # Create target directory
    TARGET_DIR="$BUILD_DIR/linux/$ARCH"
    mkdir -p "$TARGET_DIR"
    echo "Target directory: $TARGET_DIR"

    # Create container and extract libraries
    echo "Extracting compiled libraries..."
    CONTAINER=$(docker create --platform "$DOCKER_PLATFORM" starknet-jvm-build:$ARCH)

    docker cp "$CONTAINER:/build/crypto/pedersen/build/bindings/libcrypto_jni.so" "$TARGET_DIR/libcrypto_jni.so"
    docker cp "$CONTAINER:/build/crypto/poseidon/build/bindings/libposeidon_jni.so" "$TARGET_DIR/libposeidon_jni.so"
    docker cp "$CONTAINER:/build/crypto/poseidon/build/poseidon/libposeidon.so" "$TARGET_DIR/libposeidon.so"

    docker rm "$CONTAINER" > /dev/null

    echo "✓ Successfully built and extracted libraries for $ARCH"
    echo ""
done

echo "=== Build Summary ==="
echo ""
echo "Native libraries have been built for:"
echo "  - Linux x86_64 (amd64) - GCC 7 for Ubuntu 18.04+ compatibility"
echo "  - Linux aarch64 (arm64) - GCC 7 for Ubuntu 18.04+ compatibility"
echo ""
echo "Directory structure:"
tree "$BUILD_DIR" 2>/dev/null || find "$BUILD_DIR" -type f
echo ""
echo "To build a JAR with all native libraries (darwin + linux), run:"
echo "  ./gradlew :lib:jarWithPrebuiltNatives :lib:publishToMavenLocal"
echo ""
echo "✓ Multi-architecture build complete!"
