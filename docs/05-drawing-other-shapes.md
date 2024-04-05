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
