#lang scribble/manual
@(require (for-label scheme/base
                     scheme/gui
                     scheme/contract
                     "main.ss"))

@title{OpenGL 2D Graphics}
@author{@(author+email "Jay McCarthy" "jay@plt-scheme.org")}

This package provides convenience routines for 2D graphics with OpenGL.

@defmodule[(planet jaymccarthy/gl2d)]

@defproc[(gl-init [width integer?] [height integer?])
         void]

Initializes the GL canvas to be @scheme[width] wide and @scheme[height] tall (in pixels).

@defproc[(gl-viewport/restrict [mw real?] [mh real?]
                  [vw real?] [vh real?] 
                  [cx real?] [cy real?])
         void]

Initializes the GL canvas with a @scheme[vw] by @scheme[vh] viewport centered around (@scheme[cx],@scheme[cy]) where the maximum area in the scene is @scheme[mw] by @scheme[mh]. All real values are not necessarily pixels.

@defproc[(gl-draw-point [x real?] [y real?])
         void]
@defproc[(gl-draw-line [x1 real?] [y1 real?]
                       [x2 real?] [y2 real?])
         void]

The obvious operations.

@defthing[mode/c contract?]

Equivalent to @scheme[(symbols 'solid 'outline)]

@defproc[(gl-draw-circle [mode mode/c])
         void]

Draws an approximation of the unit circle. Use @scheme[call-with-scale] for a different radius and @scheme[call-with-translate] for a different center.

@defproc[(gl-draw-rectangle [mode mode/c] [w real?] [h real?])
         void]

Draws a rectangle. Use @scheme[call-with-translate] for a different corner.

@defproc[(call-with-rotation [degrees real?] [thnk (-> void)]) void]
@defproc[(call-with-mirror [figure-width real?] [thnk (-> void)]) void]
@defproc[(call-with-scale [x real?] [y real?] [thnk (-> void)]) void]
@defproc[(call-with-translate [x real?] [y real?] [thnk (-> void)]) void]

Render with a transformation matrix.

@defform[(with-rotation degrees e ...)]
@defform[(with-mirror figure-width e ...)]
@defform[(with-scale x y e ...)]
@defform[(with-translate x y e ...)]

Syntax versions of the above.

@section{Textures}

@defproc[(gl-texture? [v any/c]) boolean?]

Tests texture-ness.

@defproc[(valid-gl-texture? [v any/c]) boolean?]

Only true if texture has not been freed.

@defproc[(gl-texture-width [tex gl-texture?]) exact-nonnegative-integer?]
@defproc[(gl-texture-height [tex gl-texture?]) exact-nonnegative-integer?]

Accessors

@defproc[(gl-load-texture [pth path-string?]) valid-gl-texture?]

Loads a PNG with an alpha mask as a texture.

@defproc[(gl-bind-texture [tex valid-gl-texture?]) void]

Binds a texture for subsequent rendering.

@defproc[(gl-draw-rectangle/texture [w real?] [h real?]) void]

Renders the currently bound texture on a rectangle.

@defproc[(gl-draw-rectangle/texture-part [tx (real-in 0 1)] [ty (real-in 0 1)]
                                         [tw (real-in 0 1)] [th (real-in 0 1)]
                                         [w real?] [h real?])
         void]

Renders part of the currently bound texture on a rectangle. (The texture is normalized to a 1x1 square.)

@defproc[(gl-free-texture [tex valid-gl-texture?]) void]

Frees a texture. It is no longer a @scheme[valid-gl-texture?].
