open Wstdlib

type value =
  | Vconstr of Expr.rsymbol * field list
  | Vtuple of value list
  | Vbigint of BigInt.t
  | Vint of int
  | Vbool of bool
  | Vvoid
  | Varray of value array
  | Vmatrix of value array array
  | Vref of value ref

and field = Fimmutable of value | Fmutable of value ref

exception CannotReduce (* internal failure *)

(* Uncaught WhyML exception *)
exception Raised of Ity.xsymbol * value option * Expr.rsymbol list

val value_of_term: Decl.known_map -> Term.term -> value

val term_of_value: value -> Term.term

(** interp [env] [mm] [rs] [vars] interprets the program function [rs] using the values in [vars] for parameters and global variables. *)
val interp: Env.env -> Pmodule.pmodule Mstr.t -> Expr.rsymbol -> value Ident.Mid.t
            -> value
