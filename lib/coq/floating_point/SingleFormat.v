(* This file is generated by Why3's Coq-realize driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.

Require Import floating_point.GenFloat.

(* Why3 goal *)
Definition single : Type.
exact (t 24 128).
Defined.


Global Instance single_WhyType : WhyType single.
Proof.
apply t_WhyType.
Qed.
