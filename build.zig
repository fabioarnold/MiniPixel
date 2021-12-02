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

pub fn build(b: *Builder) !void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const exe = b.addExecutable("minipixel", "src/main.zig");
    exe.setBuildMode(mode);
    exe.setTarget(target);
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
        exe.addObjectFile("minipixel.o"); // add icon
        exe.want_lto = false; // workaround for https://github.com/ziglang/zig/issues/8531
    } else if (exe.target.isDarwin()) {
        exe.addCSourceFile("src/c/sdl_hacks.m", &.{});
    }
    exe.addIncludeDir("lib/nanovg/src");
    exe.addIncludeDir("lib/gl2/include");
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
    exe.linkSystemLibrary("libpng16");
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

    const run_cmd = exe.run();
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run VectorZig");
    run_step.dependOn(&run_cmd.step);

    // if (exe.target.isWindows()) {
    //     const sdk_bin_dir = "C:\\Program Files (x86)\\Windows Kits\\10\\bin\\10.0.18362.0\\x64\\";
    //     const mt_exe = sdk_bin_dir ++ "mt.exe";
    //     //const rc_exe = sdk_bin_dir ++ "rc.exe";
    //     //b.addSystemCommand(&[_][]const u8{ rc_exe, "/fo", "vector_ico.o", "vector.rc" });
    //     const outputresource = try std.mem.join(b.allocator, "", &.{ "-outputresource:", "zig-cache\\bin\\", exe.out_filename, ";1" });
    //     const manifest_cmd = b.addSystemCommand(&.{ mt_exe, "-manifest", "app.manifest", outputresource });
    //     manifest_cmd.step.dependOn(b.getInstallStep());
    //     const manifest_step = b.step("manifest", "Embed manifest");
    //     manifest_step.dependOn(&manifest_cmd.step);
    //     run_cmd.step.dependOn(&manifest_cmd.step);
    // }
}
