pub const Color = [4]u8;

pub const BlendMode = enum(u1) {
    alpha,
    replace,
};

pub fn eql(a: Color, b: Color) bool {
    return a[0] == b[0] and a[1] == b[1] and a[2] == b[2] and a[3] == b[3];
}

fn mul8(a: u8, b: u8) u8 {
    return @truncate(u8, (@as(u16, a) * @as(u16, b)) / 0xff);
}

fn div8(a: u8, b: u8) u8 {
    return @truncate(u8, @divTrunc(@as(u16, a) * 0xff, @as(u16, b)));
}

// blend color a over b (Porter Duff)
// a_out = a_a + a_b * (1 - a_a)
// c_out = (c_a * a_a + c_b * a_b * (1 - a_a)) / a_out
pub fn blend(a: []const u8, b: []const u8) Color {
    var out: Color = [_]u8{0} ** 4;
    const fac = mul8(b[3], 0xff - a[3]);
    out[3] = a[3] + fac;
    if (out[3] > 0) {
        out[0] = div8(mul8(a[0], a[3]) + mul8(b[0], fac), out[3]);
        out[1] = div8(mul8(a[1], a[3]) + mul8(b[1], fac), out[3]);
        out[2] = div8(mul8(a[2], a[3]) + mul8(b[2], fac), out[3]);
    }
    return out;
}
