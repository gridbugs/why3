(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2020   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require AnyFunction.

(* Why3 assumption *)
Inductive mode :=
  | RNE : mode
  | RNA : mode
  | RTP : mode
  | RTN : mode
  | RTZ : mode.
Axiom mode_WhyType : WhyType mode.
Existing Instance mode_WhyType.

(* Why3 assumption *)
Definition to_nearest (m:mode) : Prop := (m = RNE) \/ (m = RNA).
