///|
fn __shim_decode_string(a : String) -> Result[@gprelude.Dynamic, DecodeError] {
  match @gleam_json_ffi.decode_string(a) {
    Ok(d) => Ok(d)
    Err((0L, _)) => Err(UnexpectedEndOfInput)
    Err((1L, s)) => Err(UnexpectedByte(s))
    Err((_, s)) => Err(UnexpectedSequence(s))
  }
}

///|
fn __shim_to_string_tree(json : Json) -> @string_tree.StringTree {
  @string_tree.from_string(do_to_string(json))
}
