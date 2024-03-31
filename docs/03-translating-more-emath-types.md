# Translating more types from `emath` crate

Before translating `epaint` we need to translate more `emath` types.
Specifically we need to translate `Rect` but it depends on `Rangef` and `Rot2`
so we must translate these too.

When previously translating `Vec2`, `Vec2b` and `Pos2`
we made them aliases for Zig vectors. Now we will make `Rect`, `Rangef` and `Rot2`
proper structs. This will allow us to put functions inside these structs
so we may have methods. For consistency with `vec2.zig`, `vec2b.zig` and `pos2.zig`
we will still name the types `T` and require users to import whole file, eg:

```zig
const rect = @import("rect.zig");
```

Due to the lack of shadowing the above import would conflict with `rect` variable.
So we will name all files in PascalCase and import them as PascalCase.
This seems fine because each file represents a struct and structs can have PascalCase names.

Now these structs look like OCaml modules which is awesome and we solved shadowing problem too.

With this awesome naming we shall consider renaming `Color.Color32` type
to `Color.Bytes` and `Color.Rgba` to `Color.Floats`.
Also we may rename `Rangef` to simpler `Range` because `Vec2` is also not called `Vec2f`.
But for now lets leave it as it is.

While we talk about naming I have to also mention that I don't like that
variables in Zig are named in snake_case and functions are named in camelCase.
What if a variable contains a function? But for now I also leave it that way
because it helps with the lack of shadowing problem.

Very good thing when translating from Rust to Zig is that in Zig there's less code duplication.
Because in Rust single trait is sometimes implemented twice for `T` and `&T` (immutable case)
or for `T` and `&mut T` (mutable case) while in Zig we implement function
either for `T` (immutable case) or for `*T` (mutable case).
Partly this is thanks to hidden pass by reference in Zig where
compiler can replace parameter of type `T` by parameter of type `&T`
whenever it believes pass by reference is more efficient than pass by value.
Unfortunately this in some rare cases may lead to disaster
(for more see talk ATTACK of the KILLER FEATURES by Martin Wickham).
