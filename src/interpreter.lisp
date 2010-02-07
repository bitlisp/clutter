(cl:in-package "COMMON-LISP")
(defpackage #:clutter
  (:use #:cl))
(in-package #:clutter)

;;;
;;; Environments
;;;

(defparameter *initial-env* '())
(defparameter *global-env* *initial-env*)
(defparameter *global-fenv* '())

(defun push-initial-binding (name value)
  (push (cons name value) *global-env*))

(defmacro definitial (name value)
  `(progn (push-initial-binding ',name ,value)
          ',name))

(defun push-initial-function-binding (name value)
  (push (cons name value) *global-fenv*))

(defmacro definitial-fun (name value)
  `(progn (push-initial-function-binding ',name ,value)
          ',name))

(defmacro defprimitive (name value arity)
  `(definitial-fun ,name (lambda (values)
                           (if (= ,arity (length values))
                               (apply ,value values)
                               (error "Incorrect arity.")))))

;;;
;;; Primitives
;;;

(defparameter *true* '|t|)
(defparameter *false* '|f|)

(definitial |t| *true*)
(definitial |f| *false*)
(definitial |nil| '())
(defprimitive |not| (lambda (x) (if (eq x *false*) *true* *false*)) 1)
(defprimitive |cons| #'cons 2)
(defprimitive |car| #'car 1)
(defprimitive |cdr| #'cdr 1)
(defprimitive |rplaca| #'rplaca 2)
(defprimitive |rplacd| #'rplacd 2)
(defprimitive |eq?| (lambda (x y) (if (eq x y) *true* *false*)) 2)
(defprimitive |eql?| (lambda (x y) (if (eql x y) *true* *false*)) 2)
(defprimitive |symbol?| (lambda (x) (if (symbolp x) *true* *false*)) 1)
(defprimitive |<| (lambda (x y) (if (< x y) *true* *false*)) 2)
(defprimitive |>| (lambda (x y) (if (> x y) *true* *false*)) 2)
(defprimitive |=| (lambda (x y) (if (= x y) *true* *false*)) 2)
(defprimitive |apply| #'invoke 2)
(definitial-fun |call| (lambda (args) (invoke (car args) (cdr args))))

;;;
;;; Evaluator
;;;

(defun eprogn (exps env fenv)
  (when exps
    (if (cdr exps)
        (progn (evaluate (car exps) env fenv)
               (eprogn (cdr exps) env fenv))
        (evaluate (car exps) env fenv))))

(defun eval-list (list env fenv)
  (mapcar (lambda (exp) (evaluate exp env fenv)) list))

(defun find-binding (id env)
  (or (assoc id env)
      (error "No such binding: ~S" id)))

(defun lookup (id env)
  (cdr (find-binding id env)))

(defun (setf lookup) (new-value id env)
  (setf (cdr (find-binding id env)) new-value))

(defun extend (env variables values)
  (cond ((consp variables)
         (if values
             (cons (cons (car variables) (car values))
                   (extend env (cdr variables) (cdr values)))
             (error "Not enough values")))
        ((null variables)
         (if values
             (error "Too many values")
             env))
        ((symbolp variables) (cons (cons variables values) env))))

(defun invoke (function args)
  (if (functionp function)
      (funcall function args)
      (error "Not a function: ~S" function)))

(defun make-function (variables body env fenv)
  (lambda (values)
    (eprogn body (extend env variables values) fenv)))

(defun evaluate-application (fn args fenv)
  (assert (symbolp fn))
  (funcall (lookup fn fenv) args))

(defun evaluate (exp env fenv)
  (if (atom exp)
      (typecase exp
        ((or number string character boolean vector) exp)
        (symbol (lookup exp env))
        (otherwise (error "Cannot evaluate: ~S" exp)))
      (case (car exp)
        (|quote| (cadr exp))
        (|if| (if (not (eq (evaluate (cadr exp) env fenv) *false*))
                  (evaluate (caddr exp) env fenv)
                  (evaluate (cadddr exp) env fenv)))
        (|do| (eprogn (cdr exp) env fenv))
        (|set!| (setf (lookup (cadr exp) env)
                      (evaluate (caddr exp) env fenv)))
        (|lambda| (make-function (cadr exp) (cddr exp) env fenv))
        (|function| (if (symbolp (cadr exp))
                        (lookup (cadr exp) fenv)
                        (error "No such function: ~A" (cadr exp))))
        (|flet| (eprogn (cddr exp) env (extend fenv (mapcar #'car (cadr exp))
                                               (mapcar (lambda (def)
                                                         (make-function (cadr def)
                                                                        (cddr def)
                                                                        env fenv))
                                                       (cadr exp)))))
          (otherwise (evaluate-application (car exp)
                                         (eval-list (cdr exp) env fenv)
                                         fenv)))))

(defun repl ()
  (let ((*readtable* (copy-readtable *readtable*)))
    (setf (readtable-case *readtable*) :preserve)
    (loop
      (princ "> ")
      (with-simple-restart (abort "Return to Clutter's toplevel")
        (prin1 (evaluate (read) *global-env* *global-fenv*)))
      (fresh-line))))
