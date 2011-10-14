(* This file is generated by Why3's Coq driver *)
(* Beware! Only edit allowed sections below    *)
Require Import ZArith.
Require Import Rbase.
Parameter ident : Type.

Axiom ident_eq_dec : forall (i1:ident) (i2:ident), (i1 = i2) \/ ~ (i1 = i2).

Parameter mk_ident: Z -> ident.


Axiom mk_ident_inj : forall (i:Z) (j:Z), ((mk_ident i) = (mk_ident j)) ->
  (i = j).

Inductive operator  :=
  | Oplus : operator 
  | Ominus : operator 
  | Omult : operator .

Inductive expr  :=
  | Econst : Z -> expr 
  | Evar : ident -> expr 
  | Ebin : expr -> operator -> expr -> expr .

Inductive stmt  :=
  | Sskip : stmt 
  | Sassign : ident -> expr -> stmt 
  | Sseq : stmt -> stmt -> stmt 
  | Sif : expr -> stmt -> stmt -> stmt 
  | Swhile : expr -> stmt -> stmt .

Axiom check_skip : forall (s:stmt), (s = Sskip) \/ ~ (s = Sskip).

Parameter map : forall (a:Type) (b:Type), Type.

Parameter get: forall (a:Type) (b:Type), (map a b) -> a -> b.

Implicit Arguments get.

Parameter set: forall (a:Type) (b:Type), (map a b) -> a -> b -> (map a b).

Implicit Arguments set.

Axiom Select_eq : forall (a:Type) (b:Type), forall (m:(map a b)),
  forall (a1:a) (a2:a), forall (b1:b), (a1 = a2) -> ((get (set m a1 b1)
  a2) = b1).

Axiom Select_neq : forall (a:Type) (b:Type), forall (m:(map a b)),
  forall (a1:a) (a2:a), forall (b1:b), (~ (a1 = a2)) -> ((get (set m a1 b1)
  a2) = (get m a2)).

Parameter const: forall (b:Type) (a:Type), b -> (map a b).

Set Contextual Implicit.
Implicit Arguments const.
Unset Contextual Implicit.

Axiom Const : forall (b:Type) (a:Type), forall (b1:b) (a1:a), ((get (const(
  b1):(map a b)) a1) = b1).

Definition state  := (map ident Z).

Definition eval_bin(x:Z) (op:operator) (y:Z): Z :=
  match op with
  | Oplus => (x + y)%Z
  | Ominus => (x - y)%Z
  | Omult => (x * y)%Z
  end.

Set Implicit Arguments.
Fixpoint eval_expr(s:(map ident Z)) (e:expr) {struct e}: Z :=
  match e with
  | (Econst n) => n
  | (Evar x) => (get s x)
  | (Ebin e1 op e2) => (eval_bin (eval_expr s e1) op (eval_expr s e2))
  end.
Unset Implicit Arguments.

Inductive one_step : (map ident Z) -> stmt -> (map ident Z)
  -> stmt -> Prop :=
  | one_step_assign : forall (s:(map ident Z)) (x:ident) (e:expr),
      (one_step s (Sassign x e) (set s x (eval_expr s e)) Sskip)
  | one_step_seq : forall (s:(map ident Z)) (sqt:(map ident Z)) (i1:stmt)
      (i1qt:stmt) (i2:stmt), (one_step s i1 sqt i1qt) -> (one_step s (Sseq i1
      i2) sqt (Sseq i1qt i2))
  | one_step_seq_skip : forall (s:(map ident Z)) (i:stmt), (one_step s
      (Sseq Sskip i) s i)
  | one_step_if_true : forall (s:(map ident Z)) (e:expr) (i1:stmt) (i2:stmt),
      (~ ((eval_expr s e) = 0%Z)) -> (one_step s (Sif e i1 i2) s i1)
  | one_step_if_false : forall (s:(map ident Z)) (e:expr) (i1:stmt)
      (i2:stmt), ((eval_expr s e) = 0%Z) -> (one_step s (Sif e i1 i2) s i2)
  | one_step_while_true : forall (s:(map ident Z)) (e:expr) (i:stmt),
      (~ ((eval_expr s e) = 0%Z)) -> (one_step s (Swhile e i) s (Sseq i
      (Swhile e i)))
  | one_step_while_false : forall (s:(map ident Z)) (e:expr) (i:stmt),
      ((eval_expr s e) = 0%Z) -> (one_step s (Swhile e i) s Sskip).

Axiom progress : forall (s:(map ident Z)) (i:stmt), (~ (i = Sskip)) ->
  exists sqt:(map ident Z), exists iqt:stmt, (one_step s i sqt iqt).

Inductive many_steps : (map ident Z) -> stmt -> (map ident Z) -> stmt
  -> Z -> Prop :=
  | many_steps_refl : forall (s:(map ident Z)) (i:stmt), (many_steps s i s i
      0%Z)
  | many_steps_trans : forall (s1:(map ident Z)) (s2:(map ident Z)) (s3:(map
      ident Z)) (i1:stmt) (i2:stmt) (i3:stmt) (n:Z), (one_step s1 i1 s2
      i2) -> ((many_steps s2 i2 s3 i3 n) -> (many_steps s1 i1 s3 i3
      (n + 1%Z)%Z)).

Axiom steps_non_neg : forall (s1:(map ident Z)) (s2:(map ident Z)) (i1:stmt)
  (i2:stmt) (n:Z), (many_steps s1 i1 s2 i2 n) -> (0%Z <= n)%Z.

Axiom many_steps_seq : forall (s1:(map ident Z)) (s3:(map ident Z)) (i1:stmt)
  (i2:stmt) (n:Z), (many_steps s1 (Sseq i1 i2) s3 Sskip n) -> exists s2:(map
  ident Z), exists n1:Z, exists n2:Z, (many_steps s1 i1 s2 Sskip n1) /\
  ((many_steps s2 i2 s3 Sskip n2) /\ (n = ((1%Z + n1)%Z + n2)%Z)).

Inductive fmla  :=
  | Fterm : expr -> fmla 
  | Fand : fmla -> fmla -> fmla 
  | Fnot : fmla -> fmla .

Set Implicit Arguments.
Fixpoint eval_fmla(s:(map ident Z)) (f:fmla) {struct f}: Prop :=
  match f with
  | (Fterm e) => ~ ((eval_expr s e) = 0%Z)
  | (Fand f1 f2) => (eval_fmla s f1) /\ (eval_fmla s f2)
  | (Fnot f1) => ~ (eval_fmla s f1)
  end.
Unset Implicit Arguments.

Parameter subst_expr: expr -> ident -> expr -> expr.


Axiom subst_expr_def : forall (e:expr) (x:ident) (t:expr),
  match e with
  | (Econst _) => ((subst_expr e x t) = e)
  | (Evar y) => ((x = y) -> ((subst_expr e x t) = t)) /\ ((~ (x = y)) ->
      ((subst_expr e x t) = e))
  | (Ebin e1 op e2) => ((subst_expr e x t) = (Ebin (subst_expr e1 x t) op
      (subst_expr e2 x t)))
  end.

Axiom eval_subst_expr : forall (s:(map ident Z)) (e:expr) (x:ident) (t:expr),
  ((eval_expr s (subst_expr e x t)) = (eval_expr (set s x (eval_expr s t))
  e)).

Set Implicit Arguments.
Fixpoint subst(f:fmla) (x:ident) (t:expr) {struct f}: fmla :=
  match f with
  | (Fterm e) => (Fterm (subst_expr e x t))
  | (Fand f1 f2) => (Fand (subst f1 x t) (subst f2 x t))
  | (Fnot f1) => (Fnot (subst f1 x t))
  end.
Unset Implicit Arguments.

Axiom eval_subst : forall (s:(map ident Z)) (f:fmla) (x:ident) (t:expr),
  (eval_fmla s (subst f x t)) <-> (eval_fmla (set s x (eval_expr s t)) f).

Definition valid_triple(p:fmla) (i:stmt) (q:fmla): Prop := forall (s:(map
  ident Z)), (eval_fmla s p) -> forall (sqt:(map ident Z)) (n:Z),
  (many_steps s i sqt Sskip n) -> (eval_fmla sqt q).

Axiom skip_rule : forall (q:fmla), (valid_triple q Sskip q).

Axiom assign_rule : forall (q:fmla) (x:ident) (e:expr),
  (valid_triple (subst q x e) (Sassign x e) q).

Axiom seq_rule : forall (p:fmla) (q:fmla) (r:fmla) (i1:stmt) (i2:stmt),
  ((valid_triple p i1 r) /\ (valid_triple r i2 q)) -> (valid_triple p
  (Sseq i1 i2) q).

Axiom if_rule : forall (e:expr) (p:fmla) (q:fmla) (i1:stmt) (i2:stmt),
  ((valid_triple (Fand p (Fterm e)) i1 q) /\ (valid_triple (Fand p
  (Fnot (Fterm e))) i2 q)) -> (valid_triple p (Sif e i1 i2) q).

(* YOU MAY EDIT THE CONTEXT BELOW *)

(* DO NOT EDIT BELOW *)

Theorem while_rule : forall (e:expr) (inv:fmla) (i:stmt),
  (valid_triple (Fand (Fterm e) inv) i inv) -> (valid_triple inv (Swhile e i)
  (Fand (Fnot (Fterm e)) inv)).
(* YOU MAY EDIT THE PROOF BELOW *)
unfold valid_triple.
intros e inv i Hinv_preserved.
intros s Hinv_init s' n Hred.
generalize (steps_non_neg _ _ _ _ _ Hred); intro Hn_pos.
generalize Hred; clear Hred.
generalize s Hinv_init; clear s Hinv_init.
apply Z_lt_induction
 with (P := fun n =>
  forall s : map ident Z,
  eval_fmla s inv ->
  many_steps s (Swhile e i) s' Sskip n ->
  eval_fmla s' (Fand (Fnot (Fterm e)) inv)
); auto.
intros.
inversion H1; subst; clear H1.
inversion H2; subst; clear H2.
(* case cond true *)
generalize (many_steps_seq _ _ _ _ _ H3).
intros (s3,(n1,(n2,(h1,(h2,h3))))).
apply H with (y:=n2) (s:=s3); auto.
generalize (steps_non_neg _ _ _ _ _ h1).
generalize (steps_non_neg _ _ _ _ _ h2).
now (auto with zarith).
apply Hinv_preserved with (s:=s2) (n:=n1); simpl; auto.
(* case cond false *)
inversion H3; subst.
simpl; auto.
now inversion H1.
Qed.
(* DO NOT EDIT BELOW *)


