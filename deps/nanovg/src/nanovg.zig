const std = @import("std");
const c = @cImport({
    @cInclude("nanovg.h");
    @cInclude("glad/glad.h");
    @cDefine("NANOVG_GL2", "1");
    @cInclude("nanovg_gl.h");
});

pub const Pi: f32 = 3.14159265358979323846264338327;

// pub const Color = struct { // ABI incompatible :(
//     r: f32,
//     g: f32,
//     b: f32,
//     a: f32,
//     fn c(self: Color) c.NVGcolor {
//         return @bitCast(c.NVGcolor, self);
//     }
// };
pub const Color = c.NVGcolor;

pub const Paint = c.NVGpaint;

pub const Winding = enum(u2) {
    ccw = 1, // Winding for solid shapes
    cw = 2, // Winding for holes
};

pub const Solidity = enum(u1) {
    solid = 1, // CCW
    hole = 2, // CW
};

pub const LineCap = enum(u2) {
    butt,
    round,
    square,
};

pub const LineJoin = enum(u2) {
    miter,
    round,
    bevel,
};

pub const TextAlign = struct {
    pub const HorizontalAlign = enum(u8) {
        left = 1 << 0,
        center = 1 << 1,
        right = 1 << 2,
        _,
    };
    pub const VerticalAlign = enum(u8) {
        top = 1 << 3,
        middle = 1 << 4,
        bottom = 1 << 5,
        baseline = 1 << 6, // Default, align text vertically to baseline.
        _,
    };

    horizontal: HorizontalAlign = .left,
    vertical: VerticalAlign = .baseline,

    pub fn toInt(text_align: TextAlign) u8 {
        return @enumToInt(text_align.horizontal) | @enumToInt(text_align.vertical);
    }
};

pub const GlyphPosition = c.NVGglyphPosition;

pub const Image = struct {
    handle: i32,
};

pub const ImageFlags = packed struct {
    generate_mipmaps: bool = false, // Generate mipmaps during creation of the image.
    repeat_x: bool = false, // Repeat image in X direction.
    repeat_y: bool = false, // Repeat image in Y direction.
    flip_y: bool = false, // Flips (inverses) image in Y direction when rendered.
    premultiplied: bool = false, // Image data has premultiplied alpha.
    nearest: bool = false, // Image interpolation is Nearest instead Linear
};

var ctx: ?*c.NVGcontext = undefined;

pub fn init() void {
    ctx = c.nvgCreateGL2(0);
}

pub fn quit() void {
    c.nvgDeleteGL2(ctx);
}

// Begin drawing a new frame
// Calls to nanovg drawing API should be wrapped in nvgBeginFrame() & nvgEndFrame()
// nvgBeginFrame() defines the size of the window to render to in relation currently
// set viewport (i.e. glViewport on GL backends). Device pixel ration allows to
// control the rendering on Hi-DPI devices.
// For example, GLFW returns two dimension for an opened window: window size and
// frame buffer size. In that case you would set windowWidth/Height to the window size
// devicePixelRatio to: frameBufferWidth / windowWidth.
pub fn beginFrame(window_width: f32, window_height: f32, device_pixel_ratio: f32) void {
    c.nvgBeginFrame(ctx, window_width, window_height, device_pixel_ratio);
}

// Cancels drawing the current frame.
pub fn cancelFrame() void {
    c.nvgCancelFrame(ctx);
}

// Ends drawing flushing remaining render state.
pub fn endFrame() void {
    c.nvgEndFrame(ctx);
}

//
// Color utils
//
// Colors in NanoVG are stored as unsigned ints in ABGR format.

// Returns a color value from red, green, blue values. Alpha will be set to 255 (1.0f).
pub fn rgb(r: u8, g: u8, b: u8) Color {
    return rgbf(
        @intToFloat(f32, r) / 255.0,
        @intToFloat(f32, g) / 255.0,
        @intToFloat(f32, b) / 255.0,
    );
}

