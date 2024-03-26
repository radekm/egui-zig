# Translating core types from `emath` crate

Another thing we are going to need in `epaint` are types
`Vec2`, `Vec2b` and `Pos2` from `emath` crate.
These are 2 element vectors. In Rust these are implemented as structs
and with impls for various operation on them. Most impls are basically just lifting
operators on floats or bools to work on vectors.

We can avoid this boilerplate in Zig by making `Vec2` and `Pos2` aliases for `@Vector(2, f32)`
and `Vec2b` alias for `@Vector(2, bool)`. With these definitions we can use standard
arithmetical and logical operators and functions to get
most functionality for free.

In Zig sometimes it makes sense to specialize generic builtin function
for concrete types. For example in `vec2.zig` we have

```zig
pub fn splat(v: f32) T {
    return @splat(v);
}
```

So in some contexts we can write `vec2.splat(t)` instead of `@as(vec2.T, @splat(t))`
because our `vec2.splat` knows result type.
