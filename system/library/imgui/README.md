# Red/System ImGui Port

This is a native Red/System starter port of Dear ImGui concepts, not a C/C++ wrapper.

Current scope:

- Immediate-mode frame lifecycle
- Window layout state
- Draw-command generation for windows and widgets
- ASCII software renderer
- Color pixel software renderer
- PPM image export from the pixel buffer
- `text`
- `button`
- `checkbox`
- `slider-float`
- Headless input simulation for tests and demos
- Draw list inspection helpers for backend/debug work

Current non-goals:

- Full Dear ImGui API parity
- Native OS window backends consuming the draw list directly
- Docking, tables, draw lists, fonts, navigation, clipping, or platform IO

Build the state/demo binary from the repository root with:

```sh
rebol -qs red.r system/library/imgui/demo.reds
```

The generated binary is headless. It simulates mouse input and prints the resulting widget state transitions.

Build the ASCII renderer demo with:

```sh
rebol -qs red.r system/library/imgui/ascii-demo.reds
./ascii-demo
```

Build the image export demo with:

```sh
rebol -qs red.r system/library/imgui/image-demo.reds
./image-demo
```

The image demo writes `imgui-demo.ppm` in the current working directory.

Build the Linux X11 demo with:

```sh
rebol -qs red.r system/library/imgui/linux-demo.reds
./linux-demo
```

The X11 demo opens a native Linux window and renders the current draw list. Press any key or mouse button in the window to close it.

The current Linux backend renders by rasterizing the UI into the color software pixel buffer and blitting that framebuffer into an X11 window with `XPutImage`.

Build the Linux GLX/OpenGL demo with:

```sh
rebol -qs red.r system/library/imgui/linux-gl-demo.reds
./linux-gl-demo
```

The GLX demo uploads the software color framebuffer to an OpenGL texture and presents it in a native Linux window.
The GLX backend now has a real GPU rendering path: it builds vertex/index buffers from the current draw commands, uses a shader pipeline, and renders geometry directly in OpenGL with a bitmap font atlas texture.

Build the Linux GLX/OpenGL demo with:

```sh
rebol -qs red.r system/library/imgui/linux-gl-demo.reds
./linux-gl-demo
```

The GLX demo uploads the software color framebuffer to an OpenGL texture and presents it in a native Linux window.
On systems where Red/System emits 32-bit binaries, you need a 32-bit `libGL.so.1` runtime available.