// Returns a color value from red, green, blue values. Alpha will be set to 1.0f.
pub fn rgbf(r: f32, g: f32, b: f32) Color {
    return rgbaf(r, g, b, 1);
}

// Returns a color value from red, green, blue and alpha values.
pub fn rgba(r: u8, g: u8, b: u8, a: u8) Color {
    return rgbaf(
        @intToFloat(f32, r) / 255.0,
        @intToFloat(f32, g) / 255.0,
        @intToFloat(f32, b) / 255.0,
        @intToFloat(f32, a) / 255.0,
    );
}

// Returns a color value from red, green, blue and alpha values.
pub fn rgbaf(r: f32, g: f32, b: f32, a: f32) Color {
    return c.nvgRGBAf(r, g, b, a);
    //return .{ .unnamed_0 = .{ .rgba = [_]f32{ r, g, b, a }}, .zigpad = undefined };
    // return .{ .r = r, .g = g, .b = b, .a = a };
}

// // Linearly interpolates from color c0 to c1, and returns resulting color value.
// NVGcolor nvgLerpRGBA(NVGcolor c0, NVGcolor c1, float u);

// // Sets transparency of a color value.
// NVGcolor nvgTransRGBA(NVGcolor c0, unsigned char a);

// // Sets transparency of a color value.
// NVGcolor nvgTransRGBAf(NVGcolor c0, float a);

// // Returns color value specified by hue, saturation and lightness.
// // HSL values are all in range [0..1], alpha will be set to 255.
// NVGcolor nvgHSL(float h, float s, float l);

// // Returns color value specified by hue, saturation and lightness and alpha.
// // HSL values are all in range [0..1], alpha in range [0..255]
// NVGcolor nvgHSLA(float h, float s, float l, unsigned char a);

//
// State Handling
//
// NanoVG contains state which represents how paths will be rendered.
// The state contains transform, fill and stroke styles, text and font styles,
// and scissor clipping.

// Pushes and saves the current render state into a state stack.
// A matching nvgRestore() must be used to restore the state.
pub fn save() void {
    c.nvgSave(ctx);
}

// Pops and restores current render state.
pub fn restore() void {
    c.nvgRestore(ctx);
}

// Resets current render state to default values. Does not affect the render state stack.
pub fn reset() void {
    c.nvgReset(ctx);
}

//
// Render styles
//
// Fill and stroke render style can be either a solid color or a paint which is a gradient or a pattern.
// Solid color is simply defined as a color value, different kinds of paints can be created
// using nvgLinearGradient(), nvgBoxGradient(), nvgRadialGradient() and nvgImagePattern().
//
// Current render style can be saved and restored using nvgSave() and nvgRestore().

// // Sets whether to draw antialias for nvgStroke() and nvgFill(). It's enabled by default.
// void nvgShapeAntiAlias(NVGcontext* ctx, int enabled);

// // Sets current stroke style to a solid color.
pub fn strokeColor(color: Color) void {
    c.nvgStrokeColor(ctx, color);
}

// Sets current stroke style to a paint, which can be a one of the gradients or a pattern.
pub fn strokePaint(paint: Paint) void {
    c.nvgStrokePaint(ctx, paint);
}

// // Sets current fill style to a solid color.
pub fn fillColor(color: Color) void {
    c.nvgFillColor(ctx, color);
}

// Sets current fill style to a paint, which can be a one of the gradients or a pattern.
pub fn fillPaint(paint: Paint) void {
    c.nvgFillPaint(ctx, paint);
}

// // Sets the miter limit of the stroke style.
// // Miter limit controls when a sharp corner is beveled.
// void nvgMiterLimit(NVGcontext* ctx, float limit);

// // Sets the stroke width of the stroke style.
pub fn strokeWidth(size: f32) void {
    c.nvgStrokeWidth(ctx, size);
}

// Sets how the end of the line (cap) is drawn,
// Can be one of: NVG_BUTT (default), NVG_ROUND, NVG_SQUARE.
pub fn lineCap(cap: LineCap) void {
    const c_cap: c_int = switch (cap) {
        .butt => c.NVG_BUTT,
        .round => c.NVG_ROUND,
        .square => c.NVG_SQUARE,
    };
    c.nvgLineCap(ctx, c_cap);
}

