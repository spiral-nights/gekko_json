import gekko_json/ffi/json as mjson
import gekko_json/ffi/map as mmap
import gleam/dynamic.{type Dynamic}
import gleam/int
import gleam/json.{
  type DecodeError, UnexpectedByte, UnexpectedEndOfInput, UnexpectedSequence,
}
import gleam/list
import gleam/option.{None, Some}
import gleam/string
import gleam/string_tree.{type StringTree}

/// @patch_type("gleam/json.Json")
pub type Json =
  mjson.Json

fn json_to_dynamic(j: Json) -> Dynamic {
  mjson.match_json(
    j,
    fn() { dynamic.nil() },
    fn() { dynamic.bool(True) },
    fn() { dynamic.bool(False) },
    fn(d, repr) {
      case repr {
        Some(r) ->
          case
            !string.contains(r, ".")
            && !string.contains(r, "e")
            && !string.contains(r, "E")
          {
            True ->
              case int.parse(r) {
                Ok(i) -> dynamic.int(i)
                Error(_) -> dynamic.float(d)
              }
            False -> dynamic.float(d)
          }
        None -> dynamic.float(d)
      }
    },
    fn(s) { dynamic.string(s) },
    fn(items) { dynamic.list(list.map(items, json_to_dynamic)) },
    fn(obj) {
      mmap.map_to_array(obj)
      |> list.map(fn(kv) { #(dynamic.string(kv.0), json_to_dynamic(kv.1)) })
      |> dynamic.properties
    },
  )
}

fn format_char_hex(c_str: String) -> String {
  case string.to_utf_codepoints(c_str) {
    [cp, ..] -> {
      let code = string.utf_codepoint_to_int(cp)
      case code <= 255 {
        True -> {
          let hex = int.to_base16(code)
          let padded = case string.length(hex) {
            1 -> "0" <> hex
            _ -> hex
          }
          "0x" <> padded
        }
        False -> "0x" <> int.to_string(code)
      }
    }
    [] -> "0x00"
  }
}

/// @patch("gleam/json.decode_string")
pub fn decode_string(json_str: String) -> Result(Dynamic, DecodeError) {
  case mjson.parse(json_str, None, Some(True)) {
    Ok(parsed) -> Ok(json_to_dynamic(parsed))
    Error(err) ->
      mjson.match_parse_error(
        err,
        fn(_pos, ch) { Error(UnexpectedByte(format_char_hex(ch))) },
        fn() { Error(UnexpectedEndOfInput) },
        fn(_pos, s) { Error(UnexpectedSequence(s)) },
        fn(_pos) { Error(UnexpectedSequence("escape")) },
        fn(_pos, k) { Error(UnexpectedSequence(k)) },
        fn() { Error(UnexpectedSequence("depth")) },
      )
  }
}

/// @patch("gleam/json.to_string_tree")
pub fn to_string_tree(json: Json) -> StringTree {
  string_tree.from_string(do_to_string(json))
}

/// @patch("gleam/json.do_to_string")
pub fn do_to_string(json: Json) -> String {
  mjson.stringify(json, None, None, None)
}

/// @patch("gleam/json.do_string")
pub fn do_string(input: String) -> Json {
  mjson.string(input)
}

/// @patch("gleam/json.do_bool")
pub fn do_bool(input: Bool) -> Json {
  mjson.boolean(input)
}

/// @patch("gleam/json.do_int")
pub fn do_int(input: Int) -> Json {
  mjson.number(int.to_float(input), Some(int.to_string(input)))
}

/// @patch("gleam/json.do_float")
pub fn do_float(input: Float) -> Json {
  mjson.number(input, None)
}

/// @patch("gleam/json.do_null")
pub fn do_null() -> Json {
  mjson.null()
}

/// @patch("gleam/json.do_object")
pub fn do_object(entries: List(#(String, Json))) -> Json {
  mjson.object(mmap.new_map(entries, None))
}

/// @patch("gleam/json.do_preprocessed_array")
pub fn do_preprocessed_array(entries: List(Json)) -> Json {
  mjson.array(entries)
}
