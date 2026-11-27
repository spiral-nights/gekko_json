///|
fn __to_int32(x : Int64) -> Int {
  if x < -2147483648L || x > 2147483647L {
    abort("Int64 out of Int32 range")
  }
  x.to_int()
}

///|
pub fn[K : Hash + Eq, V] new_map(arg0 : @gprelude.GList[(K, V)], capacity : Int64?) -> Map[K, V] {
  Map((arg0).to_array().map(fn(x0) { x0 })[:], capacity?=(capacity).map(fn(x0) { __to_int32(x0) }))
}

///|
pub fn[K, V] map_to_array(self_ : Map[K, V]) -> @gprelude.GList[(K, V)] {
  @gprelude.GList::from_array((Map::to_array(self_)).map(fn(x0) { x0 })[:])
}