// Sets how sharp path corners are drawn.
// Can be one of NVG_MITER (default), NVG_ROUND, NVG_BEVEL.
pub fn lineJoin(join: LineJoin) void {
    const c_join: c_int = switch (join) {
        .miter => c.NVG_MITER,
        .round => c.NVG_ROUND,
        .bevel => c.NVG_BEVEL,
    };
    c.nvgLineJoin(ctx, c_join);
}

// Sets the transparency applied to all rendered shapes.
// Already transparent paths will get proportionally more transparent as well.
pub fn globalAlpha(alpha: f32) void {
    c.nvgGlobalAlpha(ctx, alpha);
}

//
// Transforms
//
// The paths, gradients, patterns and scissor region are transformed by an transformation
// matrix at the time when they are passed to the API.
// The current transformation matrix is a affine matrix:
//   [sx kx tx]
//   [ky sy ty]
//   [ 0  0  1]
// Where: sx,sy define scaling, kx,ky skewing, and tx,ty translation.
// The last row is assumed to be 0,0,1 and is not stored.
//
// Apart from nvgResetTransform(), each transformation function first creates
// specific transformation matrix and pre-multiplies the current transformation by it.
//
// Current coordinate system (transformation) can be saved and restored using nvgSave() and nvgRestore().

// Resets current transform to a identity matrix.
pub fn resetTransform() void {
    c.nvgResetTransform(ctx);
}

// Premultiplies current coordinate system by specified matrix.
// The parameters are interpreted as matrix as follows:
//   [a c e]
//   [b d f]
//   [0 0 1]
// void nvgTransform(NVGcontext* ctx, float a, float b, float c, float d, float e, float f);

// Translates current coordinate system.
pub fn translate(x: f32, y: f32) void {
    c.nvgTranslate(ctx, x, y);
}

// Rotates current coordinate system. Angle is specified in radians.
// void nvgRotate(NVGcontext* ctx, float angle);

// Skews the current coordinate system along X axis. Angle is specified in radians.
// void nvgSkewX(NVGcontext* ctx, float angle);

// Skews the current coordinate system along Y axis. Angle is specified in radians.
// void nvgSkewY(NVGcontext* ctx, float angle);

// Scales the current coordinate system.
pub fn scale(x: f32, y: f32) void {
    c.nvgScale(ctx, x, y);
}

// Stores the top part (a-f) of the current transformation matrix in to the specified buffer.
//   [a c e]
//   [b d f]
//   [0 0 1]
// There should be space for 6 floats in the return buffer for the values a-f.
// void nvgCurrentTransform(NVGcontext* ctx, float* xform);

// The following functions can be used to make calculations on 2x3 transformation matrices.
// A 2x3 matrix is represented as float[6].

// Sets the transform to identity matrix.
// void nvgTransformIdentity(float* dst);

// Sets the transform to translation matrix matrix.
// void nvgTransformTranslate(float* dst, float tx, float ty);

// Sets the transform to scale matrix.
// void nvgTransformScale(float* dst, float sx, float sy);

// Sets the transform to rotate matrix. Angle is specified in radians.
// void nvgTransformRotate(float* dst, float a);

// Sets the transform to skew-x matrix. Angle is specified in radians.
// void nvgTransformSkewX(float* dst, float a);

// Sets the transform to skew-y matrix. Angle is specified in radians.
// void nvgTransformSkewY(float* dst, float a);

// Sets the transform to the result of multiplication of two transforms, of A = A*B.
// void nvgTransformMultiply(float* dst, const float* src);

// Sets the transform to the result of multiplication of two transforms, of A = B*A.
// void nvgTransformPremultiply(float* dst, const float* src);

// Sets the destination to inverse of specified transform.
// Returns 1 if the inverse could be calculated, else 0.
// int nvgTransformInverse(float* dst, const float* src);

