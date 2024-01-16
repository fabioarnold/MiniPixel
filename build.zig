const std = @import("std");

fn installPalFiles(b: *std.Build) void {
    const pals = [_][]const u8{ "arne16.pal", "arne32.pal", "db32.pal", "default.pal", "famicube.pal", "pico-8.pal" };
    inline for (pals) |pal| {
        b.installBinFile("data/palettes/" ++ pal, "palettes/" ++ pal);
    }
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const automated_testing = b.option(bool, "automated-testing", "Enable automated testing") orelse false;

    const nfd_dep = b.dependency("nfd", .{ .target = target, .optimize = optimize });
    const sdl_dep = b.dependency("sdl", .{ .target = target, .optimize = optimize });
    const zigwin32_dep = b.dependency("zigwin32", .{});
    const nanovg_dep = b.dependency("nanovg", .{ .target = target, .optimize = optimize });

    const nanovg_mod = nanovg_dep.module("nanovg");
    const gui_mod = b.createModule(.{ .root_source_file = .{ .path = "src/gui/gui.zig" } });
    gui_mod.addImport("nanovg", nanovg_mod);
    const data_mod = b.createModule(.{ .root_source_file = .{ .path = "data/data.zig" } });


    const exe = b.addExecutable(.{
        .name = "minipixel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const exe_options = b.addOptions();
    exe.root_module.addOptions("build_options", exe_options);
    exe_options.addOption(bool, "automated_testing", automated_testing);

    exe.addIncludePath(.{ .path = "lib/gl2/include" });
    if (target.result.os.tag == .windows) {
        // exe.addVcpkgPaths(.dynamic) catch @panic("vcpkg not installed");
        // if (exe.vcpkg_bin_path) |bin_path| {
        //     for (&[_][]const u8{ "libpng16.dll", "zlib1.dll" }) |dll| {
        //         const src_dll = try std.fs.path.join(b.allocator, &.{ bin_path, dll });
        //         b.installBinFile(src_dll, dll);
        //     }
        // }
        exe.subsystem = .Windows;
        exe.linkSystemLibrary("shell32");
        std.fs.cwd().access("minipixel.o", .{}) catch {
            std.log.err("minipixel.o not found. Please use VS Developer Prompt and run\n\n" ++
                "\trc /fo minipixel.o minipixel.rc\n\nbefore continuing\n", .{});
            return error.FileNotFound;
        };
        exe.addObjectFile(.{ .path = "minipixel.o" }); // add icon
    } else if (target.result.os.tag == .macos) {
        exe.addCSourceFile(.{ .file = .{ .path = "src/c/sdl_hacks.m" }, .flags = &.{} });
    }
    const c_flags: []const []const u8 = if (optimize == .Debug)
        &.{ "-std=c99", "-D_CRT_SECURE_NO_WARNINGS", "-O0", "-g" }
    else
        &.{ "-std=c99", "-D_CRT_SECURE_NO_WARNINGS" };
    exe.addCSourceFile(.{ .file = .{ .path = "src/c/png_image.c" }, .flags = &.{"-std=c99"} });
    exe.addCSourceFile(.{ .file = .{ .path = "lib/gl2/src/glad.c" }, .flags = c_flags });
    exe.root_module.addImport("win32", zigwin32_dep.module("zigwin32"));
    exe.root_module.addImport("nfd", nfd_dep.module("nfd"));
    exe.root_module.addImport("nanovg", nanovg_mod);
    exe.root_module.addImport("gui", gui_mod);
    exe.root_module.addImport("data", data_mod);
    exe.linkLibrary(sdl_dep.artifact("SDL2"));
    if (target.result.os.tag == .windows) {
        // Workaround for CI: Zig detects pkg-config and resolves -lpng16 which doesn't exist
        exe.linkSystemLibrary("libpng16");
    } else if (target.result.os.tag == .macos) {
        exe.addIncludePath(.{ .path = "/opt/homebrew/include" });
        exe.addLibraryPath(.{ .path = "/opt/homebrew/lib" });
        exe.linkSystemLibrary("png");
    } else {
        exe.linkSystemLibrary("libpng16");
    }
    if (target.result.os.tag == .macos) {
        exe.linkFramework("OpenGL");
    } else if (target.result.os.tag == .windows) {
        exe.linkSystemLibrary("opengl32");
    } else if (target.result.os.tag == .linux) {
        exe.linkSystemLibrary("gl");
        exe.linkSystemLibrary("X11");
    }
    exe.linkLibC();
    b.installArtifact(exe);

    installPalFiles(b);

    const test_cmd = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .optimize = optimize,
    });
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&test_cmd.step);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run Mini Pixel");
    run_step.dependOn(&run_cmd.step);
}
