(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2018   --   Inria - CNRS - Paris-Sud University  *)
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
Require list.List.

(* Why3 goal *)
Definition hd : forall {a:Type} {a_WT:WhyType a}, (list a) -> a.
intros a a_WT [|h _].
exact why_inhabitant.
exact h.
Defined.

(* Why3 goal *)
Lemma hd_cons : forall {a:Type} {a_WT:WhyType a}, forall (x:a) (r:(list a)),
  ((hd (Init.Datatypes.cons x r)) = x).
Proof.
now intros a a_WT x r.
Qed.

(* Why3 goal *)
Definition tl : forall {a:Type} {a_WT:WhyType a}, (list a) -> (list a).
intros a a_WT [|_ t].
exact nil.
exact t.
Defined.

(* Why3 goal *)
Lemma tl_cons : forall {a:Type} {a_WT:WhyType a}, forall (x:a) (r:(list a)),
  ((tl (Init.Datatypes.cons x r)) = r).
Proof.
now intros a a_WT x r.
Qed.