// Transform a point by given transform.
// void nvgTransformPoint(float* dstx, float* dsty, const float* xform, float srcx, float srcy);

// Converts degrees to radians and vice versa.
// float nvgDegToRad(float deg);
// float nvgRadToDeg(float rad);

//
// Images
//
// NanoVG allows you to load jpg, png, psd, tga, pic and gif files to be used for rendering.
// In addition you can upload your own image. The image loading is provided by stb_image.
// The parameter imageFlags is combination of flags defined in NVGimageFlags.

// Creates image by loading it from the disk from specified file name.
// Returns handle to the image.
pub fn createImage(filename: [:0]const u8, flags: ImageFlags) Image {
    return Image{ .handle = c.nvgCreateImage(ctx, filename.ptr, @bitCast(u6, flags)) };
}

// // Creates image by loading it from the specified chunk of memory.
// // Returns handle to the image.
// int nvgCreateImageMem(NVGcontext* ctx, int imageFlags, unsigned char* data, int ndata);

// Creates image from specified image data.
// Returns handle to the image.
pub fn createImageRgba(w: u32, h: u32, flags: ImageFlags, data: []const u8) Image {
    return Image{ .handle = c.nvgCreateImageRGBA(ctx, @intCast(c_int, w), @intCast(c_int, h), @bitCast(u6, flags), data.ptr) };
}

// Updates image data specified by image handle.
pub fn updateImage(image: Image, data: []const u8) void {
    c.nvgUpdateImage(ctx, image.handle, data.ptr);
}

// Updates a region of the image data specified by image handle. Data needs to match the size of the texture data.
pub fn updateImageRegion(image: Image, data: []const u8, x: u32, y: u32, w: u32, h: u32) void {
    c.nvgUpdateImageRegion(ctx, image.handle, data.ptr, @intCast(c_int, x), @intCast(c_int, y), @intCast(c_int, w), @intCast(c_int, h));
}

// // Returns the dimensions of a created image.
// void nvgImageSize(NVGcontext* ctx, int image, int* w, int* h);

// Deletes created image.
pub fn deleteImage(image: Image) void {
    c.nvgDeleteImage(ctx, image.handle);
}

//
// Paints
//
// NanoVG supports four types of paints: linear gradient, box gradient, radial gradient and image pattern.
// These can be used as paints for strokes and fills.

// Creates and returns a linear gradient. Parameters (sx,sy)-(ex,ey) specify the start and end coordinates
// of the linear gradient, icol specifies the start color and ocol the end color.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn linearGradient(sx: f32, sy: f32, ex: f32, ey: f32, icol: Color, ocol: Color) Paint {
    return c.nvgLinearGradient(ctx, sx, sy, ex, ey, icol, ocol);
}

// Creates and returns a box gradient. Box gradient is a feathered rounded rectangle, it is useful for rendering
// drop shadows or highlights for boxes. Parameters (x,y) define the top-left corner of the rectangle,
// (w,h) define the size of the rectangle, r defines the corner radius, and f feather. Feather defines how blurry
// the border of the rectangle is. Parameter icol specifies the inner color and ocol the outer color of the gradient.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn boxGradient(x: f32, y: f32, w: f32, h: f32, r: f32, f: f32, icol: Color, ocol: Color) Paint {
    return c.nvgBoxGradient(ctx, x, y, w, h, r, f, icol, ocol);
}

// // Creates and returns a radial gradient. Parameters (cx,cy) specify the center, inr and outr specify
// // the inner and outer radius of the gradient, icol specifies the start color and ocol the end color.
// // The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
// NVGpaint nvgRadialGradient(NVGcontext* ctx, float cx, float cy, float inr, float outr,
// 						   NVGcolor icol, NVGcolor ocol);

