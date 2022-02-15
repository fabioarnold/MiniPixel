const std = @import("std");
const fs = std.fs;
const mem = std.mem;
const Builder = std.build.Builder;
const FileSource = std.build.FileSource;
const Pkg = std.build.Pkg;

const win32 = Pkg{ .name = "win32", .path = FileSource.relative("deps/zigwin32/win32.zig") };
const nfd = Pkg{ .name = "nfd", .path = FileSource.relative("deps/nfd-zig/src/lib.zig") };
const nanovg = Pkg{ .name = "nanovg", .path = FileSource.relative("deps/nanovg/src/nanovg.zig") };
const gui = Pkg{ .name = "gui", .path = FileSource.relative("src/gui/gui.zig"), .dependencies = &.{nanovg} };

fn printError(str: []const u8) void {
    var stderr = std.io.getStdErr();
    var stderr_writer = stderr.writer();
    var tty_config = std.debug.detectTTYConfig();
    tty_config.setColor(stderr_writer, .Red);
    _ = stderr_writer.write("ERROR: ") catch {};
    tty_config.setColor(stderr_writer, .Reset);
    _ = stderr_writer.write(str) catch {};
}

fn installPalFiles(b: *Builder) void {
    const pals = [_][]const u8{ "arne16.pal", "arne32.pal", "db32.pal", "default.pal", "famicube.pal", "pico-8.pal" };
    inline for (pals) |pal| {
        b.installBinFile("data/palettes/" ++ pal, "palettes/" ++ pal);
    }
}

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("minipixel", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
    exe.addIncludeDir("lib/nanovg/src");
    exe.addIncludeDir("lib/gl2/include");
    if (exe.target.isWindows()) {
        exe.addVcpkgPaths(.dynamic) catch @panic("vcpkg not installed");
        if (exe.vcpkg_bin_path) |bin_path| {
            for (&[_][]const u8{ "SDL2.dll", "libpng16.dll", "zlib1.dll" }) |dll| {
                const src_dll = try std.fs.path.join(b.allocator, &.{ bin_path, dll });
                b.installBinFile(src_dll, dll);
            }
        }
        exe.subsystem = .Windows;
        exe.linkSystemLibrary("shell32");
        std.fs.cwd().access("minipixel.o", .{}) catch {
            printError("minipixel.o not found. Please use VS Developer Prompt and run\n\n" ++
                "\trc /fo minipixel.o minipixel.rc\n\nbefore continuing\n");
            return error.FileNotFound;
        };
        exe.addObjectFile("minipixel.o"); // add icon
        exe.want_lto = false; // workaround for https://github.com/ziglang/zig/issues/8531
    } else if (exe.target.isDarwin()) {
        exe.addCSourceFile("src/c/sdl_hacks.m", &.{});
    }
    const c_flags = &.{ "-std=c99", "-D_CRT_SECURE_NO_WARNINGS" };
    exe.addCSourceFile("src/c/png_image.c", &.{"-std=c99"});
    exe.addCSourceFile("lib/gl2/src/glad.c", c_flags);
    exe.addCSourceFile("lib/nanovg/src/nanovg.c", c_flags);
    exe.addCSourceFile("deps/nanovg/src/c/nanovg_gl2_impl.c", c_flags);
    exe.addPackage(win32);
    exe.addPackage(nfd);
    exe.addPackage(nanovg);
    exe.addPackage(gui);
    const nfd_lib = try @import("deps/nfd-zig/build.zig").makeLib(b, mode, target, "deps/nfd-zig/");
    exe.linkLibrary(nfd_lib);
    exe.linkSystemLibrary("SDL2");
    if (exe.target.isWindows()) {
        // Workaround for CI: Zig detects pkg-config and resolves -lpng16 which doesn't exist
        exe.linkSystemLibraryName("libpng16");
    } else {
        exe.linkSystemLibrary("libpng16");
    }
    if (exe.target.isDarwin()) {
        exe.linkFramework("OpenGL");
    } else if (exe.target.isWindows()) {
        exe.linkSystemLibrary("opengl32");
    } else if (exe.target.isLinux()) {
        exe.linkSystemLibrary("gl");
        exe.linkSystemLibrary("X11");
    }
    exe.linkLibC();
    if (b.is_release) exe.strip = true;
    exe.install();

    installPalFiles(b);

    const test_cmd = b.addTest("src/tests.zig");
    test_cmd.setBuildMode(mode);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run Mini Pixel");
    run_step.dependOn(&run_cmd.step);
}
