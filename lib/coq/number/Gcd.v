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
Require int.Int.
Require int.Abs.
Require int.EuclideanDivision.
Require int.ComputerDivision.
Require number.Parity.
Require number.Divisibility.

Import Znumtheory.

(* Why3 goal *)
Notation gcd := Zgcd (only parsing).

(* Why3 goal *)
Lemma gcd_nonneg : forall (a:Z) (b:Z), (0%Z <= (gcd a b))%Z.
Proof.
exact Zgcd_is_pos.
Qed.

(* Why3 goal *)
Lemma gcd_def1 :
  forall (a:Z) (b:Z), (number.Divisibility.divides (gcd a b) a).
Proof.
intros a b.
apply Zgcd_is_gcd.
Qed.

(* Why3 goal *)
Lemma gcd_def2 :
  forall (a:Z) (b:Z), (number.Divisibility.divides (gcd a b) b).
Proof.
intros a b.
apply Zgcd_is_gcd.
Qed.

(* Why3 goal *)
Lemma gcd_def3 : forall (a:Z) (b:Z) (x:Z), (number.Divisibility.divides x
  a) -> ((number.Divisibility.divides x b) -> (number.Divisibility.divides x
  (gcd a b))).
Proof.
intros a b x.
apply Zgcd_is_gcd.
Qed.

(* Why3 goal *)
Lemma gcd_unique : forall (a:Z) (b:Z) (d:Z), (0%Z <= d)%Z ->
  ((number.Divisibility.divides d a) -> ((number.Divisibility.divides d b) ->
  ((forall (x:Z), (number.Divisibility.divides x a) ->
  ((number.Divisibility.divides x b) -> (number.Divisibility.divides x
  d))) -> (d = (gcd a b))))).
Proof.
intros.
apply sym_eq.
apply Zis_gcd_gcd.
exact H.
now constructor.
Qed.

(* Why3 goal *)
Lemma Assoc :
  forall (x:Z) (y:Z) (z:Z), ((gcd (gcd x y) z) = (gcd x (gcd y z))).
Proof.
exact Zgcd_ass.
Qed.

(* Why3 goal *)
Lemma Comm : forall (x:Z) (y:Z), ((gcd x y) = (gcd y x)).
Proof.
exact Zgcd_comm.
Qed.

(* Why3 goal *)
Lemma gcd_0_pos : forall (a:Z), (0%Z <= a)%Z -> ((gcd a 0%Z) = a).
Proof.
intros a H.
rewrite <- (Zabs_eq a H) at 2.
apply Zgcd_0.
Qed.

(* Why3 goal *)
Lemma gcd_0_neg : forall (a:Z), (a < 0%Z)%Z -> ((gcd a 0%Z) = (-a)%Z).
Proof.
intros a H.
rewrite <- Zabs_non_eq.
apply Zgcd_0.
now apply Zlt_le_weak.
Qed.

(* Why3 goal *)
Lemma gcd_opp : forall (a:Z) (b:Z), ((gcd a b) = (gcd (-a)%Z b)).
Proof.
intros a b.
apply Zis_gcd_gcd.
apply Zgcd_is_pos.
apply Zis_gcd_minus.
apply Zis_gcd_sym.
apply Zgcd_is_gcd.
Qed.

(* Why3 goal *)
Lemma gcd_euclid : forall (a:Z) (b:Z) (q:Z), ((gcd a b) = (gcd a
  (b - (q * a)%Z)%Z)).
Proof.
intros a b c.
apply Zis_gcd_gcd.
apply Zgcd_is_pos.
apply Zis_gcd_sym.
apply Zis_gcd_for_euclid with c.
apply Zgcd_is_gcd.
Qed.

(* Why3 goal *)
Lemma Gcd_computer_mod : forall (a:Z) (b:Z), (~ (b = 0%Z)) -> ((gcd b
  (ZArith.BinInt.Z.rem a b)) = (gcd a b)).
Proof.
intros a b _.
rewrite (Zgcd_comm a b).
rewrite (gcd_euclid b a (Z.quot a b)).
apply f_equal.
rewrite (Z.quot_rem' a b) at 2.
ring.
Qed.

(* Why3 goal *)
Lemma Gcd_euclidean_mod : forall (a:Z) (b:Z), (~ (b = 0%Z)) -> ((gcd b
  (int.EuclideanDivision.mod1 a b)) = (gcd a b)).
Proof.
intros a b Zb.
rewrite (Zgcd_comm a b).
rewrite (gcd_euclid b a (EuclideanDivision.div a b)).
apply f_equal.
rewrite (EuclideanDivision.Div_mod a b Zb) at 2.
ring.
Qed.

(* Why3 goal *)
Lemma gcd_mult : forall (a:Z) (b:Z) (c:Z), (0%Z <= c)%Z -> ((gcd (c * a)%Z
  (c * b)%Z) = (c * (gcd a b))%Z).
Proof.
intros a b c H.
apply Zis_gcd_gcd.
apply Zmult_le_0_compat with (1 := H).
apply Zgcd_is_pos.
apply Zis_gcd_mult.
apply Zgcd_is_gcd.
Qed.

