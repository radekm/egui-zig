# Drawing other shapes

## Ellipse

Now we will add support for other shapes. Let's start with ellipse.
We translate `EllipseShape` as `Shape.Ellipse`. It seems weird that `tessellateEllipse`
allocates memory for slice `quarter` and array list `points`.
I believe these structures should be pooled in `Tessellator.T`.

I added `Vec2.isZero` because `v == Vec2.ZERO` returns vector
and I don't know any better way to determine if a vector is zero.

Calling `addLineLoop` from `tessellateEllipse` revealed that `addLineLoop`
is completely wrong. The reason is that it belongs to non-public `Path` type
so our trick to use `std.testing.refAllDeclsRecursive` to force type checking from `demo.zig`
doesn't work because `Path` is not visible from `demo.zig`.
It's really sad that Zig successfully compiles file which contains garbage.
BTW it doesn't even type-check `if` body if condition is `false` at compile-time:

```zig
const CUT_OFF_SHARP_CORNERS = false;
const right_angle_length_sq = 0.5;
const sharper_than_a_right_angle = length_sq < right_angle_length_sq;
if (CUT_OFF_SHARP_CORNERS and sharper_than_a_right_angle) {
    // cut off the sharp corner
    const center_normal = normal.normalized();
    const n0c = (n0 + center_normal) / 2.0;
    const n1c = (n1 + center_normal) / 2.0;
    self.addPoint(points[i], n0c / Vec2.lengthSq(n0c));
    self.addPoint(points[i], n1c / Vec2.lengthSq(n1c));
}
```

Body calls method `normalized` which doesn't exist and
`try` is missing before `self.addPoint` calls.

## Path

Next we add support for path. We translate `PathShape` as `Shape.Path`
and `tessellate_path` as `tessellatePath`. Similarly to `addLineLoop`
we discovered that `addOpenPoints` was completely wrong after we called it
from `tessellatePath`.

And finally, the problem that gave me a bit of trouble.
Originally in `tessellatePath` I had the following code

```zig
const typ = if (closed)
    PathType.closed
else
    PathType.open;
```

Running `zig build` resulted in the following error

```
error: error: Invalid record (Producer: 'zig 0.12.0' Reader: 'LLVM 17.0.6')
```

which unfortunately doesn't give any clue what's wrong. By commenting out different parts
of the code I discovered where the problem is and rewrote the expression to

```zig
const typ: PathType = if (closed)
    .closed
else
    .open;
```

which fixed it.

## Rect

We want to translate `RectShape` as `Shape.Rect`. But since `Rect` name is already
used by `Rect` from `emath` we first import whole `emath` as `m` and start referring
to `Rect` from `emath` by `m.Rect`.

Function `tessellate_rect` calls `fill_closed_path_with_uv` giving it lambda function `uv_from_pos`.
Zig doesn't support lambda functions. Fortunately for us `fill_closed_path_with_uv` is always
called with the same lambda. This means that we can specialize our translated `fillClosedPathWithUv`
to concrete lambda a don't have to pass any lambda. Instead of lambda we pass
values from its closure `rect_to_fill: Rect.T` and `rect_in_texture: Rect.T`.

## Quadratic bezier curve

Not suprisingly we translate `QuadraticBezierShape` as `Shape.QuadraticBezier`.
The only challenge are two functions which take lambdas.
The first of them is `quadratic_for_each_local_extremum` which calls the given lambda
with `f32` argument at most once. So we can just return `?f32` and no lambda is needed.

The more complex one is `for_each_flattened_with_t` which calls the given lambda multiple times.
We translate the lambda parameter as `callback: anytype` and in the body of `forEachFlattenedWithT`
we call it by

```zig
try callback.run(self.sample(t), t);
```

For comparison here is how `for_each_flattened_with_t` is used in Rust:

```rust
let mut result = vec![self.points[0]];
self.for_each_flattened_with_t(tolerance, &mut |p, _t| {
    result.push(p);
});
```

And here is much uglier version in Zig. In Zig we have to create anonymous struct with
method `run` and pass it to `forEachFlattenedWithT`:

```zig
var result = std.ArrayList(Pos2.T).init(allocator);
errdefer result.deinit();
try result.append(self.points[0]);

const callback = struct {
    context: *std.ArrayList(Pos2.T),
    fn run(self_nested: @This(), p: Pos2.T, t: f32) Allocator.Error!void {
        _ = t;
        try self_nested.context.append(p);
    }
}{ .context = &result };
try self.forEachFlattenedWithT(tolerance, callback);
```

The lack of shadowing in Zig doesn't help either - we have to use `selfNested` instead of `self`.

## Cubic bezier curve

Translating cubic bezier curve is similar to quadratic bezier curve.
The slight difference is that `cubicForEachLocalExtremum` returns at most two values
instead of at most one value as was the case with `quadraticForEachLocalExtremum`.
So instead of returning `?f32` we return `BoundedArray(f32, 2)`.

For the other function taking lambda namely `for_each_flattened_with_t` for cubic beziers
we use exactly the same trick as before. We replace Rust lambda parameter by parameter `callback: anytype`
and in the body call `callback.run()`. And again it's uglier than in Rust
but on the other hand everybody at least sees which variables belong to the closure.

When running expanded `demo.zig` we found
a problem with our translation of for loops. Following Rust for loop is totally fine

```rust
let count = params.count as u32;
for index in 1..count {
    // body
}
```

But when translated to Zig

```zig
const count: u32 = @intFromFloat(params.count);
for (1..count) |index| {
    // body
}
```

it may panic with integer overflow if upper bound `count` is smaller than lower bound `1`.
We fixed the code by wrapping the whole for loop in `if` ensuring that `count` is at least `1`.
Unfortunately similar problems may lurk elsewhere.

## Line segment

In `epaint` line segment does not have dedicated struct.
But we create one for consistency.
