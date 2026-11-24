# `gekko_json`

Companion MoonBit/Wasm shim overlay package for unmodified upstream [`gleam_json`](https://hex.pm/packages/gleam_json), built for [`gekko`](https://github.com/spiral-nights/gekko).

Instead of forking `gleam_json`, `gekko_json` provides only the MoonBit FFI primitives (`moonbit/gleam_json_ffi/`), in-package patches (`overlays/`), and symbol-level override configuration (`gekko.toml`) needed to compile upstream `gleam_json` to MoonBit (`wasm`, `wasm-gc`, `js`, `native`, and Wasm Components).

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

## License

MIT — see [`LICENSE`](./LICENSE).