// Creates and returns an image patter. Parameters (ox,oy) specify the left-top location of the image pattern,
// (ex,ey) the size of one image, angle rotation around the top-left corner, image is handle to the image to render.
// The gradient is transformed by the current transform when it is passed to nvgFillPaint() or nvgStrokePaint().
pub fn imagePattern(ox: f32, oy: f32, ex: f32, ey: f32, angle: f32, image: Image, alpha: f32) Paint {
    return c.nvgImagePattern(ctx, ox, oy, ex, ey, angle, image.handle, alpha);
}

//
// Scissoring
//
// Scissoring allows you to clip the rendering into a rectangle. This is useful for various
// user interface cases like rendering a text edit or a timeline.

// Sets the current scissor rectangle.
// The scissor rectangle is transformed by the current transform.
pub fn scissor(x: f32, y: f32, w: f32, h: f32) void {
    c.nvgScissor(ctx, x, y, w, h);
}

// // Intersects current scissor rectangle with the specified rectangle.
// // The scissor rectangle is transformed by the current transform.
// // Note: in case the rotation of previous scissor rect differs from
// // the current one, the intersection will be done between the specified
// // rectangle and the previous scissor rectangle transformed in the current
// // transform space. The resulting shape is always rectangle.
// void nvgIntersectScissor(NVGcontext* ctx, float x, float y, float w, float h);

// Reset and disables scissoring.
pub fn resetScissor() void {
    c.nvgResetScissor(ctx);
}

//
// Paths
//
// Drawing a new shape starts with nvgBeginPath(), it clears all the currently defined paths.
// Then you define one or more paths and sub-paths which describe the shape. The are functions
// to draw common shapes like rectangles and circles, and lower level step-by-step functions,
// which allow to define a path curve by curve.
//
// NanoVG uses even-odd fill rule to draw the shapes. Solid shapes should have counter clockwise
// winding and holes should have counter clockwise order. To specify winding of a path you can
// call nvgPathWinding(). This is useful especially for the common shapes, which are drawn CCW.
//
// Finally you can fill the path using current fill style by calling nvgFill(), and stroke it
// with current stroke style by calling nvgStroke().
//
// The curve segments and sub-paths are transformed by the current transform.

// Clears the current path and sub-paths.
pub fn beginPath() void {
    c.nvgBeginPath(ctx);
}

// Starts new sub-path with specified point as first point.
pub fn moveTo(x: f32, y: f32) void {
    c.nvgMoveTo(ctx, x, y);
}

// Adds line segment from the last point in the path to the specified point.
pub fn lineTo(x: f32, y: f32) void {
    c.nvgLineTo(ctx, x, y);
}

// Adds cubic bezier segment from last point in the path via two control points to the specified point.
pub fn bezierTo(c1x: f32, c1y: f32, c2x: f32, c2y: f32, x: f32, y: f32) void {
    c.nvgBezierTo(ctx, c1x, c1y, c2x, c2y, x, y);
}

// Adds quadratic bezier segment from last point in the path via a control point to the specified point.
pub fn quadTo(cx: f32, cy: f32, x: f32, y: f32) void {
    c.nvgQuadTo(ctx, cx, cy, x, y);
}

// Adds an arc segment at the corner defined by the last path point, and two specified points.
pub fn arcTo(x1: f32, y1: f32, x2: f32, y2: f32, r: f32) void {
    c.nvgArcTo(ctx, x1, y1, x2, y2, r);
}

// Closes current sub-path with a line segment.
pub fn closePath() void {
    c.nvgClosePath(ctx);
}

// Sets the current sub-path winding, see NVGwinding and NVGsolidity.
pub fn pathWinding(dir: Winding) void {
    c.nvgPathWinding(ctx, @enumToInt(dir));
}

// Creates new circle arc shaped sub-path. The arc center is at cx,cy, the arc radius is r,
// and the arc is drawn from angle a0 to a1, and swept in direction dir (NVG_CCW, or NVG_CW).
// Angles are specified in radians.
pub fn arc(cx: f32, cy: f32, r: f32, a0: f32, a1: f32, dir: Winding) void {
    c.nvgArc(ctx, cx, cy, r, a0, a1, @enumToInt(dir));
}

