#!/usr/bin/bash
set -Eeuo pipefail
clear

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="$ROOT_DIR/out"
MODULE_OUTPUT_DIR="${OUTPUT_DIR}/module"

GIT_PROJECT_DIR="${PWD}/meta-overlayfs"
METAMODULE_DIR="${GIT_PROJECT_DIR}/metamodule"

NDK_PATH="$HOME/android-ndk/r29"
TOOLCHAIN_PATH="$NDK_PATH/toolchains/llvm/prebuilt/linux-x86_64"
CLANG="$TOOLCHAIN_PATH/bin/clang"

MINIMAL_API_LEVEL="${MINIMAL_API_LEVEL:-25}"

if [ ! -d "$NDK_PATH" ]; then
    echo; echo "ERROR: NDK not found: $NDK_PATH"; echo
    exit 2
fi

if [ ! -x "$CLANG" ]; then
    echo; echo "ERROR: NDK clang not found: $CLANG"; echo
    exit 2
fi

checkout() {

  if [ ! -d "${GIT_PROJECT_DIR}/.git" ]; then

    echo
    git clone https://github.com/col83/meta-overlayfs.git "${GIT_PROJECT_DIR}"

  fi

}

setup_cargo() {

  export CARGO_HOME="${PWD}/.cargo"
  export PATH="$CARGO_HOME/bin:$PATH"

  rustup target install aarch64-linux-android

  if ! command -v cargo-ndk >/dev/null 2>&1; then
    echo; echo "Installing cargo-ndk"; echo
    cargo install cargo-ndk
  fi

}

build() {

  # rm -rf "${OUTPUT_DIR:?}/"
  rm -rf "${MODULE_OUTPUT_DIR:?}/"
  mkdir -p "${MODULE_OUTPUT_DIR:?}/"

  pushd "${GIT_PROJECT_DIR}" 1>/dev/null

  # cargo clean &>/dev/null

  ANDROID_NDK_HOME="$(realpath "$NDK_PATH")"
  export ANDROID_NDK_HOME

  echo "Building meta-overlayfs..."; echo

  RUSTFLAGS="-C target-feature=+crt-static -A linker-messages" \
  cargo ndk \
    -t aarch64-linux-android \
    -P "${MINIMAL_API_LEVEL}" \
    --link-builtins \
    build -r

  cp "target/aarch64-linux-android/release/meta-overlayfs" "$MODULE_OUTPUT_DIR/"

  popd 1>/dev/null

}

create_flashable_zip() {

  cp "$METAMODULE_DIR"/module.prop "$MODULE_OUTPUT_DIR/"
  cp "$METAMODULE_DIR"/*.sh "$MODULE_OUTPUT_DIR/"

  chmod 755 "$MODULE_OUTPUT_DIR"/*.sh
  chmod 755 "$MODULE_OUTPUT_DIR/meta-overlayfs"

  pushd "${MODULE_OUTPUT_DIR}" 1>/dev/null

  local MODULE_VERSION
  MODULE_VERSION=$(grep -m1 '^version=' "$METAMODULE_DIR/module.prop" | cut -d'=' -f2- | tr -d '\r')

  export ZIP_NAME="OverlayFS_MetaModule-v${MODULE_VERSION}.zip"

  zip -qr9 "${OUTPUT_DIR}/${ZIP_NAME}" .

  popd 1>/dev/null

}

main() {

  checkout; echo
  setup_cargo; echo
  build
  create_flashable_zip

  echo; file "$(realpath "${MODULE_OUTPUT_DIR}/meta-overlayfs")"

  echo; echo "Output: $(realpath "${MODULE_OUTPUT_DIR}/${ZIP_NAME}")"

}

main; echo
