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
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GEKKO="${GEKKO:-gekko}"
TARGETS="${TARGETS:-wasm wasm-gc js native}"
UPSTREAM_REF="${UPSTREAM_REF:-v3.1.0}"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [ -n "${UPSTREAM_DIR:-}" ]; then
  UPSTREAM_ROOT="$(cd "$UPSTREAM_DIR" && pwd)"
else
  UPSTREAM_ROOT="$TMP_DIR/upstream_json"
  git clone --depth 1 --branch "$UPSTREAM_REF" https://github.com/gleam-lang/json.git "$UPSTREAM_ROOT" >/dev/null 2>&1
fi

PROJECT_DIR="$TMP_DIR/json_parity"
OUT_DIR="$TMP_DIR/json_parity_mbt"
mkdir -p "$PROJECT_DIR/src/gleeunit" "$PROJECT_DIR/test"

if [ -n "${GEKKO_STDLIB_DIR:-}" ]; then
  STDLIB_ABS="$(cd "$GEKKO_STDLIB_DIR" && pwd)"
  STDLIB_SHIM_DEP="gekko_stdlib = { path = \"$STDLIB_ABS\" }"
else
  STDLIB_SHIM_DEP="gekko_stdlib = { git = \"https://github.com/spiral-nights/gekko_stdlib.git\", ref = \"${GEKKO_STDLIB_REF:-main}\" }"
fi

if [ -n "${GEKKO_STDLIB_DIR:-}" ] || [ "${GEKKO_STDLIB_REF:-main}" != "main" ]; then
  STAGED_JSON="$TMP_DIR/staged_gekko_json"
  mkdir -p "$STAGED_JSON"
  (cd "$ROOT" && tar cf - --exclude=build --exclude=manifest.toml .) | (cd "$STAGED_JSON" && tar xf -)
  sed -i -E "s|^gekko_stdlib = .*|$STDLIB_SHIM_DEP|" "$STAGED_JSON/gleam.toml"
  JSON_SHIM_DEP="gekko_json = { path = \"$STAGED_JSON\" }"
else
  JSON_SHIM_DEP="gekko_json = { path = \"$ROOT\" }"
fi

cat > "$PROJECT_DIR/gleam.toml" <<EOF
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

cat > "$PROJECT_DIR/src/gleeunit/should.gleam" <<'EOF'
pub fn equal(a: t, b: t) -> Nil {
  assert a == b
  Nil
}
EOF

cat > "$PROJECT_DIR/src/json_parity.gleam" <<'EOF'
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
' "$UPSTREAM_ROOT/test/gleam_json_test.gleam" > "$PROJECT_DIR/test/json_parity_test.gleam"

# Extra end-to-end check covering nested decoders (`decode.field`, `decode.optional`,
# `decode.dict`, `decode.at`) and parse error formatting alongside the 25 upstream tests.
cat > "$PROJECT_DIR/test/json_roundtrip_extra_test.gleam" <<'EOF'
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
(cd "$PROJECT_DIR" && gleam deps download)
if ! gekko_out="$("$GEKKO" check --root "$PROJECT_DIR" --out "$OUT_DIR" --target wasm 2>&1)"; then
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
  (cd "$OUT_DIR" && moon check --deny-warn --target "$target")
  if ! out="$(cd "$OUT_DIR" && moon test --target "$target" 2>&1)"; then
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
