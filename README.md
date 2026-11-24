# `gekko_json`

Companion MoonBit/Wasm shim overlay package for unmodified upstream [`gleam_json`](https://hex.pm/packages/gleam_json), built for [`gekko`](https://github.com/spiral-nights/gekko).

Instead of forking `gleam_json`, `gekko_json` provides co-located MoonBit module patches (`patches/gleam/json.mbt`) and symbol-level configuration (`gekko.toml`) so upstream `gleam_json` compiles cleanly to MoonBit (`wasm`, `wasm-gc`, `js`, `native`, and Wasm Components).

## Usage

Add unmodified `gleam_stdlib` + `gleam_json` alongside `gekko_stdlib` + `gekko_json` in your `gleam.toml`:

```toml
[dependencies]
gleam_stdlib = ">= 1.0.0 and < 2.0.0"
gleam_json = ">= 3.0.0 and < 4.0.0"
gekko_stdlib = { git = "https://github.com/spiral-nights/gekko_stdlib.git", ref = "main" }
gekko_json = { git = "https://github.com/spiral-nights/gekko_json.git", ref = "main" }
```

Then build or test with `gekko` (standard `gleam check` and `gleam test` on Erlang/JS continue to work untouched):

```bash
gekko check
gekko test
gekko build --release
```

## Testing

Run the upstream `gleam_json` parity suite (`26` tests across `wasm`, `wasm-gc`, `js`, and `native`) against unmodified Hex `gleam_json` + `gleam_stdlib`:

```bash
./scripts/test_upstream.sh
```

Override `GEKKO_STDLIB_DIR=/path/to/gekko_stdlib` to test against a local `gekko_stdlib` checkout.

## License

MIT — see [`LICENSE`](./LICENSE).
