///|
#gekko.patch
#derive(Eq, Debug)
pub(all) struct Json {
  raw : @mjson.Json
}

///|
fn hash_raw_json(j : @mjson.Json, hasher : Hasher) -> Unit {
  match j {
    Null => hasher.combine_int(0)
    True => hasher.combine_int(1)
    False => hasher.combine_int(2)
    String(s) => {
      hasher.combine_int(3)
      hasher.combine(s)
    }
    Number(d, ..) => {
      hasher.combine_int(4)
      hasher.combine(d)
    }
    Array(arr) => {
      hasher.combine_int(5)
      hasher.combine_int(arr.length())
      for item in arr {
        hash_raw_json(item, hasher)
      }
    }
    Object(obj) => {
      hasher.combine_int(6)
      hasher.combine_int(obj.length())
      obj.each(fn(k, v) {
        hasher.combine(k)
        hash_raw_json(v, hasher)
      })
    }
  }
}

///|
pub impl Hash for Json with hash_combine(self, hasher) {
  hash_raw_json(self.raw, hasher)
}

///|
pub impl @gprelude.GleamInspect for Json with gleam_inspect(self) {
  self.raw.stringify()
}

///|
fn json_to_dynamic(j : @mjson.Json) -> @gprelude.Dynamic {
  match j {
    Null => @gprelude.DynNull
    True => @gprelude.DynBool(true)
    False => @gprelude.DynBool(false)
    String(s) => @gprelude.DynString(s)
    Number(d, repr~) =>
      match repr {
        Some(r) =>
          if !(r.contains(".")) && !(r.contains("e")) && !(r.contains("E")) {
            try {
              @gprelude.DynInt(@str.parse_int64(r))
            } catch {
              _ => @gprelude.DynFloat(d)
            }
          } else {
            @gprelude.DynFloat(d)
          }
        None => @gprelude.DynFloat(d)
      }
    Array(arr) => {
      let items = arr.map(json_to_dynamic)
      @gprelude.DynList(@gprelude.GList::from_array(items[:]))
    }
    Object(obj) => {
      let m : Map[@gprelude.Dynamic, @gprelude.Dynamic] = Default::default()
      obj.each(fn(k, v) { m.set(@gprelude.DynString(k), json_to_dynamic(v)) })
      @gprelude.DynMap(m)
    }
  }
}

///|
fn hex_nibble(n : Int) -> Char {
  let d = n & 0xF
  if d < 10 {
    (48 + d).unsafe_to_char()
  } else {
    (55 + d).unsafe_to_char()
  }
}

///|
fn format_char_hex(c : Char) -> String {
  let code = c.to_int()
  if code <= 0xFF {
    "0x" +
    hex_nibble(code >> 4).to_string() +
    hex_nibble(code).to_string()
  } else {
    "0x" + code.to_string()
  }
}

///|
#gekko.patch
fn decode_string(json_str : String) -> Result[@gprelude.Dynamic, DecodeError] {
  let parsed : @mjson.Json = try {
    @mjson.parse(json_str, preserve_number_repr=true)
  } catch {
    @mjson.InvalidEof => return Err(UnexpectedEndOfInput)
    @mjson.InvalidChar(_, c) => return Err(UnexpectedByte(format_char_hex(c)))
    @mjson.InvalidNumber(_, s) => return Err(UnexpectedSequence(s))
    @mjson.InvalidIdentEscape(_) => return Err(UnexpectedSequence("escape"))
    @mjson.DuplicateKey(_, k) => return Err(UnexpectedSequence(k))
    @mjson.DepthLimitExceeded => return Err(UnexpectedSequence("depth"))
  }
  Ok(json_to_dynamic(parsed))
}

///|
#gekko.patch
fn do_to_string(j : Json) -> String {
  j.raw.stringify()
}

///|
#gekko.patch
pub fn to_string_tree(json : Json) -> @string_tree.StringTree {
  @string_tree.from_string(do_to_string(json))
}

///|
#gekko.patch
fn do_string(input : String) -> Json {
  { raw: @mjson.Json::string(input) }
}

///|
#gekko.patch
fn do_bool(input : Bool) -> Json {
  { raw: @mjson.Json::boolean(input) }
}

///|
#gekko.patch
fn do_int(input : Int64) -> Json {
  { raw: @mjson.Json::number(input.to_double(), repr=input.to_string()) }
}

///|
#gekko.patch
fn do_float(input : Double) -> Json {
  { raw: @mjson.Json::number(input) }
}

///|
#gekko.patch
fn do_null() -> Json {
  { raw: @mjson.Json::null() }
}

///|
#gekko.patch
fn do_object(entries : @gprelude.GList[(String, Json)]) -> Json {
  let m : Map[String, @mjson.Json] = Default::default()
  for cur = entries {
    match cur {
      @gprelude.Nil => break { raw: @mjson.Json::object(m) }
      @gprelude.Cons((k, v), rest) => {
        m.set(k, v.raw)
        continue rest
      }
    }
  }
}

///|
#gekko.patch
fn do_preprocessed_array(entries : @gprelude.GList[Json]) -> Json {
  { raw: @mjson.Json::array(entries.to_array().map(fn(j) { j.raw })) }
}
