## Building Mini Pixel from source

### Requirements
* A current master build of the [Zig compiler](https://ziglang.org/download/)
* Only on Windows: [vcpkg package manager](https://github.com/microsoft/vcpkg) to install ...
* The [SDL2 library](https://libsdl.org)

### Install dependencies using vcpkg
```
> vcpkg install sdl2:x64-windows libpng:x64-windows
```

### Build icon resource for Windows
From VS command prompt:

```
> rc /fo minipixel.o minipixel.rc 
```

### Build and run
```
$ zig build run
```

### Building a Windows release
```
$ zig build -Dtarget=x86_64-windows-gnu -Drelease-small=true
```

Copy contents of zig-out/bin to VS installer project.