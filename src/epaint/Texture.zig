pub const Id = union(enum) {
    /// Textures allocated using [`TextureManager`].
    ///
    /// The first texture (`TextureId::Managed(0)`) is used for the font data.
    managed: u64,
    /// Your own texture, defined in any which way you want.
    /// The backend renderer will presumably use this to look up what texture to use.
    user: u64,

    pub const DEFAULT = Id{ .managed = 0 };

    pub fn eql(self: Id, other: Id) bool {
        return switch (self) {
            .managed => |i| switch (other) {
                .managed => |j| i == j,
                else => false,
            },
            .user => |i| switch (other) {
                .user => |j| i == j,
                else => false,
            },
        };
    }
};
