# Drawing circles

`epaint` is bigger than `ecolor` and `emath`.
We translate it in several phases:

- In the first phase we will support just one shape - circle.
  Circle will serve as a good enought test of tesellator.
- In the second phase we will add support for all other shapes except text.
- Finally in the third phase we will add support for text.

Since we won't use `stats.rs` and `mutex.rs` we don't need to translate them.
`mutex.rs` is in egui to satisfy whims of the borrow checker so it's existence
in Zig world doesn't make sense.

This is the first phase where we want to draw a circle.
To draw a shape we need to describe it and then convert its description to triangles
so it could be processed by GPU.

Circles are desribed by `CircleShape`. They are converted to triangles by `tessellate_circle`.
Triangles are stored in `Mesh`.

Let's convert `Mesh` first. First we see that `Vertex` has two definitions.
One of them is for Unity so we can drop it because we don't care about Unity.
Second we don't want support legacy render backends limited to 16-bit vertex indices.
So let's drop this too. `Mesh` depends on `TextureId` which we translate as `Texture.Id`
and `TSTransform`. Code in `Mesh` needs to convert number of vertices stored as `usize`
to vertex index stored as `u32`. The strength of Rust is that it checks for overflows.
In Zig we use `@intCast` where overflow results in undefined behavior which is bad.
Unfortunately we haven't done anything about it.

Then we translate `Stroke` which allows us to translate `CircleShape`.
We translate it into module shape as `Circle` so the users will refer to it by `Shape.Circle`
instead of `Shape.CircleShape`. Again we have to deal with the lack of shadowing.
One example is that we have to rename `stroke` parameter of `Shape.Circle.stroke` function
to `stroke0`.

Even though Zig is more low level then Rust our code is shorter.
The main reason is that we have omitted lots implementations of `From` trait
which serve for type conversions. For example we don't need converting tuples to stroke.
This makes code easier to read because there's only one stroke representation.
Another good thing is that we have omitted many implementations of `Default`.
They sometimes obfuscate the code. For example currently default `Color32` is `TRANSPARENT`
but `PLACEHOLDER` color would also make sense. In my opinion it's better to write
`Color32::TRANSPARENT` than `Default::default()`.

The last piece is to translate `Tessellator` and its function `tessellate_circle`.
We found several annoyances when translating code from `tessellator.rs`.
The first one is that `for` loop with `u32` range has `usize` loop variable.
For example:

```zig
const n: u32 = undefined;
for (2..n) |i| {
    // `i` has type `usize`.
}
```

Unfortunately writing range as `@as(u32, 2)..n` doesn't help at all.
Due to this our code is full of things like `@as(u32, @intCast(i))` - not nice.
Here shadowing would help because we could shadow `usize` loop variable with `u32` variable.

The second annoyance is that Rust code contains variables `i0` and `i1` which in Zig are types.
In many languages types can't be used as values so there's no problem.
But in Zig types are values so we had to replace `i0` by `@"i0"` and `i1` by `@"i1"`.
And because `i1` was used for loop variables we ended with ugly `@as(u32, @intCast(@"i1"))`
all over the place.

The third annoyance is that we can't use `==` for comparing custom structs.
I don't like operator overloading much but sometimes it can be a good thing.
For example in Zig we have to test equality of colors by `eql` function instead of `==`.
