#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#include <X11/Xlib.h>
#include <GL/gl.h>
#include <GL/glx.h>

static int x_error = 0;

static int on_x_error(Display *display, XErrorEvent *event) {
    (void)display;
    (void)event;
    x_error = 1;
    return 0;
}

int main(void) {
    Display *display = XOpenDisplay(NULL);
    if (!display) {
        fprintf(stderr, "XOpenDisplay failed\n");
        return 1;
    }

    XSetErrorHandler(on_x_error);

    int screen = DefaultScreen(display);
    int attrs[] = {
        GLX_RGBA,
        GLX_DOUBLEBUFFER,
        GLX_RED_SIZE, 8,
        GLX_GREEN_SIZE, 8,
        GLX_BLUE_SIZE, 8,
        GLX_DEPTH_SIZE, 24,
        None
    };

    XVisualInfo *vi = glXChooseVisual(display, screen, attrs);
    if (!vi) {
        fprintf(stderr, "glXChooseVisual failed\n");
        XCloseDisplay(display);
        return 2;
    }

    Colormap cmap = XCreateColormap(display, RootWindow(display, screen), vi->visual, AllocNone);

    XSetWindowAttributes swa;
    swa.colormap = cmap;
    swa.event_mask = ExposureMask | KeyPressMask | StructureNotifyMask;

    Window win = XCreateWindow(
        display,
        RootWindow(display, screen),
        50, 50,
        320, 240,
        0,
        vi->depth,
        InputOutput,
        vi->visual,
        CWColormap | CWEventMask,
        &swa
    );

    if (!win || x_error) {
        fprintf(stderr, "XCreateWindow failed\n");
        XCloseDisplay(display);
        return 3;
    }

    XStoreName(display, win, "GLX 32-bit Smoke Test");
    XMapWindow(display, win);

    GLXContext ctx = glXCreateContext(display, vi, NULL, True);
    if (!ctx) {
        fprintf(stderr, "glXCreateContext failed\n");
        XDestroyWindow(display, win);
        XCloseDisplay(display);
        return 4;
    }

    if (!glXMakeCurrent(display, win, ctx)) {
        fprintf(stderr, "glXMakeCurrent failed\n");
        glXDestroyContext(display, ctx);
        XDestroyWindow(display, win);
        XCloseDisplay(display);
        return 5;
    }

    const char *vendor = (const char *)glGetString(GL_VENDOR);
    const char *renderer = (const char *)glGetString(GL_RENDERER);
    const char *version = (const char *)glGetString(GL_VERSION);

    printf("GL_VENDOR=%s\n", vendor ? vendor : "(null)");
    printf("GL_RENDERER=%s\n", renderer ? renderer : "(null)");
    printf("GL_VERSION=%s\n", version ? version : "(null)");
    fflush(stdout);

    int running = 1;
    int frames = 0;
    while (running && frames < 180) {
        while (XPending(display)) {
            XEvent ev;
            XNextEvent(display, &ev);
            if (ev.type == KeyPress || ev.type == DestroyNotify) {
                running = 0;
            }
        }

        glViewport(0, 0, 320, 240);
        glClearColor(0.95f, 0.15f, 0.1f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glXSwapBuffers(display, win);
        usleep(16666);
        frames++;
    }

    glXMakeCurrent(display, None, NULL);
    glXDestroyContext(display, ctx);
    XDestroyWindow(display, win);
    XCloseDisplay(display);
    return 0;
}
