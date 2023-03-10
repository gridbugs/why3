(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import BuiltIn.
Require BuiltIn.
Require int.Int.
Require int.MinMax.
Require list.List.
Require list.Length.
Require list.Mem.
Require list.Append.

Axiom char : Type.
Parameter char_WhyType : WhyType char.
Existing Instance char_WhyType.

(* Why3 assumption *)
Definition word := Init.Datatypes.list char.

(* Why3 assumption *)
Inductive dist: Init.Datatypes.list char -> Init.Datatypes.list char ->
  Numbers.BinNums.Z -> Prop :=
  | dist_eps : dist Init.Datatypes.nil Init.Datatypes.nil 0%Z
  | dist_add_left :
      forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char)
        (n:Numbers.BinNums.Z),
      dist w1 w2 n -> forall (a:char),
      dist (Init.Datatypes.cons a w1) w2 (n + 1%Z)%Z
  | dist_add_right :
      forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char)
        (n:Numbers.BinNums.Z),
      dist w1 w2 n -> forall (a:char),
      dist w1 (Init.Datatypes.cons a w2) (n + 1%Z)%Z
  | dist_context :
      forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char)
        (n:Numbers.BinNums.Z),
      dist w1 w2 n -> forall (a:char),
      dist (Init.Datatypes.cons a w1) (Init.Datatypes.cons a w2) n.

(* Why3 assumption *)
Definition min_dist (w1:Init.Datatypes.list char)
    (w2:Init.Datatypes.list char) (n:Numbers.BinNums.Z) : Prop :=
  dist w1 w2 n /\ (forall (m:Numbers.BinNums.Z), dist w1 w2 m -> (n <= m)%Z).

(* Why3 assumption *)
Fixpoint last_char (a:char) (u:Init.Datatypes.list char) {struct u}: char :=
  match u with
  | Init.Datatypes.nil => a
  | Init.Datatypes.cons c u' => last_char c u'
  end.

(* Why3 assumption *)
Fixpoint but_last (a:char)
  (u:Init.Datatypes.list char) {struct u}: Init.Datatypes.list char :=
  match u with
  | Init.Datatypes.nil => Init.Datatypes.nil
  | Init.Datatypes.cons c u' => Init.Datatypes.cons a (but_last c u')
  end.

Axiom first_last_explicit :
  forall (u:Init.Datatypes.list char) (a:char),
  ((Init.Datatypes.app (but_last a u)
    (Init.Datatypes.cons (last_char a u) Init.Datatypes.nil))
   = (Init.Datatypes.cons a u)).

Axiom first_last :
  forall (a:char) (u:Init.Datatypes.list char),
  exists v:Init.Datatypes.list char, exists b:char,
  ((Init.Datatypes.app v (Init.Datatypes.cons b Init.Datatypes.nil)) =
   (Init.Datatypes.cons a u)) /\
  ((list.Length.length v) = (list.Length.length u)).

Axiom key_lemma_right :
  forall (w1:Init.Datatypes.list char) (w'2:Init.Datatypes.list char)
    (m:Numbers.BinNums.Z) (a:char),
  dist w1 w'2 m -> forall (w2:Init.Datatypes.list char),
  (w'2 = (Init.Datatypes.cons a w2)) ->
  exists u1:Init.Datatypes.list char, exists v1:Init.Datatypes.list char,
  exists k:Numbers.BinNums.Z,
  (w1 = (Init.Datatypes.app u1 v1)) /\
  dist v1 w2 k /\ ((k + (list.Length.length u1))%Z <= (m + 1%Z)%Z)%Z.

Axiom dist_symetry :
  forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char)
    (n:Numbers.BinNums.Z),
  dist w1 w2 n -> dist w2 w1 n.

Axiom key_lemma_left :
  forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char)
    (m:Numbers.BinNums.Z) (a:char),
  dist (Init.Datatypes.cons a w1) w2 m ->
  exists u2:Init.Datatypes.list char, exists v2:Init.Datatypes.list char,
  exists k:Numbers.BinNums.Z,
  (w2 = (Init.Datatypes.app u2 v2)) /\
  dist w1 v2 k /\ ((k + (list.Length.length u2))%Z <= (m + 1%Z)%Z)%Z.

Axiom dist_concat_left :
  forall (u:Init.Datatypes.list char) (v:Init.Datatypes.list char)
    (w:Init.Datatypes.list char) (n:Numbers.BinNums.Z),
  dist v w n ->
  dist (Init.Datatypes.app u v) w ((list.Length.length u) + n)%Z.

Axiom dist_concat_right :
  forall (u:Init.Datatypes.list char) (v:Init.Datatypes.list char)
    (w:Init.Datatypes.list char) (n:Numbers.BinNums.Z),
  dist v w n ->
  dist v (Init.Datatypes.app u w) ((list.Length.length u) + n)%Z.

Axiom min_dist_equal :
  forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char) 
    (a:char) (n:Numbers.BinNums.Z),
  min_dist w1 w2 n ->
  min_dist (Init.Datatypes.cons a w1) (Init.Datatypes.cons a w2) n.



(* Why3 goal *)
Theorem min_dist_diff :
  forall (w1:Init.Datatypes.list char) (w2:Init.Datatypes.list char) 
    (a:char) (b:char) (m:Numbers.BinNums.Z) (p:Numbers.BinNums.Z),
  ~ (a = b) -> min_dist (Init.Datatypes.cons a w1) w2 p ->
  min_dist w1 (Init.Datatypes.cons b w2) m ->
  min_dist (Init.Datatypes.cons a w1) (Init.Datatypes.cons b w2)
  ((ZArith.BinInt.Z.min m p) + 1%Z)%Z.
(* Why3 intros w1 w2 a b m p h1 h2 h3. *)
Proof.
intros w1 w2 a b m p.
unfold min_dist; intuition.
unfold Z.min.
case (m ?= p)%Z; generalize dist_add_left dist_add_right; intuition.
generalize (Z.le_min_l m p) (Z.le_min_r m p) Zplus_le_compat_r Z.le_trans.
inversion H1; intuition eauto.
Qed.

