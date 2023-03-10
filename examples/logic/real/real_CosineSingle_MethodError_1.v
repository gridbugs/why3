(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require Reals.Rbasic_fun.
Require Reals.R_sqrt.
Require Reals.Rtrigo_def.
Require Reals.Rtrigo1.
Require Reals.Ratan.
Require BuiltIn.
Require real.Real.
Require real.Abs.
Require real.Square.
Require real.Trigonometry.

Require Import Interval.Tactic.

(* Why3 goal *)
Theorem MethodError :
  forall (x:Reals.Rdefinitions.R),
  ((Reals.Rbasic_fun.Rabs x) <= (1 / 32)%R)%R ->
  ((Reals.Rbasic_fun.Rabs
    ((1%R - ((1 / 2)%R * (x * x)%R)%R)%R - (Reals.Rtrigo_def.cos x))%R)
   <= (1 / 16777216)%R)%R.
Proof.
intros x h1.
interval with (i_autodiff x, i_bisect x).
Qed.
