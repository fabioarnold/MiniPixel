const builtin = @import("builtin");

const sdl2_include_prefix = if (builtin.os.tag == .windows or builtin.os.tag == .macos) "SDL2/" else "";

pub usingnamespace @cImport({
    @cInclude(sdl2_include_prefix ++ "SDL.h");
    @cInclude(sdl2_include_prefix ++ "SDL_opengl.h");
    @cInclude(sdl2_include_prefix ++ "SDL_syswm.h");
});