#!/usr/bin/env bash
# Use the exact Android toolchain pins shared by all three Ace 3V references.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cache="$root/.tmp/toolchains"
env_file=
while (($#)); do
  case "$1" in
    --cache-dir) cache=$2; shift 2;;
    --env-file) env_file=$2; shift 2;;
    *) echo "unknown toolchain option: $1" >&2; exit 1;;
  esac
done
mkdir -p "$cache"
cache=$(cd -- "$cache" && pwd)
clang_sha=28b975ada54f8610ed531a6b57253aed10e7c87d
tools_sha=d153b7ab4a4956198957e258d4f370e875c53059
identity=android-clang-r487747c-pahole-1.23
[[ ${TOOLCHAIN_ID:-$identity} == "$identity" ]] || { echo "unsupported OnePlus toolchain identity: $TOOLCHAIN_ID" >&2; exit 1; }
fetch(){
  local name=$1 url=$2 sha=$3 subtree=$4 dir
  dir="$cache/$name"
  if [[ ! -d $dir/.git ]]; then
    mkdir -p "$dir"
    git -C "$dir" init -q
    git -C "$dir" remote add origin "$url"
  fi
  [[ $(git -C "$dir" remote get-url origin) == "$url" ]] || { echo "wrong toolchain origin: $dir" >&2; exit 1; }
  git -C "$dir" config core.sparseCheckout true
  printf '%s/\n' "$subtree" > "$dir/.git/info/sparse-checkout"
  if [[ $(git -C "$dir" rev-parse --verify HEAD 2>/dev/null || true) != "$sha" ]]; then
    git -C "$dir" -c http.version=HTTP/1.1 fetch --depth 1 --filter=blob:none origin "$sha"
    git -C "$dir" checkout --detach FETCH_HEAD
  fi
  [[ $(git -C "$dir" rev-parse HEAD) == "$sha" ]]
  git -C "$dir" diff --exit-code HEAD -- "$subtree" >/dev/null
}
fetch clang https://git.codelinaro.org/clo/la/kernelplatform/prebuilts-master/clang/host/linux-x86.git "$clang_sha" clang-r487747c
fetch build-tools https://git.codelinaro.org/clo/la/kernel/prebuilts/build-tools.git "$tools_sha" linux-x86
clang="$cache/clang/clang-r487747c/bin"
pahole="$cache/build-tools/linux-x86/bin/pahole"
"$clang/clang" --version | grep -F 'clang version 17.0.2'
"$clang/ld.lld" --version | grep -F 'LLD 17.0.2'
[[ $("$pahole" --version) == v1.23 ]] || { echo 'expected Android pahole v1.23' >&2; exit 1; }
# LLVM tools must precede the host distro. Keep host utilities for non-kernel CI.
export PATH="$clang:$PATH" PAHOLE="$pahole" LLVM=1 HOSTCC=clang HOSTCXX=clang++ TOOLCHAIN_ID="$identity"
printf 'verified toolchain=%s clang_commit=%s build_tools_commit=%s\n' "$identity" "$clang_sha" "$tools_sha"
sha256sum "$clang/clang" "$clang/ld.lld" "$pahole"
if [[ -n $env_file ]]; then
  printf 'PATH=%s\nPAHOLE=%s\nLLVM=1\nHOSTCC=clang\nHOSTCXX=clang++\nTOOLCHAIN_ID=%s\n' "$PATH" "$PAHOLE" "$identity" >> "$env_file"
fi
