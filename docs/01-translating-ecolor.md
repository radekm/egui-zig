# Translating `ecolor` crate

First we will translate crate `ecolor` because `Color32` is used
all over the place in `epaint`. Because `ecolor` is small and we don't
need some functionality like macros we put everything
in a single file `color.zig`.

The first problem pose conversions from `f32` to `u8`.
These are saturating in Rust - at least according to the comment from `ecolor`:

```rust
fn fast_round(r: f32) -> u8 {
    (r + 0.5) as _ // rust does a saturating cast since 1.45
}
```

Unfortunately in Zig `@intFromFloat` may result in undefined behvior.
So we write

```zig
fn fastRound(r: f32) u8 {
    return if (r >= 254.5) 255 else if (r <= 0) 0 else @intFromFloat(r);
}
```

and use it also in `gammaMultiply`.

The second problem comes from the lack of shadowing in Zig.
`Color32` has methods `r()`, `g()`, `b()` and `a()`.
Other methods in Rust take parameters `r`, `g`, `b` and `a` eg.

```rust
pub const fn from_rgb(r: u8, g: u8, b: u8) -> Self {
    Self([r, g, b, 255])
}
```

but in Zig this is not possible because these names would shadow methods
`r()`, `g()`, `b()` and `a()`. So we named those parameters in Zig
`red`, `green`, `blue` and `alpha`. Then normally when translating from Rust to Zig
we would lowercase constants for colors but we can't do it because then we would
lowercase `RED` to `red` which would then conflict with method parameters
which are named `red` too.

I personally prefer approach of F# and Rust to allow shadowing.
Shadowing sometimes even prevents bugs because you can shadow variable which
shall not be used so then you guarantee they can't be used.

The third problem is that Zig compiler doesn't typecheck the code until it's used.
We have finished our translation but very likely Zig code is full of problems
which will be detected after we use it. We must use each function in each type instantiation.
It's like C++ templates without concepts.

Additional note: The third problem can be partially remedied by writing following test:

```zig
const color = @import("epaint/color.zig");

test "force typechecking" {
    std.testing.refAllDeclsRecursive(color);
}
```

Unfortunately it won't test whether code makes sense for all imaginable comptime arguments.
