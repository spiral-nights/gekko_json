#!/usr/bin/env bash
# Transpile and execute upstream gleam-lang/json's test suite through gekko
# against unmodified Hex gleam_stdlib + gleam_json + companion shims across
# MoonBit targets (wasm, wasm-gc, js, native).
#
# Environment overrides:
#   GEKKO            - gekko CLI command or binary path (default: gekko)
#   TARGETS          - space-separated MoonBit targets (default: "wasm wasm-gc js native")
#   UPSTREAM_DIR     - optional local checkout of gleam-lang/json
#   UPSTREAM_REF     - git ref to clone when UPSTREAM_DIR is unset (default: v3.1.0)
#   GEKKO_STDLIB_DIR - local path to gekko_stdlib (default: clone over HTTPS)
#   GEKKO_STDLIB_REF - git ref when fetching gekko_stdlib (default: main)
#   GEKKO_CACHE_DIR  - optional persistent cache directory for clones, staging, and MoonBit builds
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEKKO="${GEKKO:-gekko}"
TARGETS="${TARGETS:-wasm wasm-gc js native}"
UPSTREAM_REF="${UPSTREAM_REF:-v3.1.0}"
GEKKO_CACHE_DIR="${GEKKO_CACHE_DIR:-}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LAST_CHANGED=0

write_if_changed() {
  local dest="$1"
  local tmp_file
  tmp_file="$(mktemp "$TMP_DIR/wic.XXXXXX")"
  cat > "$tmp_file"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$tmp_file" "$dest"; then
    rm -f "$tmp_file"
    LAST_CHANGED=0
  else
    mv "$tmp_file" "$dest"
    LAST_CHANGED=1
  fi
}

copy_if_changed() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [ -f "$dest" ] && cmp -s "$src" "$dest"; then
    LAST_CHANGED=0
  else
    cp "$src" "$dest"
    LAST_CHANGED=1
  fi
}

sync_tree_preserve() {
  local src_dir="$1"
  local dest_dir="$2"
  mkdir -p "$dest_dir"
  (
    cd "$dest_dir"
    find . \( -path './build' -o -path './build/*' -o -path './_build' -o -path './_build/*' -o -path './manifest.toml' -o -path './.git' -o -path './.git/*' \) -prune -o -type f -print
  ) | while IFS= read -r rel; do
    if [ ! -f "$src_dir/$rel" ]; then
      rm -f "$dest_dir/$rel"
    fi
  done
  (
    cd "$dest_dir"
    find . \( -path './build' -o -path './build/*' -o -path './_build' -o -path './_build/*' -o -path './.git' -o -path './.git/*' \) -prune -o -type d -empty -print 2>/dev/null || true
  ) | sort -r | while IFS= read -r rel; do
    [ "$rel" = "." ] || rmdir "$dest_dir/$rel" 2>/dev/null || true
  done
  (
    cd "$src_dir"
    find . -type f -print
  ) | while IFS= read -r rel; do
    copy_if_changed "$src_dir/$rel" "$dest_dir/$rel"
  done
}

if [ -n "${UPSTREAM_DIR:-}" ]; then
  UPSTREAM_ROOT="$(cd "$UPSTREAM_DIR" && pwd)"
elif [ -n "$GEKKO_CACHE_DIR" ]; then
  UPSTREAM_ROOT="$GEKKO_CACHE_DIR/upstream/json-$UPSTREAM_REF"
  if [ ! -d "$UPSTREAM_ROOT/.git" ]; then
    mkdir -p "$(dirname "$UPSTREAM_ROOT")"
    git clone --depth 1 --branch "$UPSTREAM_REF" https://github.com/gleam-lang/json.git "$TMP_DIR/upstream_json" >/dev/null 2>&1
    rm -rf "$UPSTREAM_ROOT"
    mv "$TMP_DIR/upstream_json" "$UPSTREAM_ROOT"
  fi
else
  UPSTREAM_ROOT="$TMP_DIR/upstream_json"
  git clone --depth 1 --branch "$UPSTREAM_REF" https://github.com/gleam-lang/json.git "$UPSTREAM_ROOT" >/dev/null 2>&1
fi

if [ -n "$GEKKO_CACHE_DIR" ]; then
  WORK_BASE="$GEKKO_CACHE_DIR/json_parity"
  PROJECT_DIR="$WORK_BASE/project"
  OUT_DIR="$WORK_BASE/out"
else
  WORK_BASE="$TMP_DIR"
  PROJECT_DIR="$TMP_DIR/json_parity"
  OUT_DIR="$TMP_DIR/json_parity_mbt"
fi
mkdir -p "$PROJECT_DIR/src/gleeunit" "$PROJECT_DIR/test"

if [ -n "${GEKKO_STDLIB_DIR:-}" ]; then
  STDLIB_ABS="$(cd "$GEKKO_STDLIB_DIR" && pwd)"
  STDLIB_SHIM_DEP="gekko_stdlib = { path = \"$STDLIB_ABS\" }"
else
  STDLIB_SHIM_DEP="gekko_stdlib = { git = \"https://github.com/spiral-nights/gekko_stdlib.git\", ref = \"${GEKKO_STDLIB_REF:-main}\" }"
fi

if [ -n "${GEKKO_STDLIB_DIR:-}" ] || [ "${GEKKO_STDLIB_REF:-main}" != "main" ]; then
  STAGED_TMP="$TMP_DIR/raw_gekko_json"
  mkdir -p "$STAGED_TMP"
  (cd "$ROOT" && tar cf - --exclude=build --exclude=_build --exclude=manifest.toml .) | (cd "$STAGED_TMP" && tar xf -)
  sed -i -E "s|^gekko_stdlib = .*|$STDLIB_SHIM_DEP|" "$STAGED_TMP/gleam.toml"
  STAGED_JSON="$WORK_BASE/staged_gekko_json"
  sync_tree_preserve "$STAGED_TMP" "$STAGED_JSON"
  JSON_SHIM_DEP="gekko_json = { path = \"$STAGED_JSON\" }"