// Creates new rectangle shaped sub-path.
pub fn rect(x: f32, y: f32, w: f32, h: f32) void {
    c.nvgRect(ctx, x, y, w, h);
}

// Creates new rounded rectangle shaped sub-path.
pub fn roundedRect(x: f32, y: f32, w: f32, h: f32, r: f32) void {
    c.nvgRoundedRect(ctx, x, y, w, h, r);
}

// // Creates new rounded rectangle shaped sub-path with varying radii for each corner.
// void nvgRoundedRectVarying(NVGcontext* ctx, float x, float y, float w, float h, float radTopLeft, float radTopRight, float radBottomRight, float radBottomLeft);

// Creates new ellipse shaped sub-path.
pub fn ellipse(cx: f32, cy: f32, rx: f32, ry: f32) void {
    c.nvgEllipse(ctx, cx, cy, rx, ry);
}

// Creates new circle shaped sub-path.
pub fn circle(cx: f32, cy: f32, r: f32) void {
    c.nvgCircle(ctx, cx, cy, r);
}

// Fills the current path with current fill style.
pub fn fill() void {
    c.nvgFill(ctx);
}

// Fills the current path with current stroke style.
pub fn stroke() void {
    c.nvgStroke(ctx);
}

//
// Text
//
// NanoVG allows you to load .ttf files and use the font to render text.
//
// The appearance of the text can be defined by setting the current text style
// and by specifying the fill color. Common text and font settings such as
// font size, letter spacing and text align are supported. Font blur allows you
// to create simple text effects such as drop shadows.
//
// At render time the font face can be set based on the font handles or name.
//
// Font measure functions return values in local space, the calculations are
// carried in the same resolution as the final rendering. This is done because
// the text glyph positions are snapped to the nearest pixels sharp rendering.
//
// The local space means that values are not rotated or scale as per the current
// transformation. For example if you set font size to 12, which would mean that
// line height is 16, then regardless of the current scaling and rotation, the
// returned line height is always 16. Some measures may vary because of the scaling
// since aforementioned pixel snapping.
//
// While this may sound a little odd, the setup allows you to always render the
// same way regardless of scaling. I.e. following works regardless of scaling:
//
//		const char* txt = "Text me up.";
//		nvgTextBounds(vg, x,y, txt, NULL, bounds);
//		nvgBeginPath(vg);
//		nvgRoundedRect(vg, bounds[0],bounds[1], bounds[2]-bounds[0], bounds[3]-bounds[1]);
//		nvgFill(vg);
//
// Note: currently only solid color fill is supported for text.

// Creates font by loading it from the disk from specified file name.
// Returns handle to the font.
pub fn createFont(name: [:0]const u8, filename: [:0]const u8) i32 {
    return c.nvgCreateFont(ctx, name, filename);
}

// font_index specifies which font face to load from a .ttf/.ttc file.
pub fn createFontAtIndex(name: [:0]const u8, filename: [:0]const u8, font_index: i32) i32 {
    return c.nvgCreateFontAtIndex(ctx, name, filename, font_index);
}

// // Creates font by loading it from the specified memory chunk.
// // Returns handle to the font.
// int nvgCreateFontMem(NVGcontext* ctx, const char* name, unsigned char* data, int ndata, int freeData);

// // fontIndex specifies which font face to load from a .ttf/.ttc file.
// int nvgCreateFontMemAtIndex(NVGcontext* ctx, const char* name, unsigned char* data, int ndata, int freeData, const int fontIndex);

// // Finds a loaded font of specified name, and returns handle to it, or -1 if the font is not found.
// int nvgFindFont(NVGcontext* ctx, const char* name);

// Adds a fallback font by handle.
pub fn addFallbackFontId(base_font: i32, fallback_font: i32) i32 {
    return c.nvgAddFallbackFontId(ctx, base_font, fallback_font);
}

// // Adds a fallback font by name.
// int nvgAddFallbackFont(NVGcontext* ctx, const char* baseFont, const char* fallbackFont);

// // Resets fallback fonts by handle.
// void nvgResetFallbackFontsId(NVGcontext* ctx, int baseFont);

