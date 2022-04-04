# musi leko
> musi: game, fun, entertainment

> leko: block, square, cube

> musi leko: block game, square fun

yeah its a working title

musileko is a game/engine for worlds made of voxels. currently still early in development

# clonin n buildin
use zig 0.9.0, have gpu drivers that can handle opengl 3.3

musileko autogenerates `.zig` files for each source directory.

these can be manually updated with `zig build imports` following file tree changes

use `zig build clean_imports` to delete them

## windows
just `zig build run`, it *should* work

## linux
same as windows, just install glfw3 from your pm of choice

## mac os
you're on your own

# controls
standard wasd and mouse stuff, space goes up, lshift goes down
- \[`\] to unlock mouse
- \[f4\] to toggle fullscreen
- \[z\] to toggle noclip