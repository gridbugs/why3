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
Require HighOrd.
Require AnyFunction.
Require int.Int.
Require set.Set.
Require map.Map.
Require map.Const.

(* Why3 goal *)
Definition is_finite {a:Type} {a_WT:WhyType a} :
  (a -> Init.Datatypes.bool) -> Prop.
Proof.
intros f.
(* Weak Finite Sets seems difficult to use here because they are defined as a
   functor which takes the type as argument. For the type a here, we would need
   to define the module during proof (or inside section) which is not possible.
   When it becomes possible, it would be much better to use Weak Finite Sets.
*)
(* We take a list to represent sets because it is simple and convenient.
   This is naive though and could easily be improved. The list is supposed to have
   no duplication (for cardinal). *)
exact (exists l: List.list a, List.NoDup l /\ forall e, List.In e l <-> f e = true).
Defined.

(* Why3 goal *)
Lemma is_finite_empty {a:Type} {a_WT:WhyType a} :
  forall (s:a -> Init.Datatypes.bool), set.Set.is_empty s -> is_finite s.
Proof.
intros s h1.
exists List.nil.
split. constructor.
split; intros Hemp.
+ destruct Hemp.
+ destruct (h1 e Hemp).
Qed.

(* Why3 goal *)
Lemma is_finite_subset {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s2 -> set.Set.subset s1 s2 -> is_finite s1.
Proof.
intros s1 s2 h1 h2.
destruct h1 as [l2 [Hdup h1]].
revert s1 s2 h1 h2.
(* The idea is to build the new list by induction. Two cases exists: the new element of s2
   is in s1 too or not *)
induction l2; intros.
+ exists nil.
  split; [|split].
  - constructor.
  - eauto.
  - intros. eapply h2 in H. eapply h1. assumption.
+ destruct (List.in_dec why_decidable_eq a0 l2).
  - eapply IHl2; eauto. { inversion Hdup; eauto. }
    split; intros.
    * destruct (why_decidable_eq a0 e).
      ++ eapply h1. left. auto.
      ++ eapply h1; eauto. right. eauto.
    * destruct (h1 e). destruct H1; eauto. subst. assumption.
  - assert (Hdup2: List.NoDup l2). { inversion Hdup; eauto. }
    destruct (Bool.bool_dec (s1 a0) true).
    * destruct (IHl2 Hdup2 (fun x => if why_decidable_eq x a0 then false else s1 x)
                           (fun x => if why_decidable_eq x a0 then false else s2 x)).
      ++ intros. split; intros. destruct why_decidable_eq; eauto. subst. intuition.
         eapply h1. right. assumption.
         destruct why_decidable_eq; eauto. inversion H. eapply h1 in H. destruct H. destruct n0; auto. assumption.
      ++ intros x H1. unfold set.Set.mem in *. destruct why_decidable_eq. auto. eapply h2. apply H1.
      ++ exists (List.cons a0 x). split; [| split]; intros.
         -- destruct H. constructor; [| eauto]. intro Habs. eapply H0 in Habs.
            destruct why_decidable_eq. inversion Habs. auto.
         -- destruct H0; try subst; eauto. eapply H in H0. destruct why_decidable_eq; eauto.
            inversion H0.
         -- destruct H as [Hdup3 H]. specialize (H e0). destruct why_decidable_eq. left. auto. right. eapply H. assumption.
    * destruct (IHl2 Hdup2 s1 (fun x => if why_decidable_eq x a0 then false else s2 x)).
      ++ split; intros. destruct why_decidable_eq. subst. intuition. eapply h1. right. assumption.
         destruct why_decidable_eq. inversion H. eapply h1 in H. destruct H; try subst; intuition.
      ++ intros e H. unfold set.Set.mem in *. destruct why_decidable_eq. subst.
         intuition.
         eapply h2. eapply H.
      ++ exists x. auto.
Qed.

(* Why3 goal *)
Lemma is_finite_add {a:Type} {a_WT:WhyType a} :
  forall (x:a) (s:a -> Init.Datatypes.bool), is_finite s ->
  is_finite (map.Map.set s x Init.Datatypes.true).
Proof.
intros x s h1.
destruct h1 as [l1 [Hdup h1]].
destruct (List.in_dec why_decidable_eq x l1).
- exists l1. split; eauto. intros. unfold Map.set. destruct why_decidable_eq.
  subst. intuition. apply h1.
- exists (List.cons x l1).
  split; [| split]; intros.
  + constructor; eauto.
  + destruct H. eapply Map.set'def; eauto.
    eapply h1 in H. unfold Map.set. destruct why_decidable_eq; eauto.
  + unfold Map.set in *. destruct why_decidable_eq. left. auto.
    right. eapply h1; eauto.
Qed.

(* Why3 goal *)
Lemma is_finite_add_rev {a:Type} {a_WT:WhyType a} :
  forall (x:a) (s:a -> Init.Datatypes.bool),
  is_finite (map.Map.set s x Init.Datatypes.true) -> is_finite s.
Proof.
intros x s h1.
eapply is_finite_subset; eauto.
intros e H. unfold Map.set, set.Set.mem in *. destruct why_decidable_eq; eauto.
Qed.

(* Why3 goal *)
Lemma is_finite_singleton {a:Type} {a_WT:WhyType a} :
  forall (x:a),
  is_finite
  (map.Map.set
   (map.Const.const Init.Datatypes.false : a -> Init.Datatypes.bool) x
   Init.Datatypes.true).
Proof.
intros x.
exists (List.cons x List.nil).
unfold Map.set.
split; [|split]; intros.
+ constructor. intro Habs. inversion Habs. constructor.
+ destruct why_decidable_eq; intuition.
  destruct H as [Hsubst | []]. subst. destruct n; reflexivity.
+ destruct why_decidable_eq; intuition.
  left. assumption.
  inversion H.
Qed.

(* Why3 goal *)
Lemma is_finite_remove {a:Type} {a_WT:WhyType a} :
  forall (x:a) (s:a -> Init.Datatypes.bool), is_finite s ->
  is_finite (map.Map.set s x Init.Datatypes.false).
Proof.
intros x s h1.
eapply is_finite_subset; eauto.
eapply set.Set.subset_remove.
Qed.

(* Why3 goal *)
Lemma is_finite_remove_rev {a:Type} {a_WT:WhyType a} :
  forall (x:a) (s:a -> Init.Datatypes.bool),
  is_finite (map.Map.set s x Init.Datatypes.false) -> is_finite s.
Proof.
intros x s h1.
destruct h1 as [l1 [Hdup h1]].
destruct (Bool.bool_dec (s x) true) as [Heq | Heq].
+ exists (List.cons x l1).
  split.
  - constructor; auto. intro Habs. eapply h1 in Habs. unfold Map.set in Habs.
    destruct why_decidable_eq; intuition.
  - unfold Map.set in h1. intros. specialize (h1 e). destruct why_decidable_eq; [| intuition]. subst.
    split; intuition. destruct H1; eauto.
+ exists l1.
  split; [auto|]. intros. specialize (h1 e). replace (Map.set s x false e) with (s e) in h1.
  eauto.
  unfold Map.set. destruct why_decidable_eq. subst. destruct (s e); intuition.
  reflexivity.
Qed.

(* Unnecessary lemma *)
Lemma NoDup_exists: forall {A} (eq_dec: forall x y: A, {x = y} + {x <> y}) P (Pdec: forall e, {P e} + {~ P e}) (l: List.list A),
  exists l1, List.NoDup l1 /\ forall e, List.In e l1 <-> (List.In e l /\ P e).
Proof.
induction l.
- exists List.nil. split. constructor. intros. intuition. inversion H.
- destruct IHl. destruct H.
  destruct (List.in_dec eq_dec a l).
  + exists x. split; eauto. intros. rewrite H0.
    split; intuition. inversion H2; eauto. subst. assumption.
  + destruct (Pdec a).
    ++ exists (List.cons a x). split. constructor; eauto.
       rewrite H0. intro Habs. destruct Habs; eauto.
       intros. simpl. rewrite H0. intuition. subst. assumption.
    ++ exists x. split; eauto. intros. rewrite H0. intuition. simpl in H2. destruct H2; try subst; intuition.
Qed.

(* Why3 goal *)
Lemma is_finite_union {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s1 -> is_finite s2 -> is_finite (set.Set.union s1 s2).
Proof.
intros s1 s2 h1 h2.
destruct h1 as [l1 [Hdup1 h1]].
destruct h2 as [l2 [Hdup2 h2]].

assert (exists l, List.NoDup l /\
  forall x, List.In x l <-> List.In x (List.app l1 l2) /\ True).
{ eapply NoDup_exists. eapply why_decidable_eq. eauto. }
destruct H as [l [Hdup H]].
exists l.
split; eauto.
intros. generalize (List.in_app_iff l1 l2 e); intros.
rewrite H. clear H. unfold set.Set.union. rewrite Bool.orb_true_iff.
rewrite H0.
transitivity (List.In e l1 \/ s2 e = true). rewrite or_iff_compat_l; eauto. intuition.
rewrite or_iff_compat_r; eauto. reflexivity.
Qed.

(* Why3 goal *)
Lemma is_finite_union_rev {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite (set.Set.union s1 s2) -> is_finite s1 /\ is_finite s2.
Proof.
intros s1 s2 h1.
split; eapply is_finite_subset; eauto.
+ apply set.Set.subset_union_1.
+ apply set.Set.subset_union_2.
Qed.

(* Why3 goal *)
Lemma is_finite_inter_left {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s1 -> is_finite (set.Set.inter s1 s2).
Proof.
intros s1 s2 h1.
eapply is_finite_subset; eauto.
eapply set.Set.subset_inter_1.
Qed.

(* Why3 goal *)
Lemma is_finite_inter_right {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s2 -> is_finite (set.Set.inter s1 s2).
Proof.
intros s1 s2 h1.
eapply is_finite_subset; eauto.
eapply set.Set.subset_inter_2.
Qed.

(* Why3 goal *)
Lemma is_finite_diff {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s1 -> is_finite (set.Set.diff s1 s2).
Proof.
intros s1 s2 h1.
eapply is_finite_subset; eauto.
eapply set.Set.subset_diff.
Qed.

(* Why3 goal *)
Lemma is_finite_map {a:Type} {a_WT:WhyType a} {b:Type} {b_WT:WhyType b} :
  forall (f:a -> b) (s:a -> Init.Datatypes.bool), is_finite s ->
  is_finite (set.Set.map f s).
Proof.
intros f s h1.
destruct h1 as [l1 [Hdup1 h1]].
assert (exists l, List.NoDup l /\
          forall e, List.In e l <-> List.In e (List.map f l1) /\ True).
{ eapply NoDup_exists. eapply why_decidable_eq. eauto. }
destruct H as [l [Hdupl H]].
exists l.
split.
- assumption.
- intros. rewrite (set.Set.map'def f s e).
  rewrite H.
  rewrite (List.in_map_iff f l1 e).
  split; intros. destruct H0. destruct H0.
  rewrite h1 in H0. exists x. intuition.
  destruct H0.
  split.
  exists x. rewrite h1. intuition.
  constructor.
Qed.

(* Why3 goal *)
Definition cardinal {a:Type} {a_WT:WhyType a} :
  (a -> Init.Datatypes.bool) -> Numbers.BinNums.Z.
Proof.
intros f.
(* There are no algorithms that decide at some point that the set is infinite *)
destruct (ClassicalEpsilon.excluded_middle_informative (is_finite f)).
+ (* Case when the set is finite. Take the length of a list with No duplication *)
  unfold is_finite in i.
  assert (Hdef: {l : list a | is_finite f -> List.NoDup l /\
                    (forall e : a, List.In e l <-> f e = true)}).
  eapply (ClassicalEpsilon.classical_indefinite_description).
  constructor. apply List.nil.
  destruct Hdef as (l, Hdef).
  apply (Z.of_nat (List.length l)).
+ (* Case when set is infinite: default value = 0 *)
  apply Z.zero.
Defined.

(* Why3 goal *)
Lemma cardinal_nonneg {a:Type} {a_WT:WhyType a} :
  forall (s:a -> Init.Datatypes.bool), (0%Z <= (cardinal s))%Z.
Proof.
intros s.
unfold cardinal. destruct ClassicalEpsilon.excluded_middle_informative.
destruct ClassicalEpsilon.classical_indefinite_description.
omega.
reflexivity.
Qed.

(* Why3 goal *)
Lemma cardinal_empty {a:Type} {a_WT:WhyType a} :
  forall (s:a -> Init.Datatypes.bool), is_finite s ->
  set.Set.is_empty s <-> ((cardinal s) = 0%Z).
Proof.
intros s h1.
unfold cardinal. assert (Hsav := h1). destruct h1.
destruct ClassicalEpsilon.excluded_middle_informative as [Hfin | Hnfin].
- destruct ClassicalEpsilon.classical_indefinite_description as (l, Hex).
  specialize (Hex Hfin).
  split; intros.
  * unfold set.Set.is_empty, set.Set.mem in H0.
    destruct l.
    + reflexivity.
    + destruct (H0 a0). eapply Hex. left. reflexivity.
  * unfold set.Set.is_empty, set.Set.mem. intros e Habs. eapply Hex in Habs.
    destruct l. destruct Habs. inversion H0.
- intuition.
Qed.

(* Why3 goal *)
Lemma cardinal_add {a:Type} {a_WT:WhyType a} :
  forall (x:a), forall (s:a -> Init.Datatypes.bool), is_finite s ->
  (set.Set.mem x s ->
   ((cardinal (map.Map.set s x Init.Datatypes.true)) = (cardinal s))) /\
  (~ set.Set.mem x s ->
   ((cardinal (map.Map.set s x Init.Datatypes.true)) =
    ((cardinal s) + 1%Z)%Z)).
Proof.
intros x s h1.
split; intros.
- rewrite <- (set.Set.extensionality s (Map.set s x true)). reflexivity. intro.
  unfold set.Set.mem, Map.set in *. destruct why_decidable_eq; try subst; intuition.
- assert (is_finite (Map.set s x true)). { apply is_finite_add. assumption. }
  unfold cardinal.
  destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
  destruct ClassicalEpsilon.classical_indefinite_description.
  destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
  destruct ClassicalEpsilon.classical_indefinite_description.
  specialize (a0 H0). specialize (a1 h1).
  assert (Hnat: length x0 = S (length x1)).
  { (* Here we base the proof on the fact that the first list where one cons x is the
       same length as the second one because they have the same elements and NoDup. *)
    assert (List.NoDup (List.cons x x1)).
    { constructor. intro Habs. apply H. eapply a1 in Habs. assumption. apply a1. }
    assert (forall e, List.In e (x :: x1) <-> List.In e x0).
    {
      intros. simpl. destruct a0 as (Hdupx0, Heq0). rewrite Heq0. destruct a1 as (Hdupx1, Heq1).
      rewrite Heq1. unfold Map.set. destruct why_decidable_eq; intuition.
    }
    assert (length x0 <= length (List.cons x x1) /\ (length (List.cons x x1) <= length x0)).
    {
      split.
      + eapply List.NoDup_incl_length; eauto. apply a0. intros e Hincl. eapply H2. assumption.
      + eapply List.NoDup_incl_length; eauto. intros e Hincl. eapply H2. assumption.
    }
    intuition.
  }
  rewrite Hnat. rewrite Nat2Z.inj_succ. ring.
Qed.

(* Why3 goal *)
Lemma cardinal_remove {a:Type} {a_WT:WhyType a} :
  forall (x:a), forall (s:a -> Init.Datatypes.bool), is_finite s ->
  (set.Set.mem x s ->
   ((cardinal (map.Map.set s x Init.Datatypes.false)) =
    ((cardinal s) - 1%Z)%Z)) /\
  (~ set.Set.mem x s ->
   ((cardinal (map.Map.set s x Init.Datatypes.false)) = (cardinal s))).
Proof.
intros x s h1.
split.
- intros.
  pose (s' := Map.set s x false).
  fold s'.
  assert (Map.set s' x true = s).
  {
    apply set.Set.extensionality. intro e.
    unfold s', set.Set.mem. unfold Map.set. destruct why_decidable_eq. subst. intuition.
    intuition.
  }
  rewrite <- H0.
  assert (~ set.Set.mem x s').
  { unfold s'. unfold Map.set, set.Set.mem.
    destruct why_decidable_eq; intuition.
  }
  eapply cardinal_add in H1. rewrite H1. ring.
  unfold s'. eapply is_finite_remove. assumption.
- intros.
  assert (Map.set s x false = s).
  {
    apply set.Set.extensionality. intro. unfold Map.set, set.Set.mem.
    destruct why_decidable_eq; intuition. subst. eauto.
  }
  rewrite H0. reflexivity.
Qed.

(* Why3 goal *)
Lemma cardinal_subset {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s2 -> set.Set.subset s1 s2 -> ((cardinal s1) <= (cardinal s2))%Z.
Proof.
intros s1 s2 h1 h2.
assert (is_finite s1).
{
  eapply is_finite_subset; eauto.
}
(* Remove ClassicalEpsilon noise *)
unfold cardinal.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 H). specialize (a1 h1).
destruct a0 as [Hdupx Heqx]. destruct a1 as [Hdupx0 Heqx0].
(* Same goal without ClassicalEpsilon indirection *)
assert (List.length x <= List.length x0).
{
  eapply List.NoDup_incl_length; eauto.
  intros e H1.
  eapply Heqx0. eapply Heqx in H1. unfold set.Set.subset, set.Set.mem in h2. eapply h2 in H1. assumption.
}
omega.
Qed.

(* Why3 goal *)
Lemma subset_eq {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s2 -> set.Set.subset s1 s2 -> ((cardinal s1) = (cardinal s2)) ->
  (s1 = s2).
Proof.
intros s1 s2 h1 h2 h3.
assert (is_finite s1).
{
  eapply is_finite_subset; eauto.
}
unfold cardinal in h3.
(* Remove classical epsilon noise *)
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 H). specialize (a1 h1).
rename x into l1.
rename x0 into l2.
destruct a0 as [Hdup1 Heq1].
destruct a1 as [Hdup2 Heq2].
assert (List.incl l1 l2).
{
  intros e H1. eapply Heq2. eapply h2. eapply Heq1. assumption.
}
eapply set.Set.extensionality. intro.
unfold set.Set.mem.
unfold set.Set.subset in h2.
rewrite <- Heq2, <- Heq1.
assert (List.length l1 = List.length l2).
{
  omega.
}
split. eauto.
eapply List.NoDup_length_incl; eauto. omega.
Qed.

(* Why3 goal *)
Lemma cardinal1 {a:Type} {a_WT:WhyType a} :
  forall (s:a -> Init.Datatypes.bool), ((cardinal s) = 1%Z) -> forall (x:a),
  set.Set.mem x s -> (x = (set.Set.pick s)).
Proof.
intros s h1 x h2.
unfold cardinal in *.
destruct ClassicalEpsilon.excluded_middle_informative.
* destruct ClassicalEpsilon.classical_indefinite_description.
  specialize (a0 i).
  assert (H: ~ set.Set.is_empty s). { unfold set.Set.is_empty. intro. eapply H. eassumption. }
  specialize (set.Set.pick_def s H). intros. unfold set.Set.mem in *.
  destruct x0.
  + inversion h1.
  + destruct x0.
    - simpl in a0. eapply a0 in h2. eapply a0 in H0. intuition. subst. reflexivity.
    - simpl in h1; contradict h1; zify; omega.
* inversion h1.
Qed.

Lemma length_prop: forall {A} (eq_dec: forall x y: A, {x = y} + {x <> y}) lu li (lui: List.list A),
  List.NoDup lu -> List.NoDup li -> List.NoDup lui ->
  List.incl li lu -> (forall e, List.In e lui <-> List.In e lu /\ not (List.In e li)) ->
  List.length lui = List.length lu - List.length li.
Proof.
induction lu; intros.
+ assert (lui = List.nil). destruct lui; eauto. specialize (H3 a); eauto. intuition. destruct H4.
  left. reflexivity. destruct H4.
  subst. reflexivity.
+ destruct (List.in_dec eq_dec a li).
  * destruct (List.in_split a li i) as [li' [li'' Hlieq]].
    assert (List.length lui = List.length lu - List.length (List.app li' li'')).
    {
      eapply IHlu; eauto.
      - inversion H; eauto.
      - rewrite Hlieq in H0. eapply List.NoDup_remove_1; eauto.
      - intro. intros. specialize (H2 a0). rewrite Hlieq in H2.
        simpl in H2. rewrite List.in_app_iff in H2. simpl in H2.
        destruct (eq_dec a a0).
        * subst. eapply List.NoDup_remove_2 in H0; intuition.
        * destruct H2.
          ++ eapply List.in_app_iff in H4. intuition.
          ++ destruct n; eauto.
          ++ assumption.
     - intros. rewrite H3. simpl. rewrite List.in_app_iff.
       rewrite Hlieq. rewrite List.in_app_iff. simpl. intuition.
       subst. inversion H. intuition.
   }
   rewrite Hlieq. rewrite List.app_length. simpl length.
   rewrite H4. rewrite List.app_length. omega.
  * assert (List.In a lui). { eapply H3. split. left. reflexivity. assumption. }
    destruct (List.in_split a lui H4) as [lui' [lui'' Hlui]].
    assert (length (List.app lui' lui'') = length lu - length li).
    {
      eapply IHlu; eauto.
      - inversion H. assumption.
      - rewrite Hlui in H1.  eapply List.NoDup_remove_1; eauto.
      - intros e Hincl. specialize (H2 e Hincl). simpl in H2. intuition. subst.
        intuition.
      - intros. destruct (eq_dec a e).
        -- split; intros. assert False. rewrite Hlui in H1. eapply List.NoDup_remove_2 in H1. destruct H1.
           subst. assumption. destruct H6.
           inversion H. subst. destruct H8. apply H5.
        -- rewrite Hlui in H3. specialize (H3 e).
           rewrite List.in_app_iff in H3. simpl in H3.
           rewrite List.in_app_iff. clear - H3 n0. intuition.
    }
    rewrite Hlui. rewrite List.app_length. simpl length. rewrite List.app_length in H5.
    assert (List.length li <= List.length lu).
    {
      eapply List.NoDup_incl_length; eauto.
      intros e Hincl. specialize (H2 e Hincl). simpl in H2. intuition. subst.
      intuition.
    }
  omega.
Qed.

Lemma NoDup_app: forall {A} l l'
  (Hnotin1: forall e: A, List.In e l -> ~ List.In e l')
  (Hnotin2: forall e, List.In e l' -> ~ List.In e l),
  List.NoDup l -> List.NoDup l' -> List.NoDup (List.app l l').
Proof.
induction l; intros.
+ simpl. assumption.
+ simpl. constructor; eauto.
  - intro. rewrite List.in_app_iff in H1. destruct H1. inversion H; intuition.
    eapply Hnotin1; eauto. left. reflexivity.
  - eapply IHl; eauto.
    * intros. eapply Hnotin1. right. assumption.
    * intros. eapply Hnotin2 in H1. intro Habs. destruct H1. right. assumption.
    * inversion H; eauto.
Qed.

(* Why3 goal *)
Lemma cardinal_union {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s1 -> is_finite s2 ->
  ((cardinal (set.Set.union s1 s2)) =
   (((cardinal s1) + (cardinal s2))%Z - (cardinal (set.Set.inter s1 s2)))%Z).
Proof.
intros s1 s2 h1 h2.
assert (is_finite (set.Set.union s1 s2)). { apply is_finite_union; eauto. }
assert (is_finite (set.Set.inter s1 s2)). { apply is_finite_inter_left; eauto. }
unfold cardinal.
(* Remove classical epsilon noise *)
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 H). specialize (a1 h1). specialize (a2 h2). specialize (a3 H0).
destruct a0 as [Hdup_un Heq_un].
destruct a1 as [Hdups2 Heqs2].
destruct a2 as [Hdups1 Heqs1].
destruct a3 as [Hdup_int Heq_int].
rename x into lun. rename x0 into l1. rename x1 into l2. rename x2 into lint.
(* In terms of list, we create the list that has elements of union - intersection.
   And we create the union of (l1 - intersection) and (l2 - intersection).
   We obtain a list equality. We can deduce the length equation from that. *)
assert (exists lun_lint, List.NoDup lun_lint /\
  forall e, List.In e lun_lint <-> (List.In e lun /\ not (List.In e lint))).
{
  eapply NoDup_exists. eapply why_decidable_eq. intros.
  destruct (List.in_dec why_decidable_eq e lint); eauto.
}
destruct H1 as [lun_lint [Hduplun_lint Heqlun_lint]].
assert (List.length lun_lint = List.length lun - List.length lint).
{
eapply length_prop; eauto. apply why_decidable_eq.
intro. intros. eapply Heq_un. eapply set.Set.union'def. eapply Heq_int in H1.
eapply set.Set.inter'def in H1. intuition.
}

assert (exists l1_lint, List.NoDup l1_lint /\
  forall e, List.In e l1_lint <-> (List.In e l1 /\ not (List.In e lint))).
{
  eapply NoDup_exists. eapply why_decidable_eq. intros.
  destruct (List.in_dec why_decidable_eq e lint); eauto.
}
destruct H2 as [l1_lint [Hdupl1_lint Heql1_lint]].
assert (List.length l1_lint = List.length l1 - List.length lint).
{
  eapply length_prop; eauto. apply why_decidable_eq.
  intro. intros. eapply Heqs2. eapply Heq_int in H2.
  eapply set.Set.inter'def in H2. intuition.
}
assert (exists l2_lint, List.NoDup l2_lint /\
  forall e, List.In e l2_lint <-> (List.In e l2 /\ not (List.In e lint))).
{
  eapply NoDup_exists. eapply why_decidable_eq. intros.
  destruct (List.in_dec why_decidable_eq e lint); eauto.
}
destruct H3 as [l2_lint [Hdupl2_lint Heql2_lint]].
assert (List.length l2_lint = List.length l2 - List.length lint).
{
  eapply length_prop; eauto. apply why_decidable_eq.
  intro. intros. eapply Heqs1. eapply Heq_int in H3.
  eapply set.Set.inter'def in H3. intuition.
}
assert (List.NoDup (List.app l1_lint l2_lint) /\
  forall e, List.In e lun_lint <-> List.In e (List.app l1_lint l2_lint)).
{
  split.
  - eapply NoDup_app; eauto.
    + intros. rewrite Heql2_lint. eapply Heql1_lint in H4.
      rewrite Heqs2 in H4. rewrite Heq_int in H4. rewrite Heq_int.
      rewrite Heqs1. rewrite set.Set.inter'def in H4. rewrite set.Set.inter'def.
      unfold set.Set.mem in *. intuition.
    + intros. rewrite Heql2_lint in H4. rewrite Heql1_lint.
      rewrite Heqs2. rewrite Heq_int. rewrite Heq_int in H4.
      rewrite Heqs1 in H4. rewrite set.Set.inter'def in H4. rewrite set.Set.inter'def.
      unfold set.Set.mem in *. intuition.
  - intros. rewrite List.in_app_iff. rewrite Heqlun_lint.
  rewrite Heql1_lint. rewrite Heql2_lint. rewrite Heq_un, Heqs2, Heqs1, Heq_int.
  rewrite set.Set.union'def. rewrite set.Set.inter'def. unfold set.Set.mem.
  clear - s1. intuition.
}
assert (List.length (List.app l1_lint l2_lint) = List.length lun_lint).
{
  assert (List.length (List.app l1_lint l2_lint) <= List.length lun_lint).
  eapply List.NoDup_incl_length; intuition. intro. apply H6.
  assert (List.length (List.app l1_lint l2_lint) >= List.length lun_lint).
  eapply List.NoDup_incl_length; intuition. intro. apply H7.
  omega.
}

assert (length l1 >= length lint).
{
  eapply List.NoDup_incl_length; intuition. intros e Hincl. eapply Heq_int in Hincl.
  eapply Heqs2. eapply set.Set.inter'def in Hincl. intuition.
}
assert (length l2 >= length lint).
{
  eapply List.NoDup_incl_length; intuition. intros e Hincl. eapply Heq_int in Hincl.
  eapply Heqs1. eapply set.Set.inter'def in Hincl. intuition.
}
assert (length lun >= length lint).
{
  eapply List.NoDup_incl_length; intuition. intros e Hincl. eapply Heq_int in Hincl.
  eapply Heq_un. eapply set.Set.inter'def in Hincl. eapply set.Set.union'def. intuition.
}
rewrite List.app_length in H5. omega.
Qed.

(* Why3 goal *)
Lemma cardinal_inter_disjoint {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  set.Set.disjoint s1 s2 -> ((cardinal (set.Set.inter s1 s2)) = 0%Z).
Proof.
intros s1 s2 h1.
eapply set.Set.disjoint_inter_empty in h1.
unfold set.Set.is_empty, set.Set.mem in h1.
unfold cardinal.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 i). destruct a0.
destruct x. reflexivity.
destruct (h1 a0). eapply H0. left. reflexivity.
Qed.

(* Why3 goal *)
Lemma cardinal_diff {a:Type} {a_WT:WhyType a} :
  forall (s1:a -> Init.Datatypes.bool) (s2:a -> Init.Datatypes.bool),
  is_finite s1 ->
  ((cardinal (set.Set.diff s1 s2)) =
   ((cardinal s1) - (cardinal (set.Set.inter s1 s2)))%Z).
Proof.
intros s1 s2 h1.
assert (is_finite (set.Set.inter s1 s2)). { apply is_finite_inter_left; eauto. }
assert (is_finite (set.Set.diff s1 s2)). { apply is_finite_diff; eauto. }
unfold cardinal.
(* Remove classical epsilon noise *)
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 i). specialize (a1 i0). specialize (a2 i1).
destruct a0, a1, a2.
assert (List.length x = List.length x0 - List.length x1).
{
  eapply length_prop; eauto.
  - apply why_decidable_eq.
  - intros e Hin. eapply H6 in Hin. eapply H4. eapply set.Set.inter'def in Hin.
    apply Hin.
  - intros. rewrite H6. rewrite H4. rewrite H2. rewrite set.Set.diff'def.
    rewrite set.Set.inter'def. intuition.
}
assert (List.length x0 >= List.length x1).
eapply List.NoDup_incl_length; intuition.
{
  intros e Hincl. eapply H4. eapply H6 in Hincl. rewrite set.Set.inter'def in Hincl.
  intuition.
}
omega.
Qed.

(* Why3 goal *)
Lemma cardinal_map {a:Type} {a_WT:WhyType a} {b:Type} {b_WT:WhyType b} :
  forall (f:a -> b) (s:a -> Init.Datatypes.bool), is_finite s ->
  ((cardinal (set.Set.map f s)) <= (cardinal s))%Z.
Proof.
intros f s h1.
assert (is_finite (set.Set.map f s)). { eapply is_finite_map. assumption. }
unfold cardinal.
(* Remove classical epsilon noise *)
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
destruct ClassicalEpsilon.excluded_middle_informative; [| intuition].
destruct ClassicalEpsilon.classical_indefinite_description.
specialize (a0 i). specialize (a1 i0).
destruct a0, a1.
assert (List.length x <= List.length x0).
{
  eapply le_trans with (List.length (List.map f x0)).
  - assert (List.incl x (List.map f x0)).
    { intro. intros. eapply H1 in H4. rewrite set.Set.map'def in H4.
      destruct H4. destruct H4. subst.
      eapply List.in_map. eapply H3; eauto.
    }
    eapply List.NoDup_incl_length; eauto.
  - rewrite List.map_length; eauto.
}
omega.
Qed.