// // Resets fallback fonts by name.
// void nvgResetFallbackFonts(NVGcontext* ctx, const char* baseFont);

// Sets the font size of current text style.
pub fn fontSize(size: f32) void {
    c.nvgFontSize(ctx, size);
}

// Sets the blur of current text style.
pub fn fontBlur(blur: f32) void {
    c.nvgFontBlur(ctx, blur);
}

// // Sets the letter spacing of current text style.
// void nvgTextLetterSpacing(NVGcontext* ctx, float spacing);

// // Sets the proportional line height of current text style. The line height is specified as multiple of font size.
// void nvgTextLineHeight(NVGcontext* ctx, float lineHeight);

// Sets the text align of current text style, see NVGalign for options.
pub fn textAlign(text_align: TextAlign) void {
    c.nvgTextAlign(ctx, text_align.toInt());
}

// Sets the font face based on specified id of current text style.
pub fn fontFaceId(font: i32) void {
    c.nvgFontFaceId(ctx, font);
}

// Sets the font face based on specified name of current text style.
pub fn fontFace(font: [:0]const u8) void {
    c.nvgFontFace(ctx, font);
}

// Draws text string at specified location. If end is specified only the sub-string up to the end is drawn.
pub fn text(x: f32, y: f32, string: []const u8) f32 {
    if (string.len == 0) return x;
    return c.nvgText(ctx, x, y, std.meta.assumeSentinel(string, 0), string.ptr + string.len);
}

// // Draws multi-line text string at specified location wrapped at the specified width. If end is specified only the sub-string up to the end is drawn.
// // White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
// // Words longer than the max width are slit at nearest character (i.e. no hyphenation).
// void nvgTextBox(NVGcontext* ctx, float x, float y, float breakRowWidth, const char* string, const char* end);

// Measures the specified text string. Parameter bounds should be a pointer to float[4],
// if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
// Returns the horizontal advance of the measured text (i.e. where the next character should drawn).
// Measured values are returned in local coordinate space.
pub fn textBounds(x: f32, y: f32, string: []const u8, bounds: *[4]f32) f32 {
    return c.nvgTextBounds(ctx, x, y, std.meta.assumeSentinel(string, 0), string.ptr + string.len, bounds);
}

pub fn textWidth(string: []const u8) f32 {
    return c.nvgTextBounds(ctx, 0, 0, std.meta.assumeSentinel(string, 0), string.ptr + string.len, null);
}

// // Measures the specified multi-text string. Parameter bounds should be a pointer to float[4],
// // if the bounding box of the text should be returned. The bounds value are [xmin,ymin, xmax,ymax]
// // Measured values are returned in local coordinate space.
// void nvgTextBoxBounds(NVGcontext* ctx, float x, float y, float breakRowWidth, const char* string, const char* end, float* bounds);

// Calculates the glyph x positions of the specified text. If end is specified only the sub-string will be used.
// Measured values are returned in local coordinate space.
pub fn textGlyphPositions(x: f32, y: f32, string: []const u8, positions: []GlyphPosition) void {
    if (string.len == 0) return;
    _ = c.nvgTextGlyphPositions(ctx, x, y, std.meta.assumeSentinel(string, 0), string.ptr + string.len, positions.ptr, @intCast(c_int, positions.len));
}

// Returns the vertical metrics based on the current text style.
// Measured values are returned in local coordinate space.
pub fn textMetrics(ascender: ?*f32, descender: ?*f32, line_height: ?*f32) void {
    c.nvgTextMetrics(ctx, ascender, descender, line_height);
}

// // Breaks the specified text into lines. If end is specified only the sub-string will be used.
// // White space is stripped at the beginning of the rows, the text is split at word boundaries or when new-line characters are encountered.
// // Words longer than the max width are slit at nearest character (i.e. no hyphenation).
// int nvgTextBreakLines(NVGcontext* ctx, const char* string, const char* end, float breakRowWidth, NVGtextRow* rows, int maxRows);
