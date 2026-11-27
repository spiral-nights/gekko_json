///|
fn __to_int32(x : Int64) -> Int {
  if x < -2147483648L || x > 2147483647L {
    abort("Int64 out of Int32 range")
  }
  x.to_int()
}

///|
fn __to_char(s : String) -> Char {
  match s.get_char(0) {
    Some(c) => c
    None => abort("Expected non-empty String for Char")
  }
}

///|
pub fn parse(arg0 : String, reject_duplicate_keys : Bool?, preserve_number_repr : Bool?) -> Result[@moonbitlang_core_json.Json, @moonbitlang_core_json.ParseError] {
  try {
    let __res = @moonbitlang_core_json.parse((arg0).to_string_view(), reject_duplicate_keys?=reject_duplicate_keys, preserve_number_repr?=preserve_number_repr)
    Ok(__res)
  } catch {
    __err => Err(__err)
  }
}

///|
pub fn array(arg0 : @gprelude.GList[@moonbitlang_core_json.Json]) -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::array((arg0).to_array())
}

///|
pub fn boolean(arg0 : Bool) -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::boolean(arg0)
}

///|
pub fn null() -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::null()
}

///|
pub fn number(arg0 : Double, repr : String?) -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::number(arg0, repr?=repr)
}

///|
pub fn object(arg0 : Map[String, @moonbitlang_core_json.Json]) -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::object(arg0)
}

///|
pub fn string(arg0 : String) -> @moonbitlang_core_json.Json {
  @moonbitlang_core_json.Json::string(arg0)
}

///|
pub fn stringify(self_ : @moonbitlang_core_json.Json, escape_slash : Bool?, indent : Int64?, replacer : @moonbitlang_core_json.Replacer?) -> String {
  @moonbitlang_core_json.Json::stringify(self_, escape_slash?=escape_slash, indent?=(indent).map(fn(x0) { __to_int32(x0) }), replacer?=replacer)
}

///|
pub fn parse_error_invalid_char(arg0 : @moonbitlang_core_json.Position, arg1 : String) -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.InvalidChar(arg0, __to_char(arg1))
}

///|
pub fn parse_error_invalid_eof() -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.InvalidEof
}

///|
pub fn parse_error_invalid_number(arg0 : @moonbitlang_core_json.Position, arg1 : String) -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.InvalidNumber(arg0, arg1)
}

///|
pub fn parse_error_invalid_ident_escape(arg0 : @moonbitlang_core_json.Position) -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.InvalidIdentEscape(arg0)
}

///|
pub fn parse_error_duplicate_key(arg0 : @moonbitlang_core_json.Position, arg1 : String) -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.DuplicateKey(arg0, arg1)
}

///|
pub fn parse_error_depth_limit_exceeded() -> @moonbitlang_core_json.ParseError {
  @moonbitlang_core_json.DepthLimitExceeded
}

///|
pub fn[Ret] match_parse_error(value : @moonbitlang_core_json.ParseError, on_invalid_char : (@moonbitlang_core_json.Position, String) -> Ret, on_invalid_eof : () -> Ret, on_invalid_number : (@moonbitlang_core_json.Position, String) -> Ret, on_invalid_ident_escape : (@moonbitlang_core_json.Position) -> Ret, on_duplicate_key : (@moonbitlang_core_json.Position, String) -> Ret, on_depth_limit_exceeded : () -> Ret) -> Ret {
  match value {
    @moonbitlang_core_json.InvalidChar(v0, v1) => on_invalid_char(v0, (v1).to_string())
    @moonbitlang_core_json.InvalidEof => on_invalid_eof()
    @moonbitlang_core_json.InvalidNumber(v0, v1) => on_invalid_number(v0, v1)
    @moonbitlang_core_json.InvalidIdentEscape(v0) => on_invalid_ident_escape(v0)
    @moonbitlang_core_json.DuplicateKey(v0, v1) => on_duplicate_key(v0, v1)
    @moonbitlang_core_json.DepthLimitExceeded => on_depth_limit_exceeded()
  }
}

///|
pub fn[Ret] match_json(value : @moonbitlang_core_json.Json, on_null : () -> Ret, on_true : () -> Ret, on_false : () -> Ret, on_number : (Double, String?) -> Ret, on_string : (String) -> Ret, on_array : (@gprelude.GList[@moonbitlang_core_json.Json]) -> Ret, on_object : (Map[String, @moonbitlang_core_json.Json]) -> Ret) -> Ret {
  match value {
    @moonbitlang_core_json.Null => on_null()
    @moonbitlang_core_json.True => on_true()
    @moonbitlang_core_json.False => on_false()
    @moonbitlang_core_json.Number(v0, repr=v1) => on_number(v0, v1)
    @moonbitlang_core_json.String(v0) => on_string(v0)
    @moonbitlang_core_json.Array(v0) => on_array(@gprelude.GList::from_array((v0)[:]))
    @moonbitlang_core_json.Object(v0) => on_object(v0)
  }
}