else
  JSON_SHIM_DEP="gekko_json = { path = \"$ROOT\" }"
fi

GLEAM_TOML_CHANGED=0
write_if_changed "$PROJECT_DIR/gleam.toml" <<EOF
name = "json_parity"
version = "0.1.0"

[dependencies]
gleam_stdlib = ">= 1.0.0 and < 2.0.0"
gleam_json = ">= 3.0.0 and < 4.0.0"
$STDLIB_SHIM_DEP
$JSON_SHIM_DEP

[tools.gekko.use_shims]
gleam_stdlib = "gekko_stdlib"
gleam_json = "gekko_json"
EOF
GLEAM_TOML_CHANGED=$LAST_CHANGED

write_if_changed "$PROJECT_DIR/src/gleeunit/should.gleam" <<'EOF'
pub fn equal(a: t, b: t) -> Nil {
  assert a == b
  Nil
}
EOF

write_if_changed "$PROJECT_DIR/src/json_parity.gleam" <<'EOF'
pub fn main() -> Nil {
  Nil
}
EOF

# Keep all 25 upstream tests in `test/gleam_json_test.gleam`, only replacing
# `gleeunit.main()` (since MoonBit runs each `*_test` function directly via `moon test`).
awk '
  BEGIN { found_imp = 0; found_main = 0 }
  $0 == "import gleeunit" {
    found_imp = 1
    next
  }
  $0 == "  gleeunit.main()" {
    found_main = 1
    print "  Nil"
    next
  }
  { print }
  END {
    if (!found_imp || !found_main) {
      print "FAIL: expected gleeunit markers not found in gleam_json_test.gleam" > "/dev/stderr"
      exit 1
    }
  }
' "$UPSTREAM_ROOT/test/gleam_json_test.gleam" | write_if_changed "$PROJECT_DIR/test/json_parity_test.gleam"

# Extra end-to-end check covering nested decoders (`decode.field`, `decode.optional`,
# `decode.dict`, `decode.at`) and parse error formatting alongside the 25 upstream tests.
write_if_changed "$PROJECT_DIR/test/json_roundtrip_extra_test.gleam" <<'EOF'
import gleam/dict
import gleam/dynamic
import gleam/dynamic/decode
import gleam/json
import gleam/list
import gleam/option.{None}

pub fn nested_json_roundtrip_and_decode_errors_test() {
  let j =
    json.object([
      #("name", json.string("gleam")),
      #("nums", json.array([1, 2, 3], of: json.int)),
      #("ratio", json.float(1.5)),
      #("ok", json.bool(True)),
      #("opt", json.nullable(None, of: json.int)),
    ])
  let j_str = json.to_string(j)
  let rec_decoder = {
    use name <- decode.field("name", decode.string)
    use nums <- decode.field("nums", decode.list(decode.int))
    use ratio <- decode.field("ratio", decode.float)
    use ok <- decode.field("ok", decode.bool)
    use opt <- decode.field("opt", decode.optional(decode.int))
    decode.success(#(name, nums, ratio, ok, opt))
  }
  assert json.parse(j_str, rec_decoder) == Ok(#("gleam", [1, 2, 3], 1.5, True, None))

  let dict_dyn =
    [#("a", 10), #("b", 20)]
    |> list.map(fn(p) { #(dynamic.string(p.0), dynamic.int(p.1)) })
    |> dynamic.properties
  assert dynamic.classify(dict_dyn) == "Dict"
  assert decode.run(dict_dyn, decode.dict(decode.string, decode.int))
    == Ok(dict.from_list([#("a", 10), #("b", 20)]))

  assert json.parse("[", decode.list(decode.int))
    == Error(json.UnexpectedEndOfInput)
  let assert Error(json.UnexpectedByte("0x69")) =
    json.parse("{invalid}", decode.dynamic)
  assert decode.run(dynamic.int(5), decode.at([0], decode.int)) != Ok(5)
}
EOF

echo "=== Downloading dependencies and transpiling json_parity ==="
if [ ! -d "$PROJECT_DIR/build/packages/gleam_json" ] || [ "$GLEAM_TOML_CHANGED" -eq 1 ]; then
  rm -f "$PROJECT_DIR/manifest.toml"
  (cd "$PROJECT_DIR" && gleam deps download)
fi

FIRST_TARGET="${TARGETS%% *}"
if ! gekko_out="$("$GEKKO" check --root "$PROJECT_DIR" --out "$OUT_DIR" --target "$FIRST_TARGET" 2>&1)"; then
  echo "$gekko_out" >&2
  exit 1
fi
echo "$gekko_out"
if echo "$gekko_out" | grep -qi "warning"; then
  echo "FAIL: gekko check emitted warnings for json_parity" >&2
  exit 1
fi

for target in $TARGETS; do
  echo "=== Running json_parity tests on $target ==="
  if ! out="$(cd "$OUT_DIR" && moon test --deny-warn --target "$target" 2>&1)"; then
    echo "$out" >&2
    exit 1
  fi
  echo "$out"
  case "$out" in
    *"passed: 26, failed: 0"*) ;;
    *)
      echo "FAIL [json_parity/$target]: expected 'passed: 26, failed: 0'" >&2
      exit 1
      ;;
  esac
done

echo "gleam_json MoonBit tests passed on all targets ($TARGETS)."
