(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require list.List.
Require list.Length.
Require list.Nth.
Require option.Option.
Require list.HdTl.

(* Why3 assumption *)
Definition zero_at (l:Init.Datatypes.list Numbers.BinNums.Z)
    (i:Numbers.BinNums.Z) : Prop :=
  ((list.Nth.nth i l) = (Init.Datatypes.Some 0%Z)) /\
  (forall (j:Numbers.BinNums.Z), (0%Z <= j)%Z /\ (j < i)%Z ->
   ~ ((list.Nth.nth j l) = (Init.Datatypes.Some 0%Z))).

(* Why3 assumption *)
Definition no_zero (l:Init.Datatypes.list Numbers.BinNums.Z) : Prop :=
  forall (j:Numbers.BinNums.Z),
  (0%Z <= j)%Z /\ (j < (list.Length.length l))%Z ->
  ~ ((list.Nth.nth j l) = (Init.Datatypes.Some 0%Z)).

(* Why3 assumption *)
Inductive ref (a:Type) :=
  | ref'mk : a -> ref a.
Axiom ref_WhyType : forall (a:Type) {a_WT:WhyType a}, WhyType (ref a).
Existing Instance ref_WhyType.
Arguments ref'mk {a}.

(* Why3 assumption *)
Definition contents {a:Type} {a_WT:WhyType a} (v:ref a) : a :=
  match v with
  | ref'mk x => x
  end.

Parameter if_term: Numbers.BinNums.Z -> Init.Datatypes.bool.

Axiom if_term'def :
  forall (o:Numbers.BinNums.Z),
  ((o = 0%Z) -> ((if_term o) = Init.Datatypes.true)) /\
  (~ (o = 0%Z) -> ((if_term o) = Init.Datatypes.false)).

Require Import Lia.

(* Why3 goal *)
Theorem search_loop'vc :
  forall (l:Init.Datatypes.list Numbers.BinNums.Z),
  forall (s:Init.Datatypes.list Numbers.BinNums.Z) (i:Numbers.BinNums.Z),
  (0%Z <= i)%Z /\
  ((i + (list.Length.length s))%Z = (list.Length.length l)) /\
  (forall (j:Numbers.BinNums.Z), (0%Z <= j)%Z ->
   ((list.Nth.nth j s) = (list.Nth.nth (i + j)%Z l))) /\
  (forall (j:Numbers.BinNums.Z), (0%Z <= j)%Z /\ (j < i)%Z ->
   ~ ((list.Nth.nth j l) = (Init.Datatypes.Some 0%Z))) ->
  list.List.is_nil s <-> (s = Init.Datatypes.nil) ->
  forall (o:Init.Datatypes.bool),
  ~ list.List.is_nil s /\
  (exists o1:Numbers.BinNums.Z,
   ((list.HdTl.hd s) = (Init.Datatypes.Some o1)) /\
   ((o1 = 0%Z) /\ (o = Init.Datatypes.false) \/
    ~ (o1 = 0%Z) /\ (o = Init.Datatypes.true))) \/
  list.List.is_nil s /\ (o = Init.Datatypes.false) ->
  (o = Init.Datatypes.true) -> forall (i1:Numbers.BinNums.Z),
  (i1 = (i + 1%Z)%Z) -> forall (o1:Init.Datatypes.list Numbers.BinNums.Z),
  ((list.HdTl.tl s) = (Init.Datatypes.Some o1)) ->
  forall (s1:Init.Datatypes.list Numbers.BinNums.Z), (s1 = o1) ->
  forall (j:Numbers.BinNums.Z), (0%Z <= j)%Z /\ (j < i1)%Z ->
  ~ ((list.Nth.nth j l) = (Init.Datatypes.Some 0%Z)).
(* Why3 intros l s i (h1,(h2,(h3,h4))) h5 o h6 h7 i1 h8 o1 h9 s1 h10 j
        (h11,h12). *)
Proof.
intros l s i (h1,(h2,(h3,h4))) h5 o h6 h7 i1 h8 o1 h9 s1 h10 j (h11,h12).
subst.
destruct s.
easy.
injection h9. clear h9.
intros ->.
assert (h: (j < i \/ j= i)%Z) by lia; destruct h as [h| ->].
now apply h4.
destruct h6 as [[_ [x [H5 [[_ H6]|[H6 _]]]]]|[H _]] ; try easy.
specialize (h3 0%Z (Z.le_refl 0)).
rewrite Zplus_0_r in h3.
rewrite <- h3.
simpl.
simpl in H5.
rewrite H5.
contradict H6.
now injection H6.
Qed.
