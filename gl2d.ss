#lang scheme/gui

(require sgl
         sgl/gl
         sgl/gl-vectors)

(define (gl-draw-point x y)
  (gl-begin 'points)
  (gl-vertex x y)
  ;(gl-vertex (+ x 0.5) (+ y 0.5))
  (gl-end))

(define (gl-draw-line x1 y1 x2 y2)
  (gl-begin 'lines)
  (gl-vertex x1 y1)
  (gl-vertex x2 y2)
  (gl-end))

(define (gl-draw-rectangle mode w h)
  (gl-begin (case mode
              [(solid) 'quads]
              [(outline) 'line-loop]))
  (gl-vertex 0 0)
  (gl-vertex w 0)
  (gl-vertex w h)
  (gl-vertex 0 h)
  (gl-end))

(define (call-with-translate x y thnk)
  (dynamic-wind
   (lambda ()
     (gl-push-matrix)
     (gl-translate x y 0))
   thnk
   gl-pop-matrix))
(define-syntax-rule (with-translate x y e ...)
  (call-with-translate x y (lambda () e ...)))

(define (call-with-scale x y thnk)
  (dynamic-wind
   (lambda ()
     (gl-push-matrix)
     (gl-scale x y 0))
   thnk
   gl-pop-matrix))
(define-syntax-rule (with-scale x y e ...)
  (call-with-scale x y (lambda () e ...)))

(define (call-with-rotation angle thnk)
  (dynamic-wind
   (lambda ()
     (gl-push-matrix)
     (gl-rotate angle 0 0 1))
   thnk
   gl-pop-matrix))
(define-syntax-rule (with-rotation angle e ...)
  (call-with-rotation angle (lambda () e ...)))

(define (call-with-mirror w thnk)
  (with-translate w 0.0
    (with-scale -1.0 1.0
      (thnk))))
(define-syntax-rule (with-mirror width e ...)
  (call-with-mirror width (lambda () e ...)))

(define-syntax-rule (define-compile-time-vector i e)
  (begin
    (define-syntax (the-expander stx)
      (quasisyntax/loc stx
        (vector #,@e)))
    (define i (the-expander))))

(define-for-syntax circle-step 5)
(define-compile-time-vector circle-sins
  (for/list ([angle (in-range 0 360 circle-step)]) (sin angle)))
(define-compile-time-vector circle-coss
  (for/list ([angle (in-range 0 360 circle-step)]) (cos angle)))

(define (gl-draw-circle mode)
  (gl-begin (case mode
              [(solid) 'triangle-fan]
              [(outline) 'line-strip]))
  (when (symbol=? mode 'solid)
    (gl-vertex 0 0))
  (for ([s (in-vector circle-sins)]
        [c (in-vector circle-coss)])
    (gl-vertex s c))
  (gl-end))

(define (gl-viewport/restrict mw mh
                              vw vh 
                              cx cy)
  (define x1 (- cx (/ vw 2)))
  (define x2 (+ cx (/ vw 2)))
  (define y1 (- cy (/ vh 2)))
  (define y2 (+ cy (/ vh 2)))
  
  ; Don't go off the screen
  (define x1p (max 0.0 x1))
  (define x2p (min mw x2)) 
  (define y1p (max 0.0 y1))
  (define y2p (min mh y2))
  
  (gluOrtho2D 
   ; If x2 has gone off, then add more to the left
   (if (= x2 x2p)
       x1p
       (+ x1p (- x2p x2)))
   ; etc
   (if (= x1 x1p)
       x2p
       (+ x2p (- x1p x1)))
   (if (= y2 y2p)
       y1p
       (+ y1p (- y2p y2)))
   (if (= y1 y1p)
       y2p
       (+ y2p (- y1p y1)))))

(define (gl-init width height)
  (gl-viewport 0 0 width height)
  (gl-matrix-mode 'projection)
  (gl-load-identity)
  (gl-enable 'texture-2d)
  (gl-disable 'depth-test)
  (gl-disable 'lighting)
  (gl-disable 'dither)
  (gl-enable 'blend)
  (gl-matrix-mode 'modelview)
  (gl-load-identity)
  (glTexEnvf GL_TEXTURE_ENV GL_TEXTURE_ENV_MODE GL_MODULATE)
  #;(gl-translate 0.375 0.375 0))

(define mode/c
  (symbols 'solid 'outline))

(provide
 with-rotation
 with-scale
 with-translate
 with-mirror)
(provide/contract
 [mode/c contract?]
 [gl-viewport/restrict (real? real?
                              real? real?
                              real? real? . -> . void)]
 [gl-init (integer? integer? . -> . void)]
 [gl-draw-circle (mode/c . -> . void)]
 [call-with-rotation (real? (-> void) . -> . void)]
 [call-with-mirror (real? (-> void) . -> . void)]
 [call-with-scale (real? real? (-> void) . -> . void)]
 [call-with-translate (real? real? (-> void) . -> . void)]
 [gl-draw-rectangle (mode/c real? real? . -> . void)]
 [gl-draw-line (real? real? real? real? . -> . void)] 
 [gl-draw-point (real? real? . -> . void)])

;; Textures
;; Copied from sgl/bitmap.ss
(define (argb->rgba argb)
  (let* ((length (bytes-length argb))
         (rgba (make-gl-ubyte-vector length)))
    (let loop ((i 0))
      (when (< i length)
        (gl-vector-set! rgba (+ i 0) (bytes-ref argb (+ i 1)))
        (gl-vector-set! rgba (+ i 1) (bytes-ref argb (+ i 2)))
        (gl-vector-set! rgba (+ i 2) (bytes-ref argb (+ i 3)))
        (gl-vector-set! rgba (+ i 3) (bytes-ref argb (+ i 0)))
        (loop (+ i 4))))
    rgba))

(define (bitmap->argb bmp bmp-mask)
  (let* ((width (send bmp get-width))
         (height (send bmp get-height))
         (argb (make-bytes (* 4 width height) 255)))
    (send bmp get-argb-pixels 0 0 width height argb #f)
    (when bmp-mask
      (send bmp-mask get-argb-pixels 0 0 width height argb #t))
    argb))

(define-struct gl-texture (width height ref) #:mutable)
(define (valid-gl-texture? v)
  (and (gl-texture? v) (gl-texture-ref v)))
(define (gl-load-texture file)
  (define bm (make-object bitmap% file 'png/mask #f))
  (define mask (send bm get-loaded-mask))
  (define w (send bm get-width))
  (define h (send bm get-height))
  (define rgba (argb->rgba (bitmap->argb bm mask)))
  
  (define texts (glGenTextures 1))
  (define text-ref (gl-vector-ref texts 0))
  
  (glBindTexture GL_TEXTURE_2D text-ref)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MIN_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_MAG_FILTER GL_LINEAR)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_S GL_CLAMP)
  (glTexParameteri GL_TEXTURE_2D GL_TEXTURE_WRAP_T GL_CLAMP)
  (glTexImage2D GL_TEXTURE_2D 0 GL_RGBA w h 0
                GL_RGBA GL_UNSIGNED_BYTE rgba)
  
  (make-gl-texture w h texts))
(define (gl-bind-texture text)
  (glBindTexture GL_TEXTURE_2D (gl-vector-ref (gl-texture-ref text) 0)))
(define (gl-draw-rectangle/texture w h)
  (gl-draw-rectangle/texture-part 0 0 1 1 w h))
(define (gl-draw-rectangle/texture-part tx1 ty1 tw th w h)
  (glBlendFunc GL_SRC_ALPHA GL_ONE_MINUS_SRC_ALPHA)
  (gl-begin 'quads)
  (gl-tex-coord tx1 (+ ty1 th)) (gl-vertex 0 0)
  (gl-tex-coord (+ tx1 tw) (+ ty1 th)) (gl-vertex w 0) 
  (gl-tex-coord (+ tx1 tw) ty1) (gl-vertex w h)
  (gl-tex-coord tx1 ty1) (gl-vertex 0 h)
  (gl-end)
  (glBlendFunc GL_ONE GL_ZERO))
(define (gl-free-texture text)
  (glDeleteTextures (gl-texture-ref text))
  (set-gl-texture-ref! text #f))

(provide/contract
 [gl-texture? (any/c . -> . boolean?)]
 [gl-texture-width (gl-texture? . -> . exact-nonnegative-integer?)]
 [gl-texture-height (gl-texture? . -> . exact-nonnegative-integer?)]
 [valid-gl-texture? (any/c . -> . boolean?)]
 [gl-load-texture (path-string? . -> . valid-gl-texture?)]
 [gl-bind-texture (valid-gl-texture? . -> . void)]
 [gl-draw-rectangle/texture (real? real? . -> . void)]
 [gl-draw-rectangle/texture-part ((real-in 0 1) (real-in 0 1) (real-in 0 1) (real-in 0 1) real? real? . -> . void)]
 [gl-free-texture (valid-gl-texture? . -> . void)])
