#lang racket/base
(provide  Cos  Sin  Tan   Sec  Csc  Tanh  Cot
         Acos Asin Atan  Asec Acsc Atanh 
          Cosh  Sinh
         Acosh Asinh
         Degree
         Ci Si Sinc)

;;;
;;; Trigonometry
;;; 

(require racket/list racket/match racket/math
         (only-in math/number-theory binomial)
         (prefix-in % "bfracket.rkt")
         (for-syntax racket/base racket/syntax syntax/parse)
         "core.rkt" "math-match.rkt" "runtime-paths.rkt")

(module+ test
  (require rackunit math/bigfloat)
  (define normalize (dynamic-require normalize.rkt            'normalize))
  (define N         (dynamic-require numerical-evaluation.rkt 'N))
  (define x 'x) (define y 'y) (define z 'z))

;;;
;;; Trigonometry
;;; 


; [0, 2)
(define (clamp-0-2 c)
  (let [(n (%numerator c)) (d (%denominator c))]
    (/ (modulo n (* 2 d)) d)))

; [-pi, pi), i.e [-1, 1)
; better be (-1, 1], but we can save the effort
; clamp-0-2(c + 1) - 1
(define (normalize-pi-coeff c)
  (- (clamp-0-2 (+ c 1)) 1))


(define sin-pi/2-table #(0 1 0 -1))
(define (sin-pi/2* n) (vector-ref sin-pi/2-table (remainder n 4)))
(define cos-pi/2-table #(1 0 -1 0))
(define (cos-pi/2* n) (vector-ref cos-pi/2-table (remainder n 4)))


(define (Cos: u)
  (when debugging? (displayln (list 'Cos: u)))
  (math-match u
    [0 1]
    [r.0 (cos r.0)]
    ; [r (cos r)] ; nope - automatic evaluation is for inexact results only
    [@pi -1]
    [(⊗ 1/3 @pi) 1/2]
    [(⊗ α u)   #:when (negative? α)      (Cos: (⊗ (- α) u))]  ; cos is even
    [(⊗ n @pi)                           (if (even? n) 1 -1)]    
    [(⊗ α @pi) #:when (integer? (* 2 α)) (cos-pi/2* (* 2 α))]
    [(⊗ α @pi) #:when (or (> α 1) (< α -1))
               (Cos (⊗ (normalize-pi-coeff α) @pi))]
    [(⊗ α @pi) #:when (> α 1/2) (⊖ (Cos (⊗ (- 1 α) @pi)))]
    [(⊗ α @pi) #:when (even? (%denominator α)) ; half angle formula
               (let ([sign (expt -1 (floor (/ (+ α 1) 2)))])
                 (⊗ sign (Sqrt (⊗ 1/2 (⊕ 1 (Cos (⊗ 2 α @pi)))))))] ; xxx test sign
    [(⊗ p (Integer _) @pi) #:when (even? p) 1]
    
    [(⊕ u (k⊗ p @pi)) #:when (odd? p)  (⊖ (Cos: u))]
    [(⊕ (k⊗ p @pi) u) #:when (odd? p)  (⊖ (Cos: u))]
    [(⊕ u (k⊗ p @pi)) #:when (even? p) (Cos: u)]
    [(⊕ (k⊗ p @pi) u) #:when (even? p) (Cos: u)]
    [(⊕ u (⊗ p (Integer _) @pi)) #:when (even? p) (Cos: u)]
    [(⊕ (⊗ p (Integer _) @pi) u) #:when (even? p) (Cos: u)]
    
    [(Acos u) u]    ; xxx only of -1<u<1
    [(Asin u) (Sqrt (⊖ 1 (Sqr u)))]
    [(Complex a b) #:when (not (zero? b)) (Cosh (⊗ @i u))]
    [(⊖ u) (Cos u)] ; even function    
    [_ `(cos ,u)]))

(define-match-expander Cos
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'cos u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Cos: u)] [_ (identifier? stx) #'Cos:])))

(module+ test
  (displayln "TEST - Cos")
  (check-equal? (Cos 0) 1)
  (check-equal? (Cos -3) (Cos 3))
  (check-equal? (Cos @pi) -1)
  (check-equal? (Cos (⊗ 2 @pi)) 1)
  (check-equal? (Cos 0.5) 0.8775825618903728)
  (check-equal? (for/list ([n 8]) (Cos (⊗ n 1/2 @pi))) '(1 0 -1 0 1 0 -1 0))
  (check-equal? (Cos (⊖ x)) (Cos x))
  (check-equal? (Cos (⊕ x (⊗ 2 @pi)))  (Cos x))
  (check-equal? (Cos (⊕ x (⊗ 4 @pi)))  (Cos x))
  (check-equal? (Cos (⊕ x (⊗ -4 @pi))) (Cos x))
  (check-equal? (Cos (⊕ x @pi))        (⊖ (Cos x)))
  (check-equal? (Cos (⊕ x (⊗ 3 @pi)))  (⊖ (Cos x)))
  (check-equal? (Cos (⊕ x (⊗ 2 @n @pi))) (Cos x))
  (check-equal? (Cos (⊕ x (⊗ 4 @n @pi))) (Cos x))
  (check-equal? (Cos (⊕ x (⊗ 2 @p @pi))) (Cos x))
  (check-equal? (Cos (⊗ 4/3 @pi)) -1/2)
  (check-equal? (Cos (Acos x)) 'x)
  (check-equal? (Cos (Asin x)) (Sqrt (⊖ 1 (Sqr 'x))))
  (check-equal? (Cos @i) (Cosh 1)))

(define (Sin: u)
  (when debugging? (displayln (list 'Sin: u)))
  (define (Odd? n)  (and (integer? n) (odd? n)))
  (define (Even? n) (and (integer? n) (even? n)))
  (math-match u
    [0 0]
    [r.0 (sin r.0)]
    [@pi 0]
    [(⊗ 1/3 @pi) (⊘ (Sqrt 3) 2)]
    [(⊗ (Integer _) @pi) 0]
    [(⊗ α     u) #:when (negative? α)      (⊖ (Sin: (⊗ (- α) u)))]
    [(⊗ α   @pi) #:when (integer? (* 2 α)) (if (= (remainder (* 2 α) 4) 1) 1 -1)]
    [(⊗ (Integer _) (Integer _) @pi) 0]
    [(⊕ u (k⊗ (Integer v) @pi)) #:when (Even? v) (Sin: u)]
    [(⊕ (k⊗ (Integer v) @pi) u) #:when (Even? v) (Sin: u)]
    [(⊕ u (k⊗ (Integer v) @pi)) #:when (Odd? v) (⊖ (Sin: u))]
    [(⊕ (k⊗ (Integer v) @pi) u) #:when (Odd? v) (⊖ (Sin: u))]
    [(⊕ u (⊗ p (Integer v) @pi)) #:when (Even? p) (Sin: u)]
    [(⊕ (⊗ p (Integer v) @pi) u) #:when (Even? p) (Sin: u)]
    [(⊕ u (⊗ p (Integer v) @pi)) #:when (Odd? p) (⊖ (Sin: u))]
    [(⊕ (⊗ p (Integer v) @pi) u) #:when (Odd? p) (⊖ (Sin: u))]
    [(⊗ α @pi) #:when (or (> α 1) (< α -1))
               (Sin (⊗ (normalize-pi-coeff α) @pi))]
    [(⊗ α @pi) #:when (> α 1/2) (Sin (⊗ (⊖ 1 α) @pi))]
    [(⊗ α @pi) #:when (even? (%denominator α)) ; half angle formula
               (let* ([θ      (* 2 α pi)]
                      [sign.0 (sgn (+ (- (* 2 pi) θ) (* 4 pi (floor (/ θ (* 4 pi))))))]
                      [sign   (if (> sign.0 0) 1 -1)])
                 (⊗ sign (Sqrt (⊗ 1/2 (⊖ 1 (Cos (⊗ 2 α @pi)))))))] ; xxx find sign
    [(Asin u) u] ; only if -1<=u<=1   Maxima and MMA: sin(asin(3))=3 Nspire: error
    [(Acos u) (Sqrt (⊖ 1 (Sqr u)))]
    [(Complex a b) #:when (not (zero? b)) (⊗ @i -1 (Sinh (⊗ @i u)))]
    [(⊖ u) (⊖ (Sin u))] ; odd function
    [_ `(sin ,u)]))

(define-match-expander Sin
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'sin u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Sin: u)] [_ (identifier? stx) #'Sin:])))

(module+ test 
  (displayln "TEST - Sin")
  (check-equal? (for/list ([n 8]) (Sin (⊗ n 1/2 @pi))) '(0 1 0 -1 0 1 0 -1))
  (check-equal? (Sin (⊖ x))              (⊖ (Sin x)))
  (check-equal? (Sin (⊕ x (⊗ 2 @pi)))       (Sin x))
  (check-equal? (Sin (⊕ x (⊗ 4 @pi)))       (Sin x))
  (check-equal? (Sin (⊕ x (⊗ -4 @pi)))      (Sin x))
  (check-equal? (Sin (⊕ x       @pi))    (⊖ (Sin x)))
  (check-equal? (Sin (⊕ x (⊗ 3 @pi)))    (⊖ (Sin x)))
  (check-equal? (Sin (⊕ x (⊗ 2 @n @pi)))    (Sin x))
  (check-equal? (Sin (⊕ x (⊗ 4 @n @pi)))    (Sin x))
  (check-equal? (Sin (⊕ x (⊗ 2 @p @pi)))    (Sin x))
  (check-equal? (Sin (⊗ 2/3 @pi)) '(* 1/2 (expt 3 1/2)))
  (check-equal? (Sin -3) (⊖ (Sin 3)))
  (check-equal? (Sin (Asin x)) 'x)
  (check-equal? (Sin (Acos x)) (Sqrt (⊖ 1 (Sqr x))))
  (check-equal? (Sin @i) (⊗ '@i (Sinh 1))) ; PR11 TODO
  )



(define (Asin: u)
  (when debugging? (displayln (list 'Asin: u)))
  (math-match u
    [0 0]
    [1  (⊗ 1/2 @pi)]
    [1/2 (⊗ 1/6 @pi)]
    [(list '* 1/2 (list 'expt 3 1/2))               (⊗ 1/3 @pi)]
    [(Expt 2 -1/2) (⊗ 1/4 @pi)]
    [(list '* 1/2 (list 'expt 2 1/2)) (⊗ 1/4 @pi)]
    [(⊖ u) (⊖ (Asin u))] ; odd function
    [r.0 (asin r.0)]
    [_ `(asin ,u)]))

(define-match-expander Asin
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'asin u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Asin: u)] [_ (identifier? stx) #'Asin:])))

; Acos = pi/2 - Asin
(define (Acos: u)
  (when debugging? (displayln (list 'Acos: u)))
  (math-match u
    [0 (⊘ @pi 2)]
    [1 0]
    [1/2 (⊗ 1/3 @pi)]
    [(list '* 1/2 (list 'expt 3 1/2))               (⊗ 1/6 @pi)]
    [(Expt 2 -1/2) (⊗ 1/4 @pi)]
    [(list '* 1/2 (list 'expt 2 1/2)) (⊗ 1/4 @pi)]
    [(⊖ u) (⊖ @pi (Acos u))]
    [r.0 (acos r.0)]
    [_ `(acos ,u)]))

(define-match-expander Acos
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'acos u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Acos: u)] [_ (identifier? stx) #'Acos:])))

(module+ test
  (displayln "TEST - Acos")
  (check-equal? (Acos -1/2) '(* 2/3 @pi))
  (check-equal? (Asin -1/2) '(* -1/6 @pi))
  (check-equal? (Acos '(* 1/2 (expt 3 1/2))) '(* 1/6 @pi))
  (check-equal? (Asin '(* 1/2 (expt 3 1/2))) '(* 1/3 @pi))
  (check-equal? (Asin (Sin '(* -1/3 @pi))) '(* -1/3 @pi))
  (check-equal? (Acos (Cos '(* -1/3 @pi))) '(* 1/3 @pi))
  (check-equal? (Asin (Sin '(* -1/6 @pi))) '(* -1/6 @pi))
  (check-equal? (Acos (Cos '(* -1/6 @pi))) '(* 1/6 @pi)))

(define (Atan: u)
  (when debugging? (displayln (list 'Atan: u)))
  (math-match u
    [r.0 (atan r.0)]
    [u   (Asin (⊘ u (Sqrt (⊕ 1 (Sqr u)))))]))

; Patterns involved with Atan should appear before Similar patterns with Asin to avoid being hijacked.

(define-match-expander Atan
  (λ (stx) (syntax-parse stx [(_ u) #'(or (list 'atan u) (Asin (⊘ u (Sqrt (⊕ 1 (Sqr u))))))]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Atan: u)] [_ (identifier? stx) #'Atan:])))


(define (Tan u)
  (⊘ (Sin u) (Cos u)))

(define (Cot u)
  (⊘ (Cos u) (Sin u)))

(define (Csc u)
  (⊘ 1 (Sin u)))

(define (Sec u)
  (⊘ 1 (Cos u)))


(define (Asec u)
  (Acos (⊘ 1 u)))

(define (Acsc u)
  (Asin (⊘ 1 u)))

(define (Tanh u)
  (⊘ (Sinh u) (Cosh u)))

(define (Atanh u)
  (⊗ 1/2 (⊕ (Ln (⊕ 1 u)) (Ln (⊖ 1 u)))))

(define (Asinh: u)
  (Ln (⊕ u (Sqrt (⊕ (Sqr u) 1)))))


(define-match-expander Asinh
  (λ (stx) (syntax-parse stx [(_ u) #'(or (list 'asinh u)
                                          (Ln (⊕ u (Sqrt (⊕ -1 (Sqr u)))))
                                          (Ln (⊕   (Sqrt (⊕ -1 (Sqr u))) u)))]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Asinh: u)] [_ (identifier? stx) #'Asinh:])))

(define (Acosh: u)
  (Ln (⊕ u (Sqrt (⊕ (Sqr u) -1)))))

(define-match-expander Acosh
  (λ (stx) (syntax-parse stx [(_ u) #'(or (list 'acosh u)
                                          (Ln (⊕ u (Sqrt (⊕ 1 (Sqr u)))))
                                          (Ln (⊕   (Sqrt (⊕ 1 (Sqr u))) u)))]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Acosh: u)] [_ (identifier? stx) #'Acosh:])))

(define (Sinc: u)
  (when debugging? (displayln (list 'Sinc: u)))
  (math-match u
    [0 1]
    [_ (⊘ (Sin u) u)]))

(define-match-expander Sinc
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'sinc u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Sinc: u)] [_ (identifier? stx) #'Sinc:])))

(define (Si: u)
  (when debugging? (displayln (list 'Si: u)))
  (math-match u
    [0 0]
    [_ `(si ,u)]))

(define-match-expander Si
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'si u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Si: u)] [_ (identifier? stx) #'Si:])))

(define (Ci: u)
  (when debugging? (displayln (list 'Ci: u)))
  (math-match u
    [0 0]
    [_ `(ci ,u)]))

(define-match-expander Ci
  (λ (stx) (syntax-parse stx [(_ u) #'(list 'ci u)]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Ci: u)] [_ (identifier? stx) #'Ci:])))



(define (Degree u)
  (⊗ (⊘ @pi 180) u))


;;;
;;; Hyperbolic
;;;


(define (Cosh: u)
  (when debugging? (displayln (list 'Cosh: u)))
  (math-match u
    [0                      1]
    [r.0                    (cosh r.0)]
    [α #:when (negative? α) (Cosh: (- α))]
    [(ImaginaryTerm u)      (Cos u)]
    [u                      (⊗ 1/2 (⊕ (Exp u) (Exp (⊖ u))))]))

(define (Sinh: u)
  (when debugging? (displayln (list 'Sinh: u)))
  (math-match u
    [0                       0]
    [r.0                     (sinh r.0)]
    [α #:when (negative? α)  (⊖ (Sinh: (- α)))]
    [(ImaginaryTerm u)       (⊗ @i (Sin u))]
    [u                       (⊗ 1/2 (⊖ (Exp u) (Exp (⊖ u))))]))


(define-match-expander Cosh
  (λ (stx) (syntax-parse stx [(_ u) #'(or (list 'cosh u) (⊗ 1/2 (⊕ (Exp (⊖ u)) (Exp u))))]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Cosh: u)] [_ (identifier? stx) #'Cosh:])))

(define-match-expander Sinh
  (λ (stx) (syntax-parse stx [(_ u) #'(or (list 'sinh u) (⊗ 1/2 (⊖ (Exp u) (Exp (⊖ u)))))]))
  (λ (stx) (syntax-parse stx [(_ u) #'(Sinh: u)] [_ (identifier? stx) #'Sinh:])))

(define (double u)
  (⊗ 2 u))


(define-match-expander 2⊗Cosh
  (λ (stx) (syntax-parse stx [(_ u) #'(⊕ (Exp (⊖ u)) (Exp u))])))
  
(define-match-expander 2⊗Sinh
  (λ (stx) (syntax-parse stx [(_ u) #'(⊖ (Exp u) (Exp (⊖ u)))])))

(module+ test
  (displayln "TEST - Cosh")
  (define subst  (dynamic-require simplify-expand.rkt 'subst))
  (check-equal? (N (subst (Cosh x) x 1)) (cosh 1))
  (check-equal? (N (subst (Sinh x) x 1)) (sinh 1))
  (check-equal? (match      (Sinh x)  [         (Sinh y)  y] [_ #f]) x)
  (check-equal? (match      (Sinh x)  [(⊗ 1/2 (2⊗Sinh y)) y] [_ #f]) x)
  (check-equal? (match      (Cosh x)  [(⊗ 1/2 (2⊗Cosh y)) y] [_ #f]) x)
  (check-equal? (match (⊗ 2 (Sinh x)) [       (2⊗Sinh u)  u] [_ #f]) x)
  (check-equal? (match (⊗ 2 (Cosh x)) [       (2⊗Cosh u)  u] [_ #f]) x))

