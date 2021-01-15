(* Distributed under the terms of the MIT license. *)
From Coq Require Import Morphisms.
Require Import ssreflect ssrfun ssrbool.
From MetaCoq.Template Require Import config utils MCPred.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICCases PCUICInduction
  PCUICLiftSubst PCUICUnivSubst
  PCUICEquality PCUICSigmaCalculus PCUICClosed.

(* For the last proof only, about reduction, requiring closed global declarations. *)
From MetaCoq.PCUIC Require Import PCUICTyping PCUICWeakeningEnv.

From Equations Require Import Equations.
Require Import Equations.Prop.DepElim.
Set Equations With UIP.

(** * Preservation of free variables *)

Open Scope sigma_scope.
Set Keyed Unification.

Set Default Goal Selector "!".

Implicit Type (cf : checker_flags).

Definition shiftnP k p i :=
  (i <? k) || p (i - k).

Instance shiftnP_ext k : Proper (`=1` ==> `=1`) (shiftnP k).
Proof. intros f g Hfg i. now rewrite /shiftnP Hfg. Qed. 

Lemma shiftnP0 P : shiftnP 0 P =1 P.
Proof. rewrite /shiftnP. intros i; rewrite Nat.sub_0_r //. Qed.
  
Lemma shiftnP_add n k P : shiftnP n (shiftnP k P) =1 shiftnP (n + k) P.
Proof. rewrite /shiftnP. intros i; repeat nat_compare_specs => // /=. lia_f_equal. Qed.

Lemma shiftnP_impl (p q : nat -> bool) : (forall i, p i -> q i) ->
  forall n i, shiftnP n p i -> shiftnP n q i.
Proof.
  intros Hi n i. rewrite /shiftnP.
  nat_compare_specs => //. apply Hi.
Qed.

Fixpoint on_free_vars (p : nat -> bool) (t : term) : bool :=
  match t with
  | tRel i => p i
  | tEvar ev args => List.forallb (on_free_vars p) args
  | tLambda _ T M | tProd _ T M => on_free_vars p T && on_free_vars (shiftnP 1 p) M
  | tApp u v => on_free_vars p u && on_free_vars p v
  | tLetIn na b t b' => [&& on_free_vars p b, on_free_vars p t & on_free_vars (shiftnP 1 p) b']
  | tCase ind pred c brs =>
    [&& forallb (on_free_vars p) pred.(pparams),
      on_free_vars (shiftnP #|pred.(pcontext)| p) pred.(preturn),
      test_context_k (fun k => on_free_vars (shiftnP k p)) 0 pred.(pcontext),
      on_free_vars p c &
      forallb (fun br => 
        test_context_k (fun k => on_free_vars (shiftnP k p)) 0 br.(bcontext) &&
        on_free_vars (shiftnP #|br.(bcontext)| p) br.(bbody)) brs]
  | tProj _ c => on_free_vars p c
  | tFix mfix idx | tCoFix mfix idx =>
    List.forallb (test_def (on_free_vars p) (on_free_vars (shiftnP #|mfix| p))) mfix
  | tVar _ | tSort _ | tConst _ _ | tInd _ _ | tConstruct _ _ _ 
  | tPrim _ => true
  end.

Lemma on_free_vars_ext (p q : nat -> bool) t : 
  p =1 q ->
  on_free_vars p t = on_free_vars q t.
Proof.
  revert p q.
  induction t using PCUICInduction.term_forall_list_ind; simpl => //; intros;
    unfold test_def;
    rewrite ?forallb_map; try eapply All_forallb_eq_forallb; tea; eauto 2.
  all: try now rewrite (IHt1 p q) // ?(IHt2 (shiftnP 1 p) (shiftnP 1 q)) // H.
  - now rewrite (IHt1 p q) // ?(IHt2 p q) // (IHt3 (shiftnP 1 p) (shiftnP 1 q)) // H.
  - rewrite (IHt1 p q) // (IHt2 p q) //.
  - destruct X as [? [? ?]]. red in X0.
    f_equal.
    * eapply All_forallb_eq_forallb; tea. solve_all.
    * f_equal; [eapply e; rewrite H //|].
      f_equal.
      + solve_all; rewrite Nat.add_0_r. apply H0 => //.
        now apply shiftnP_ext.
      + f_equal; [eapply IHt; rewrite H //|].
        eapply All_forallb_eq_forallb; tea. intros.
        destruct X.
        f_equal; [|eapply e0; rewrite H //].
        solve_all; rewrite Nat.add_0_r; apply H0 => //.
        now apply shiftnP_ext.
  - simpl; intuition auto. f_equal; eauto 2.
    eapply b; rewrite H //.
  - simpl; intuition auto. f_equal; eauto 2.
    eapply b; rewrite H //.
Qed.

Instance on_free_vars_proper : Proper (`=1` ==> Logic.eq ==> Logic.eq) on_free_vars.
Proof. intros f g Hfg ? ? ->. now apply on_free_vars_ext. Qed.

Instance on_free_vars_proper_pointwise : Proper (`=1` ==> `=1`) on_free_vars.
Proof. intros f g Hfg x. now apply on_free_vars_ext. Qed.

Lemma shiftnP_xpredT n : shiftnP n xpredT =1 xpredT.
Proof. intros i; rewrite /shiftnP. nat_compare_specs => //. Qed.

Lemma test_context_k_ctx p k (ctx : context) : test_context_k (fun=> p) k ctx = test_context p ctx.
Proof.
  induction ctx; simpl; auto.
Qed.
Hint Rewrite test_context_k_ctx : map.

Lemma reflect_option_default {A} {P : A -> Type} {p : A -> bool} : 
  (forall x, reflectT (P x) (p x)) ->
  forall x, reflectT (option_default P x unit) (option_default p x true).
Proof.
  intros Hp x.
  destruct x => /= //. constructor. exact tt.
Qed.

Lemma ondeclP {P : term -> Type} {p : term -> bool} {d : context_decl} :
  (forall x, reflectT (P x) (p x)) ->
  reflectT (ondecl P d) (test_decl p d).
Proof.
  intros hr.
  rewrite /ondecl /test_decl; destruct d; cbn.
  destruct (hr decl_type) => //;
  destruct (reflect_option_default hr decl_body) => /= //; now constructor.
Qed.

Lemma reflectT_pred {A} {p : A -> bool} : forall x, reflectT (p x) (p x).
Proof.
  intros x. now apply equiv_reflectT.
Qed.

Lemma reflectT_pred2 {A B} {p : A -> B -> bool} : forall x y, reflectT (p x y) (p x y).
Proof.
  intros x y. now apply equiv_reflectT.
Qed.

Lemma onctx_test {p : term -> bool} {ctx : context} :
  reflectT (onctx p ctx) (test_context p ctx).
Proof.
  eapply equiv_reflectT.
  - induction 1; simpl; auto. rewrite IHX /= //.
    now move/(ondeclP reflectT_pred): p0.
  - induction ctx.
    * constructor.
    * move => /= /andP [Hctx Hd]; constructor; eauto.
      now move/(ondeclP reflectT_pred): Hd.
Qed.

Hint Rewrite test_context_k_ctx : map.

Lemma on_free_vars_true t : on_free_vars xpredT t.
Proof.
  revert t.
  induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
  all:try (rtoProp; now rewrite ?shiftnP_xpredT ?IHt1 ?IHt2 ?IHt3; eauto 2; 
    try rtoProp; solve_all).
  - rtoProp. setoid_rewrite shiftnP_xpredT.
    rewrite test_context_k_ctx.
    now move/onctx_test: a0.
  - setoid_rewrite shiftnP_xpredT.
    rewrite test_context_k_ctx.
    now move/onctx_test: a1.
  - unfold test_def in *. apply /andP. now rewrite shiftnP_xpredT.
  - unfold test_def in *. apply /andP. now rewrite shiftnP_xpredT.
Qed.

Lemma on_free_vars_impl (p q : nat -> bool) t :
  (forall i, p i -> q i) ->
  on_free_vars p t -> 
  on_free_vars q t.
Proof.
  unfold pointwise_relation, Basics.impl.
  intros Himpl onf. revert onf Himpl.
  revert t p q.
  induction t using PCUICInduction.term_forall_list_ind; simpl => //; solve_all.
  all:unfold test_def in *; rtoProp; now (eauto using shiftnP_impl with all).
Qed.

Definition closedP (n : nat) (P : nat -> bool) := 
  fun i => if i <? n then P i else false.
  
Instance closedP_proper n : Proper (`=1` ==> `=1`) (closedP n).
Proof. intros f g Hfg. intros i; rewrite /closedP. now rewrite Hfg. Qed.
  
Lemma shiftnP_closedP k n P : shiftnP k (closedP n P) =1 closedP (k + n) (shiftnP k P).
Proof.
  intros i; rewrite /shiftnP /closedP.
  repeat nat_compare_specs => //.
Qed.

(** Useful for inductions *)
Lemma onctx_k_rev {P : nat -> term -> Type} {k} {ctx} :
  onctx_k P k ctx <~>
  Alli (fun i => ondecl (P (i + k))) 0 (List.rev ctx).
Proof.
  split.
  - unfold onctx_k.
    intros Hi.
    eapply forall_nth_error_Alli => i x hx.
    pose proof (nth_error_Some_length hx).
    rewrite nth_error_rev // in hx.
    rewrite List.rev_involutive in hx.
    len in hx.
    eapply Alli_nth_error in Hi; tea.
    simpl in Hi. simpl.
    replace (Nat.pred #|ctx| - (#|ctx| - S i) + k) with (i + k) in Hi => //.
    len in H; by lia.
  - intros Hi.
    eapply forall_nth_error_Alli => i x hx.
    eapply Alli_rev_nth_error in Hi; tea.
    simpl.
    replace (#|ctx| - S i + k) with (Nat.pred #|ctx| - i + k) in Hi => //.
    lia.
Qed.

Lemma onctx_k_shift {P : nat -> term -> Type} {k} {ctx} :
  onctx_k P k ctx ->
  onctx_k (fun k' => P (k' + k)) 0 ctx.
Proof.
  intros Hi%onctx_k_rev.
  eapply onctx_k_rev.
  eapply Alli_impl; tea => /= n x.
  now rewrite Nat.add_0_r.
Qed.

Lemma onctx_k_P {P : nat -> term -> Type} {p : nat -> term -> bool} {k} {ctx : context} :
  (forall x y, reflectT (P x y) (p x y)) ->
  reflectT (onctx_k P k ctx) (test_context_k p k ctx).
Proof.
  intros HP.
  eapply equiv_reflectT.
  - intros Hi%onctx_k_rev.
    rewrite test_context_k_eq.
    induction Hi; simpl; auto.
    rewrite Nat.add_comm.
    rewrite IHHi /= //.
    now move/(ondeclP (HP _)): p0 => ->.
  - intros Hi. eapply onctx_k_rev.
    move: ctx Hi. induction ctx.
    * constructor.
    * move => /= /andP [Hctx Hd].
      eapply Alli_app_inv; eauto. constructor.
      + move/(ondeclP (HP _)): Hd. now len.
      + constructor.
Qed.

Lemma closedP_on_free_vars {n t} : closedn n t -> on_free_vars (closedP n xpredT) t.
Proof.
  revert n t.
  apply: term_closedn_list_ind; simpl => //; intros.
  all:(rewrite ?shiftnP_closedP ?shiftnP_xpredT).
  all:try (rtoProp; now rewrite ?IHt1 ?IHt2 ?IHt3).
  - rewrite /closedP /=. now nat_compare_specs.
  - solve_all.
  - destruct X. rtoProp. intuition solve_all.
    * setoid_rewrite shiftnP_closedP.
      setoid_rewrite shiftnP_xpredT.
      eapply onctx_k_shift in a0. simpl in a0.
      case: (onctx_k_P reflectT_pred2) => //.
    * red in X0. solve_all.
      + setoid_rewrite shiftnP_closedP.
        setoid_rewrite shiftnP_xpredT.
        eapply onctx_k_shift in a1. simpl in a1.
        case: (onctx_k_P reflectT_pred2) => //.
      + now rewrite shiftnP_closedP shiftnP_xpredT.
  - unfold test_def. solve_all.
    rewrite shiftnP_closedP shiftnP_xpredT.
    now len in b.
  - unfold test_def; solve_all. 
    rewrite shiftnP_closedP shiftnP_xpredT.
    now len in b.
Qed.

Lemma closedn_on_free_vars {P n t} : closedn n t -> on_free_vars (shiftnP n P) t.
Proof.
  move/closedP_on_free_vars.
  eapply on_free_vars_impl.
  intros i; rewrite /closedP /shiftnP /= //.
  nat_compare_specs => //.
Qed.

(** Any predicate is admissible as there are no free variables to consider *)
Lemma closed_on_free_vars {P t} : closed t -> on_free_vars P t.
Proof.
  move/closedP_on_free_vars.
  eapply on_free_vars_impl.
  intros i; rewrite /closedP /= //.
Qed.

Lemma on_free_vars_subst_instance {p u t} : on_free_vars p t = on_free_vars p (subst_instance u t).
Proof.
  rewrite /subst_instance /=. revert t p.
  apply: term_forall_list_ind; simpl => //; intros.
  all:try (rtoProp; now rewrite -?IHt1 -?IHt2 -?IHt3).
  - rewrite forallb_map. eapply All_forallb_eq_forallb; eauto.
  - repeat (solve_all; f_equal).
  - unfold test_def. solve_all.
  - unfold test_def; solve_all.
Qed.

Definition on_free_vars_decl P d :=
  test_decl (on_free_vars P) d.

Instance on_free_vars_decl_proper : Proper (`=1` ==> Logic.eq ==> Logic.eq) on_free_vars_decl.
Proof. rewrite /on_free_vars_decl => f g Hfg x y <-. now rewrite Hfg. Qed.

Instance on_free_vars_decl_proper_pointwise : Proper (`=1` ==> `=1`) on_free_vars_decl.
Proof. rewrite /on_free_vars_decl => f g Hfg x. now rewrite Hfg. Qed.

Definition on_free_vars_ctx P ctx :=
  alli (fun k => (on_free_vars_decl (shiftnP k P))) 0 (List.rev ctx).

Instance on_free_vars_ctx_proper : Proper (`=1` ==> `=1`) on_free_vars_ctx.
Proof.
  rewrite /on_free_vars_ctx => f g Hfg x.
  now setoid_rewrite Hfg. 
Qed.

Lemma on_free_vars_decl_impl (p q : nat -> bool) d : 
  (forall i, p i -> q i) -> 
  on_free_vars_decl p d -> on_free_vars_decl q d.
Proof.
  intros hpi.
  apply test_decl_impl. intros t.
  now apply on_free_vars_impl.
Qed.

Lemma on_free_vars_ctx_impl (p q : nat -> bool) ctx : 
  (forall i, p i -> q i) -> 
  on_free_vars_ctx p ctx -> on_free_vars_ctx q ctx.
Proof.
  intros hpi.
  eapply alli_impl => i x.
  apply on_free_vars_decl_impl.
  intros k; rewrite /shiftnP.
  now nat_compare_specs.
Qed.

Lemma closed_decl_on_free_vars {n d} : closed_decl n d -> on_free_vars_decl (closedP n xpredT) d.
Proof.
  rewrite /on_free_vars_decl /test_decl.
  move=> /andP [clb cld].
  rewrite (closedP_on_free_vars cld) /=.
  destruct (decl_body d) eqn:db => /= //.
  now rewrite (closedP_on_free_vars clb).
Qed.

Lemma closedn_ctx_on_free_vars {n ctx} : closedn_ctx n ctx ->
  on_free_vars_ctx (closedP n xpredT) ctx.
Proof.
  rewrite /on_free_vars_ctx test_context_k_eq.
  apply alli_impl => i x.
  rewrite shiftnP_closedP Nat.add_comm shiftnP_xpredT.
  eapply closed_decl_on_free_vars.
Qed.

Lemma closedn_ctx_on_free_vars_shift {n ctx P} : 
  closedn_ctx n ctx ->
  on_free_vars_ctx (shiftnP n P) ctx.
Proof.
  move/closedn_ctx_on_free_vars.
  rewrite /on_free_vars_ctx.
  apply alli_impl => i x.
  rewrite shiftnP_closedP shiftnP_add shiftnP_xpredT.
  eapply on_free_vars_decl_impl => //.
  intros k.
  rewrite /closedP /shiftnP.
  now nat_compare_specs => //.
Qed.

(** This uses absurdity elimination as [ctx] can't have any free variable *)
Lemma closed_ctx_on_free_vars P ctx : closed_ctx ctx ->
  on_free_vars_ctx P ctx.
Proof.
  move/closedn_ctx_on_free_vars => /=.
  rewrite /closedP /=.
  eapply on_free_vars_ctx_impl => //.
Qed.

Definition nocc_betweenp k n i :=
  (i <? k) || (k + n <=? i).

Definition nocc_between k n t := 
  (on_free_vars (nocc_betweenp k n) t).

Definition noccur_shift p k := fun i => (i <? k) || p (i - k).

Hint Resolve All_forallb_eq_forallb : all.

Definition strengthenP k n (p : nat -> bool) := 
  fun i => if i <? k then p i else 
    if i <? k + n then false 
    else p (i - n).

Instance strengthenP_proper n k : Proper (`=1` ==> `=1`) (strengthenP n k).
Proof.
  intros f g Hfg i. rewrite /strengthenP. now rewrite (Hfg i) (Hfg (i - k)).
Qed.

Lemma shiftnP_strengthenP k' k n p : 
  shiftnP k' (strengthenP k n p) =1 strengthenP (k' + k) n (shiftnP k' p).
Proof.
  intros i. rewrite /shiftnP /strengthenP.
  repeat nat_compare_specs => /= //. 
  lia_f_equal.
Qed.

Lemma on_free_vars_lift (p : nat -> bool) n k t : 
  on_free_vars (strengthenP k n p) (lift n k t) = on_free_vars p t.
Proof.
  intros. revert t n k p.
  induction t using PCUICInduction.term_forall_list_ind; simpl => //; intros;
    rewrite ?forallb_map; try eapply All_forallb_eq_forallb; tea; simpl.
  2-6:try now rewrite ?shiftnP_strengthenP ?IHt1 ?IHt2 ?IHt3.
  - rename n0 into i. rewrite /strengthenP.
    repeat nat_compare_specs => //.
    lia_f_equal.
  - rtoProp; solve_all. len; rewrite !shiftnP_strengthenP e IHt.
    f_equal; solve_all. f_equal; solve_all. f_equal; solve_all.
    + len. rewrite !shiftnP_strengthenP /shiftf. now rewrite Nat.sub_0_r H.
    + f_equal. solve_all.
      f_equal; solve_all.
      * len; rewrite !shiftnP_strengthenP /shiftf.
        now rewrite Nat.sub_0_r H.
      * len. now rewrite !shiftnP_strengthenP.
  - unfold test_def in *. simpl; intros ? [].
    len; rewrite shiftnP_strengthenP. f_equal; eauto.
  - unfold test_def in *. simpl; intros ? [].
    len; rewrite shiftnP_strengthenP. f_equal; eauto.
Qed.

Definition on_free_vars_terms p s :=
  forallb (on_free_vars p) s.
  
Definition substP (k : nat) n (q p : nat -> bool) : nat -> bool :=
  fun i => 
    if i <? k then p i
    else p (i + n) || strengthenP 0 k q i.

Lemma shiftnP_substP k' k n q p : 
  shiftnP k' (substP k n q p) =1 substP (k' + k) n q (shiftnP k' p).
Proof.
  intros i; rewrite /shiftnP /substP.
  repeat nat_compare_specs => /= //.
  f_equal; [f_equal|] => /= //.
  * lia_f_equal.
  * rewrite /strengthenP. simpl.
    repeat nat_compare_specs => //.
    lia_f_equal.
Qed.

Lemma on_free_vars_subst_gen (p q : nat -> bool) s k t : 
  on_free_vars_terms q s ->
  on_free_vars p t ->
  on_free_vars (substP k #|s| q p) (subst s k t).
Proof.
  revert t p k.
  induction t using PCUICInduction.term_forall_list_ind; simpl => //; intros;
    simpl.
  all:try (rtoProp; rewrite ?shiftnP_substP; now rewrite ?IHt1 ?IHt2 ?IHt3). 
  - intros. destruct (Nat.leb_spec k n).
    * destruct nth_error eqn:eq.
      + unfold on_free_vars_terms in *. toAll.
        pose proof (nth_error_Some_length eq).
        eapply nth_error_all in eq; eauto.
        simpl in eq. rewrite /substP.
        eapply on_free_vars_impl. 
        2:now rewrite -> on_free_vars_lift.
        rewrite /strengthenP. simpl.
        intros i. nat_compare_specs => //.
        intros ->. now rewrite orb_true_r.
      + eapply nth_error_None in eq.
        simpl. rewrite /substP.
        replace (n - #|s| + #|s|) with n by lia.
        nat_compare_specs.
        now rewrite H0.
    * simpl. rewrite /substP /strengthenP /=.
      rewrite H0. now nat_compare_specs.
  - solve_all.
  - rtoProp. destruct X. solve_all.
    * len. rewrite shiftnP_substP. solve_all.
    * len in H6. len; rewrite Nat.sub_0_r /shiftf !shiftnP_substP; solve_all.
    * len in H7; len. rewrite Nat.sub_0_r /shift !shiftnP_substP; solve_all.
    * len. rewrite shiftnP_substP; solve_all.
  - unfold test_def in *; red in X; solve_all.
    rtoProp. rewrite shiftnP_substP; len. solve_all.
  - unfold test_def in *; solve_all. rtoProp.
    rewrite shiftnP_substP; len. solve_all.
Qed.

Lemma rshiftk_S x f : S (rshiftk x f) = rshiftk (S x) f.
Proof. reflexivity. Qed.

Lemma substP_shiftnP n p : 
  substP 0 n p (shiftnP n p) =1 p.
Proof.
  intros i; rewrite /shiftnP /substP /= /strengthenP /=.
  nat_compare_specs.
  replace (i + n - n) with i by lia.
  now rewrite Nat.sub_0_r orb_diag.
Qed.

Lemma on_free_vars_subst (p : nat -> bool) s t : 
  forallb (on_free_vars p) s ->
  on_free_vars (shiftnP #|s| p) t ->
  on_free_vars p (subst s 0 t).
Proof.
  intros hs ht.
  epose proof (on_free_vars_subst_gen (shiftnP #|s| p) p s 0 t).
  rewrite -> substP_shiftnP in H.
  apply H.
  - exact hs.
  - apply ht.
Qed.

Lemma on_free_vars_subst1 (p : nat -> bool) s t : 
  on_free_vars p s ->
  on_free_vars (shiftnP 1 p) t ->
  on_free_vars p (subst1 s 0 t).
Proof.
  intros hs ht.
  rewrite /subst1.
  epose proof (on_free_vars_subst_gen (shiftnP 1 p) p [s] 0 t).
  rewrite -> substP_shiftnP in H.
  apply H.
  - now rewrite /on_free_vars_terms /= hs.
  - apply ht.
Qed.

Definition addnP n (p : nat -> bool) :=
  fun i => p (i + n).

Instance addnP_proper n : Proper (`=1` ==> Logic.eq ==> Logic.eq) (addnP n).
Proof.
  intros i f g Hfg; now rewrite /addnP.
Qed.
  
Instance addnP_proper_pointwise : Proper (Logic.eq ==> `=1` ==> `=1`) addnP.
Proof.
  intros i f g Hfg; now rewrite /addnP.
Qed.

Lemma addnP_add n k p : addnP n (addnP k p) =1 addnP (n + k) p.
Proof.
  rewrite /addnP => i. lia_f_equal.
Qed.

Lemma addnP0 p : addnP 0 p =1 p.
Proof. intros i; now rewrite /addnP Nat.add_0_r. Qed.

Lemma addnP_shiftnP n P : addnP n (shiftnP n P) =1 P.
Proof.
  intros i; rewrite /addnP /shiftnP /=.
  nat_compare_specs => /=. lia_f_equal.
Qed.

Lemma addnP_orP n p q : addnP n (predU p q) =1 predU (addnP n p) (addnP n q).
Proof. reflexivity. Qed.

Definition on_ctx_free_vars P ctx :=
  alli (fun k d => P k ==> (on_free_vars_decl (addnP (S k) P) d)) 0 ctx.

Instance on_ctx_free_vars_proper : Proper (`=1` ==> eq ==> eq) on_ctx_free_vars.
Proof.
  rewrite /on_ctx_free_vars => f g Hfg x y <-.
  apply alli_ext => k.
  now setoid_rewrite Hfg. 
Qed.

Instance on_ctx_free_vars_proper_pointwise : Proper (`=1` ==> `=1`) on_ctx_free_vars.
Proof.
  rewrite /on_ctx_free_vars => f g Hfg x.
  apply alli_ext => k.
  now setoid_rewrite Hfg. 
Qed.

Lemma nth_error_on_free_vars_ctx P n ctx i d :
  on_ctx_free_vars (addnP n P) ctx ->
  P (n + i) ->
  nth_error ctx i = Some d ->
  test_decl (on_free_vars (addnP (n + S i) P)) d.
Proof.
  rewrite /on_ctx_free_vars.
  solve_all.
  eapply alli_Alli, Alli_nth_error in H; eauto.
  rewrite /= {1}/addnP Nat.add_comm H0 /= in H.
  now rewrite Nat.add_comm -addnP_add.
Qed.

Definition aboveP k (p : nat -> bool) :=
  fun i => if i <? k then false else p i.

Lemma strengthenP_addn i p : strengthenP 0 i (addnP i p) =1 aboveP i p.
Proof.
   intros k.
   rewrite /strengthenP /= /addnP /aboveP.
   nat_compare_specs => //.
   lia_f_equal.
Qed.

Lemma on_free_vars_lift0 i p t :
  on_free_vars (addnP i p) t ->
  on_free_vars p (lift0 i t).
Proof.
  rewrite -(on_free_vars_lift _ i 0).
  rewrite /strengthenP /= /aboveP /addnP.
  unshelve eapply on_free_vars_impl.
  simpl. intros i'. nat_compare_specs => //.
  now replace (i' - i + i) with i' by lia.
Qed.

Lemma on_free_vars_lift0_above i p t :
  on_free_vars (addnP i p) t = on_free_vars (aboveP i p) (lift0 i t).
Proof.
  rewrite -(on_free_vars_lift _ i 0).
  rewrite /strengthenP /= /aboveP /addnP.
  unshelve eapply on_free_vars_ext.
  simpl. intros i'. nat_compare_specs => //.
  now replace (i' - i + i) with i' by lia.
Qed.

Lemma on_free_vars_mkApps p f args : 
  on_free_vars p (mkApps f args) = on_free_vars p f && forallb (on_free_vars p) args.
Proof.
  induction args in f |- * => /=.
  - now rewrite andb_true_r.
  - now rewrite IHargs /= andb_assoc.
Qed.

Lemma extended_subst_shiftn p ctx n k : 
  forallb (on_free_vars (strengthenP 0 n (shiftnP (k + context_assumptions ctx) p))) 
    (extended_subst ctx (n + k)) =
  forallb (on_free_vars (shiftnP (k + (context_assumptions ctx)) p)) 
    (extended_subst ctx k).
Proof.
  rewrite lift_extended_subst' forallb_map.
  eapply forallb_ext => t.
  rewrite -(on_free_vars_lift _ n 0 t) //.
Qed.

Lemma extended_subst_shiftn_aboveP p ctx n k : 
  forallb (on_free_vars (aboveP n p)) (extended_subst ctx (n + k)) =
  forallb (on_free_vars (addnP n p)) (extended_subst ctx k).
Proof.
  rewrite lift_extended_subst' forallb_map.
  eapply forallb_ext => t.
  rewrite -(on_free_vars_lift0_above) //.
Qed.

Lemma extended_subst_shiftn_impl p ctx n k : 
  forallb (on_free_vars (shiftnP (k + (context_assumptions ctx)) p)) 
    (extended_subst ctx k) ->
  forallb (on_free_vars (shiftnP (n + k + context_assumptions ctx) p))
    (extended_subst ctx (n + k)).
Proof.
  rewrite lift_extended_subst' forallb_map.
  eapply forallb_impl => t _.
  rewrite -(on_free_vars_lift _ n 0 t).
  rewrite /strengthenP /=.
  apply on_free_vars_impl => i.
  rewrite /shiftnP.
  repeat nat_compare_specs => /= //.
  intros.
  red; rewrite -H2. lia_f_equal.
Qed.

Definition occ_betweenP k n :=
  fun i => (k <=? i) && (i <? k + n).

Lemma on_free_vars_decl_all_term P d s :
  on_free_vars_decl P d = on_free_vars P (mkProd_or_LetIn d (tSort s)).
Proof.
  rewrite /on_free_vars_decl /= /test_decl.
  destruct d as [na [b|] ty] => /= //; now rewrite andb_true_r.
Qed.

Lemma on_free_vars_mkProd_or_LetIn P d t :
  on_free_vars P (mkProd_or_LetIn d t) = 
  on_free_vars_decl P d && on_free_vars (shiftnP 1 P) t.
Proof.
  destruct d as [na [b|] ty]; rewrite /mkProd_or_LetIn /on_free_vars_decl /test_decl /=
    ?andb_assoc /foroptb /=; try bool_congr.
Qed.

Lemma on_free_vars_ctx_all_term P ctx s :
  on_free_vars_ctx P ctx = on_free_vars P (it_mkProd_or_LetIn ctx (tSort s)).
Proof.
  rewrite /on_free_vars_ctx.
  rewrite -{2}[P](shiftnP0 P).
  generalize 0 as k.
  induction ctx using rev_ind; simpl; auto; intros k.
  rewrite List.rev_app_distr alli_app /= andb_true_r.
  rewrite IHctx it_mkProd_or_LetIn_app /= on_free_vars_mkProd_or_LetIn.
  now rewrite shiftnP_add.
Qed.

Definition on_free_vars_ctx_k P n ctx :=
  alli (fun k => (on_free_vars_decl (shiftnP k P))) n (List.rev ctx).

Definition predA {A} (p q : pred A) : simpl_pred A := 
  [pred i | p i ==> q i].

Definition eq_simpl_pred {A} (x y : simpl_pred A) := 
  `=1` x y.
  
Instance implP_Proper {A} : Proper (`=1` ==> `=1` ==> eq_simpl_pred) (@predA A).
Proof.
  intros f g Hfg f' g' Hfg' i; rewrite /predA /=.
  now rewrite Hfg Hfg'.
Qed.
  
Lemma on_free_vars_implP p q t : 
  predA p q =1 xpredT ->
  on_free_vars p t -> on_free_vars q t.
Proof.
  rewrite /predA /=. intros Hp.
  eapply on_free_vars_impl.
  intros i hp. specialize (Hp i). now rewrite /= hp in Hp.
Qed.

Definition shiftnP_predU n p q : 
  shiftnP n (predU p q) =1 predU (shiftnP n p) (shiftnP n q).
Proof.
  intros i.
  rewrite /shiftnP /predU /=.
  repeat nat_compare_specs => //.
Qed.

Instance orP_Proper {A} : Proper (`=1` ==> `=1` ==> eq_simpl_pred) (@predU A).
Proof.
  intros f g Hfg f' g' Hfg' i; rewrite /predU /=.
  now rewrite Hfg Hfg'.
Qed.

Instance andP_Proper A : Proper (`=1` ==> `=1` ==> eq_simpl_pred) (@predI A).
Proof.
  intros f g Hfg f' g' Hfg' i; rewrite /predI /=.
  now rewrite Hfg Hfg'.
Qed.

Instance pred_of_simpl_proper {A} : Proper (eq_simpl_pred ==> `=1`) (@PredOfSimpl.coerce A).
Proof.
  now move=> f g; rewrite /eq_simpl_pred => Hfg.
Qed.

Lemma orPL (p q : pred nat) : (predA p (predU p q)) =1 predT.
Proof.
  intros i. rewrite /predA /predU /=.
  rewrite (ssrbool.implybE (p i)).
  destruct (p i) => //.
Qed.


Lemma orPR (p q : nat -> bool) i : q i -> (predU p q) i.
Proof.
  rewrite /predU /= => ->; rewrite orb_true_r //.
Qed.

(** We need a disjunction here as the substitution can be made of 
    expanded lets (properly lifted) or just the variables of 
    [ctx] (lifted by [k]).
    
    The proof could certainly be simplified using a more high-level handling of
    free-variables predicate, which form a simple classical algebra. 
    To investigate: does ssr's library support this? *)

Lemma on_free_vars_extended_subst p k ctx :
  on_free_vars_ctx_k p k ctx ->
  forallb (on_free_vars 
    (predU (strengthenP 0 (context_assumptions ctx + k) (shiftnP k p)) 
      (occ_betweenP k (context_assumptions ctx))))
    (extended_subst ctx k).
Proof.
  rewrite /on_free_vars_ctx_k.
  induction ctx as [|[na [b|] ty] ctx] in p, k |- *; auto.
  - simpl. rewrite alli_app /= andb_true_r => /andP [] hctx.
    rewrite /on_free_vars_decl /test_decl /=; len => /andP [] hty /= hb.
    specialize (IHctx _ k hctx).
    rewrite IHctx // andb_true_r.
    eapply on_free_vars_subst => //.
    len. erewrite on_free_vars_implP => //; cycle 1.
    { erewrite on_free_vars_lift; eauto. }
    now rewrite shiftnP_predU /= shiftnP_strengthenP Nat.add_0_r shiftnP_add /= orPL.
  - cbn. rewrite alli_app /= andb_true_r => /andP [] hctx.
    rewrite /on_free_vars_decl /test_decl /= => hty.
    len in hty.
    specialize (IHctx p k).
    rewrite andb_idl.
    * move => _. rewrite /occ_betweenP. repeat nat_compare_specs => /= //.
    * specialize (IHctx hctx).
      rewrite (lift_extended_subst' _ 1).
      rewrite forallb_map.
      solve_all.
      apply on_free_vars_lift0.
      rewrite addnP_orP.
      eapply on_free_vars_implP; eauto.
      intros i. rewrite /predA /predU /=.
      rewrite /strengthenP /= /addnP /=.
      repeat nat_compare_specs => /= //.
      + rewrite /occ_betweenP /implb => /=.
        repeat nat_compare_specs => /= //.
      + rewrite /shiftnP /occ_betweenP /=.
        repeat nat_compare_specs => /= //.
        rewrite !orb_false_r.
        replace (i + 1 - S (context_assumptions ctx + k) - k) with
          (i - (context_assumptions ctx + k) - k) by lia.
        rewrite implybE. destruct p; auto. 
Qed.

Lemma on_free_vars_expand_lets_k P Γ n t : 
  n = context_assumptions Γ ->
  on_free_vars_ctx P Γ ->
  on_free_vars (shiftnP #|Γ| P) t ->
  on_free_vars (shiftnP n P) (expand_lets_k Γ 0 t).
Proof.
  intros -> HΓ Ht.
  rewrite /expand_lets_k /=.
  eapply on_free_vars_impl; cycle 1.
  - eapply on_free_vars_subst_gen.
    1:eapply on_free_vars_extended_subst; eauto.
    rewrite -> on_free_vars_lift. eauto.
  - len. rewrite /substP /= /strengthenP /=.
    intros i. simpl. rewrite /shiftnP.
    repeat nat_compare_specs => /= //.
    rewrite Nat.sub_0_r. rewrite /orP.
    replace (i + #|Γ| - context_assumptions Γ - #|Γ|) with (i - context_assumptions Γ) by lia.
    rewrite /occ_betweenP. repeat nat_compare_specs => /= //.
    rewrite orb_false_r Nat.sub_0_r.
    now rewrite orb_diag.
Qed.

Lemma on_free_vars_terms_inds P ind puinst bodies : 
  on_free_vars_terms P (inds ind puinst bodies).
Proof.
  rewrite /inds.
  induction #|bodies|; simpl; auto.
Qed.

Lemma on_free_vars_decl_map P f d :
  (forall i, on_free_vars P i = on_free_vars P (f i)) ->
  on_free_vars_decl P d = on_free_vars_decl P (map_decl f d).
Proof.
  intros Hi.
  rewrite /on_free_vars_decl /test_decl.
  rewrite Hi. f_equal.
  simpl. destruct (decl_body d) => //.
  now rewrite /foroptb /= (Hi t).
Qed.

Lemma on_free_vars_subst_instance_context P u Γ :
  on_free_vars_ctx P (subst_instance u Γ) = on_free_vars_ctx P Γ.
Proof.
  rewrite /on_free_vars_ctx.
  rewrite /subst_instance -map_rev alli_map.
  apply alli_ext => i d.
  symmetry. apply on_free_vars_decl_map.
  intros. apply on_free_vars_subst_instance.
Qed.

Lemma on_free_vars_map2_cstr_args p bctx ctx :
  #|bctx| = #|ctx| ->
  on_free_vars_ctx p ctx =
  on_free_vars_ctx p (map2 set_binder_name bctx ctx).
Proof.
  rewrite /on_free_vars_ctx.
  induction ctx as [|d ctx] in bctx |- *; simpl; auto.
  - destruct bctx; reflexivity.
  - destruct bctx => /= //.
    intros [= hlen].
    rewrite alli_app (IHctx bctx) // alli_app. f_equal.
    len. rewrite map2_length // hlen. f_equal.
Qed.


Lemma on_free_vars_to_extended_list P ctx : 
  forallb (on_free_vars (shiftnP #|ctx| P)) (to_extended_list ctx).
Proof.
  rewrite /to_extended_list /to_extended_list_k.
  change #|ctx| with (0 + #|ctx|).
  have: (forallb (on_free_vars (shiftnP (0 + #|ctx|) P)) []) by easy.
  generalize (@nil term), 0.
  induction ctx; intros l n.
  - simpl; auto.
  - simpl. intros Hl.
    destruct a as [? [?|] ?].
    * rewrite Nat.add_succ_r in Hl.
      specialize (IHctx _ (S n) Hl).
      now rewrite Nat.add_succ_r Nat.add_1_r.
    * rewrite Nat.add_succ_r Nat.add_1_r. eapply (IHctx _ (S n)).
      rewrite -[_ + _](Nat.add_succ_r n #|ctx|) /= Hl.
      rewrite /shiftnP.
      nat_compare_specs => /= //.
Qed.

(** This is less precise than the strengthenP lemma above *)
Lemma on_free_vars_lift_impl (p : nat -> bool) (n k : nat) (t : term) :
  on_free_vars (shiftnP k p) t ->
  on_free_vars (shiftnP (n + k) p) (lift n k t).
Proof.
  rewrite -(on_free_vars_lift _ n k t).
  eapply on_free_vars_impl.
  intros i.
  rewrite /shiftnP /strengthenP.
  repeat nat_compare_specs => /= //.
  now replace (i - n - k) with (i - (n + k)) by lia.
Qed.


Lemma foron_free_vars_extended_subst brctx p :
  on_free_vars_ctx p brctx ->
  forallb (on_free_vars (shiftnP (context_assumptions brctx) p))
    (extended_subst brctx 0).
Proof.
  move/on_free_vars_extended_subst.
  eapply forallb_impl.
  intros x hin.
  rewrite Nat.add_0_r shiftnP0.
  eapply on_free_vars_impl.
  intros i. rewrite /orP /strengthenP /= /occ_betweenP /shiftnP.
  repeat nat_compare_specs => /= //.
  now rewrite orb_false_r.
Qed.

From MetaCoq.PCUIC Require Import PCUICReduction.

Lemma on_free_vars_fix_subst P mfix idx :
  on_free_vars P (tFix mfix idx) ->
  forallb (on_free_vars P) (fix_subst mfix).
Proof.
  move=> /=; rewrite /fix_subst.
  intros hmfix. generalize hmfix.
  induction mfix at 2 4; simpl; auto.
  move/andP => [ha hm]. rewrite IHm // andb_true_r //.
Qed.

Lemma on_free_vars_unfold_fix P mfix idx narg fn :
  unfold_fix mfix idx = Some (narg, fn) ->
  on_free_vars P (tFix mfix idx) ->
  on_free_vars P fn.
Proof.
  rewrite /unfold_fix. 
  destruct nth_error eqn:hnth => // [=] _ <- /=.
  intros hmfix; generalize hmfix.
  move/forallb_All/(nth_error_all hnth) => /andP [] _ Hbody.
  eapply on_free_vars_subst; len => //.
  eapply (on_free_vars_fix_subst _ _ idx) => //.
Qed.

Lemma on_free_vars_cofix_subst P mfix idx :
  on_free_vars P (tCoFix mfix idx) ->
  forallb (on_free_vars P) (cofix_subst mfix).
Proof.
  move=> /=; rewrite /cofix_subst.
  intros hmfix. generalize hmfix.
  induction mfix at 2 4; simpl; auto.
  move/andP => [ha hm]. rewrite IHm // andb_true_r //.
Qed.

Lemma on_free_vars_unfold_cofix P mfix idx narg fn :
  unfold_cofix mfix idx = Some (narg, fn) ->
  on_free_vars P (tCoFix mfix idx) ->
  on_free_vars P fn.
Proof.
  rewrite /unfold_cofix. 
  destruct nth_error eqn:hnth => // [=] _ <- /=.
  intros hmfix; generalize hmfix.
  move/forallb_All/(nth_error_all hnth) => /andP [] _ Hbody.
  eapply on_free_vars_subst; len => //.
  eapply (on_free_vars_cofix_subst _ _ idx) => //.
Qed.

Lemma addnP_shiftnP_comm n (P : nat -> bool) : P 0 -> addnP 1 (shiftnP n P) =1 shiftnP n (addnP 1 P).
Proof.
  intros p0 i; rewrite /addnP /shiftnP /=.
  repeat nat_compare_specs => /= //. 
  - assert (n = i + 1) as -> by lia.
    now replace (i + 1 - (i + 1)) with 0 by lia.
  - lia_f_equal.
Qed.

Lemma on_ctx_free_vars_concat P Γ Δ : 
  on_ctx_free_vars P Γ ->
  on_ctx_free_vars (shiftnP #|Δ| P) Δ ->  
  on_ctx_free_vars (shiftnP #|Δ| P) (Γ ,,, Δ).
Proof.
  rewrite /on_ctx_free_vars alli_app.
  move=> hΓ -> /=; rewrite alli_shiftn.
  eapply alli_impl; tea => i d /=.
  simpl.
  rewrite {1}/shiftnP. nat_compare_specs.
  replace (#|Δ| + i - #|Δ|) with i by lia.
  destruct (P i) eqn:pi => /= //.
  apply on_free_vars_decl_impl => k.
  rewrite /addnP /shiftnP.
  nat_compare_specs.
  now replace (k + S (#|Δ| + i) - #|Δ|) with (k + S i) by lia.
Qed.

Lemma on_ctx_free_vars_tip P d : on_ctx_free_vars P [d] = P 0 ==> on_free_vars_decl (addnP 1 P) d.
Proof.
  now rewrite /on_ctx_free_vars /= /= andb_true_r.
Qed.

Lemma shiftnPS n P : shiftnP (S n) P n.
Proof.
  rewrite /shiftnP /=.
  now nat_compare_specs.
Qed.

Lemma on_ctx_free_vars_extend P Γ Δ :
  on_free_vars_ctx P Δ ->
  on_ctx_free_vars P Γ ->
  on_ctx_free_vars (shiftnP #|Δ| P) (Γ ,,, Δ).
Proof.
  intros hΔ hΓ.
  apply on_ctx_free_vars_concat => //.
  revert P Γ hΓ hΔ.
  induction Δ using rev_ind; simpl; auto; intros P Γ hΓ.
  rewrite /on_ctx_free_vars /on_free_vars_ctx List.rev_app_distr /= shiftnP0.
  rewrite alli_shift. setoid_rewrite Nat.add_comm. setoid_rewrite <- shiftnP_add.
  move/andP=> [] hx hΔ.
  rewrite alli_app /= andb_true_r Nat.add_0_r; len.
  rewrite Nat.add_comm.
  rewrite addnP_shiftnP.
  specialize (IHΔ (shiftnP 1 P) (Γ ,, x)).
  forward IHΔ.
  * simpl. apply (on_ctx_free_vars_concat _ _ [x]) => //.
    simpl.
    now rewrite on_ctx_free_vars_tip {1}/shiftnP /= addnP_shiftnP.
  * specialize (IHΔ hΔ).
    rewrite shiftnPS /= hx andb_true_r.
    rewrite /on_ctx_free_vars in IHΔ.
    rewrite -(Nat.add_1_r #|Δ|).
    setoid_rewrite <-(shiftnP_add).
    now setoid_rewrite <- (shiftnP_add _ _ _ _).
Qed.

Lemma on_free_vars_fix_context P mfix : 
  All (fun x : def term =>
      test_def (on_free_vars P) (on_free_vars (shiftnP #|mfix| P)) x)
      mfix ->
  on_free_vars_ctx P (fix_context mfix).
Proof.
  intros a.
  assert (All (fun x => on_free_vars P x.(dtype)) mfix).
  { solve_all. now move/andP: H=> []. } clear a.
  induction mfix using rev_ind; simpl; auto.
  rewrite /fix_context /= mapi_app List.rev_app_distr /=.
  rewrite /on_free_vars_ctx /= alli_app. len.
  rewrite andb_true_r.
  eapply All_app in X as [X Hx].
  depelim Hx. clear Hx.
  specialize (IHmfix X).
  rewrite /on_free_vars_ctx in IHmfix.
  rewrite IHmfix /= /on_free_vars_decl /test_decl /= /=.
  apply on_free_vars_lift0.
  now rewrite addnP_shiftnP.
Qed.

Lemma test_context_k_on_free_vars_ctx P ctx :
  test_context_k (fun k => on_free_vars (shiftnP k P)) 0 ctx =
  on_free_vars_ctx P ctx.
Proof.
  now rewrite test_context_k_eq.
Qed.

(** This shows preservation by reduction of closed/noccur_between predicates 
  necessary to prove exchange and strengthening lemmas. *)
Lemma red1_on_free_vars {cf} {P : nat -> bool} {Σ Γ u v} {wfΣ : wf Σ} :
  on_free_vars P u ->
  on_ctx_free_vars P Γ ->
  red1 Σ Γ u v ->
  on_free_vars P v.
Proof.
  intros hav hctx h.
  induction h using red1_ind_all in P, hav, hctx |- *.
  all: try solve [
    simpl ; constructor ; eapply IHh ;
    try (simpl in hav; rtoProp);
    try eapply urenaming_vass ;
    try eapply urenaming_vdef ;
    assumption
  ].
  all:simpl in hav |- *; try toAll.
  all:try move/and3P: hav => [h1 h2 h3].
  all:try (move/andP: hav => [] /andP [] h1 h2 h3).
  all:try move/andP: hav => [h1 h2].
  all:try move/andP: h3 => [] h3 h4.
  all:try move/andP: h4 => [] h4 h5.
  all:try rewrite ?h1 // ?h2 // ?h3 // ?h4 // ?IHh /= // ?andb_true_r.
  all:try eapply on_free_vars_subst1; eauto.
  - destruct (nth_error Γ i) eqn:hnth => //.
    simpl in H. noconf H.
    epose proof (nth_error_on_free_vars_ctx P 0 Γ i c).
    forward H0. { now rewrite addnP0. }
    specialize (H0 hav hnth). simpl in H0.
    rewrite /test_decl H in H0.
    rewrite on_free_vars_lift0 //.
    now move/andP: H0 => [] /=.
  - rewrite /iota_red.
    rename h5 into hbrs.
    move: h4. rewrite on_free_vars_mkApps => /andP [] /= _ hargs.
    apply on_free_vars_subst.
    { rewrite forallb_skipn //. }
    rewrite H0.
    rewrite /expand_lets /expand_lets_k /=.
    eapply forallb_nth_error in hbrs.
    erewrite H in hbrs; simpl in hbrs.
    move/andP: hbrs => [] hbr hbody.
    eapply on_free_vars_subst.
    * eapply foron_free_vars_extended_subst; eauto.
      now rewrite test_context_k_on_free_vars_ctx in hbr.
    * rewrite extended_subst_length.
      rewrite shiftnP_add.
      eapply on_free_vars_lift_impl in hbody.
      now rewrite Nat.add_comm.
  - rewrite !on_free_vars_mkApps in hav |- *.
    rtoProp.
    eapply on_free_vars_unfold_fix in H; eauto. 
  - move: h4; rewrite !on_free_vars_mkApps.
    move=> /andP [] hcofix ->.
    eapply on_free_vars_unfold_cofix in hcofix; eauto.
    now rewrite hcofix.
  - move: hav; rewrite !on_free_vars_mkApps => /andP [] hcofix ->.
    eapply on_free_vars_unfold_cofix in H as ->; eauto.
  - eapply closed_on_free_vars. rewrite closedn_subst_instance.
    eapply declared_constant_closed_body; eauto.
  - move: hav; rewrite on_free_vars_mkApps /=.
    now move/(nth_error_forallb H).
  - rewrite (on_ctx_free_vars_concat _ _ [_]) // /=
      on_ctx_free_vars_tip /= addnP_shiftnP /on_free_vars_decl
      /test_decl /= //.
  - rewrite (on_ctx_free_vars_concat _ _ [_]) //
      on_ctx_free_vars_tip /= addnP_shiftnP /on_free_vars_decl /test_decl /= h2 /=
      /foroptb /= h1 //.
  - solve_all.
    eapply OnOne2_impl_All_r; eauto. solve_all.
  - eapply on_ctx_free_vars_extend => //.
    now rewrite test_context_k_on_free_vars_ctx in h3.
  - toAll.
    clear -hctx X h5.
    eapply OnOne2_All_mix_left in X; tea.
    toAll. eapply OnOne2_impl_All_r in X; tea; solve_all; rewrite -b0 //.
    eapply b1 => //.
    rewrite test_context_k_on_free_vars_ctx in H0.
    eapply on_ctx_free_vars_extend => //.
  - rewrite (on_ctx_free_vars_concat _ _ [_]) // /=
      on_ctx_free_vars_tip /= addnP_shiftnP /on_free_vars_decl /test_decl /= h1 /= //.
  - toAll. eapply OnOne2_impl_All_r; eauto; solve_all.
  - toAll. unfold test_def.
    rewrite -(OnOne2_length X).
    eapply OnOne2_impl_All_r; eauto; solve_all.
    destruct x, y; noconf b; simpl in *. rtoProp; solve_all.
  - toAll. unfold test_def in *. rewrite -(OnOne2_length X).
    eapply OnOne2_impl_All_r; eauto; solve_all;
     destruct x, y; noconf b; simpl in *; rtoProp; solve_all.
    apply b0 => //.
    rewrite -(fix_context_length mfix0).
    eapply on_ctx_free_vars_extend => //.
    now apply on_free_vars_fix_context.
  - toAll. unfold test_def.
    rewrite -(OnOne2_length X).
    eapply OnOne2_impl_All_r; eauto; solve_all.
    destruct x, y; noconf b; simpl in *. rtoProp; solve_all.
  - toAll. unfold test_def in *. rewrite -(OnOne2_length X).
    eapply OnOne2_impl_All_r; eauto; solve_all;
    destruct x, y; noconf b; simpl in *; rtoProp; solve_all.
    apply b0 => //.
    rewrite -(fix_context_length mfix0).
    eapply on_ctx_free_vars_extend => //.
    now apply on_free_vars_fix_context.
Qed.

(* Not necessary for the above lemma, but still useful at some point presumably,
   e.g. for strenghtening *)

Lemma on_free_vars_case_predicate_context {cf} {Σ} {wfΣ : wf Σ} {P ci mdecl idecl p} :
  let pctx := case_predicate_context ci mdecl idecl p in
  declared_inductive Σ ci mdecl idecl ->
  wf_predicate mdecl idecl p ->
  forallb (on_free_vars P) (pparams p) ->
  on_free_vars (shiftnP #|pcontext p| P) (preturn p) ->
  on_free_vars_ctx P pctx.
Proof.
  intros pctx decli wfp wfb havp.
  rewrite /pctx /case_predicate_context /case_predicate_context_gen.
  set (ibinder := {| decl_name := _ |}).
  rewrite -on_free_vars_map2_cstr_args /=; len.
  { eapply (wf_predicate_length_pcontext wfp). }
  rewrite alli_app; len; rewrite andb_true_r.
  apply andb_true_iff. split.
  - rewrite -/(on_free_vars_ctx P _).
    rewrite (on_free_vars_ctx_all_term _ _ Universe.type0).
    rewrite -(subst_it_mkProd_or_LetIn _ _ _ (tSort _)).
    apply on_free_vars_subst => //.
    rewrite -on_free_vars_ctx_all_term.
    rewrite on_free_vars_subst_instance_context.
    rewrite (on_free_vars_ctx_all_term _ _ (Universe.type0)).
    rewrite -(expand_lets_it_mkProd_or_LetIn _ _ 0 (tSort _)).
    eapply on_free_vars_expand_lets_k; len.
    * rewrite (wf_predicate_length_pars wfp).
      apply (declared_minductive_ind_npars decli).
    * eapply closed_ctx_on_free_vars.
      apply (declared_inductive_closed_params decli).
    * eapply on_free_vars_impl; cycle 1.
      { rewrite <- on_free_vars_ctx_all_term.
        instantiate (1 := closedP #|mdecl.(ind_params)| xpredT).
        eapply closedn_ctx_on_free_vars.
        move: (declared_inductive_closed_pars_indices wfΣ decli).
        now rewrite closedn_ctx_app => /andP []. }
       intros i'.
      rewrite /substP /= /closedP /shiftnP. len.
      now repeat nat_compare_specs => /= //.
  - rewrite /on_free_vars_decl /ibinder /test_decl /= /foroptb /=.
    rewrite on_free_vars_mkApps /= forallb_app /=.
    rewrite on_free_vars_to_extended_list /= andb_true_r.
    rewrite -/(is_true _).
    rewrite forallb_map. unshelve eapply (forallb_impl _ _ _ _ wfb).
    intros. simpl.
    eapply on_free_vars_lift0. now rewrite addnP_shiftnP.
Qed.

Lemma on_free_vars_case_branch_context {cf} {Σ} {wfΣ : wf Σ} {P ci i mdecl idecl p br cdecl} :
  let brctx := case_branch_context ci mdecl p (forget_types (bcontext br)) cdecl in
  declared_constructor Σ (ci, i) mdecl idecl cdecl ->
  wf_predicate mdecl idecl p ->
  wf_branch cdecl br ->
  forallb (on_free_vars P) (pparams p) ->
  on_free_vars_ctx P brctx.
Proof.
  intros brctx decli wfp wfb havp.
  rewrite /brctx /case_branch_context /case_branch_context_gen.
  rewrite (on_free_vars_ctx_all_term _ _ Universe.type0).
  rewrite -(subst_it_mkProd_or_LetIn _ _ _ (tSort _)).
  apply on_free_vars_subst => //.
  rewrite -(expand_lets_it_mkProd_or_LetIn _ _ 0 (tSort _)).
  eapply on_free_vars_expand_lets_k; len.
  * rewrite (wf_predicate_length_pars wfp).
    apply (declared_minductive_ind_npars decli).
  * eapply closed_ctx_on_free_vars.
    rewrite closedn_subst_instance_context.
    apply (declared_inductive_closed_params decli).
  * rewrite -(subst_it_mkProd_or_LetIn _ _ _ (tSort _)).
    eapply on_free_vars_impl; cycle 1.
    + eapply (on_free_vars_subst_gen _ P).
      { eapply on_free_vars_terms_inds. }
      rewrite -on_free_vars_ctx_all_term.
      rewrite on_free_vars_subst_instance_context.
      rewrite -on_free_vars_map2_cstr_args.
      { len. apply (wf_branch_length wfb). }
      instantiate (1 := closedP (#|mdecl.(ind_bodies)| + #|mdecl.(ind_params)|) xpredT).
      eapply closedn_ctx_on_free_vars.
      now move/andP: (declared_constructor_closed wfΣ decli) => [] /andP [].
    + intros i'.
      rewrite /substP /= /closedP /shiftnP. len.
      now repeat nat_compare_specs => /= //.
Qed.


(*
Lemma typing_on_free_vars : env_prop
  (fun Σ Γ t A =>
    forall P,
    on_free_vars (closedP #|Γ| P) t ->
    ∑ Af, (red Σ Γ A Af * on_free_vars (closedP #|Γ| P) Af))
   (fun Σ Γ =>
   All_local_env
   (lift_typing (fun (Σ : global_env_ext) (Γ : context) (t T : term)
    =>
    forall P,
    on_free_vars (closedP #|Γ| P) t ->
    ∑ Af, (red1 Σ Γ T Af * on_free_vars (closedP #|Γ| P) Af)) Σ) Γ).
Proof.
  
  apply typing_ind_env.
  7:{
    - intros Σ wfΣ Γ wfΓ t na A B a u X hty ihty ht iht hu ihu P.
      simpl. move/andP=> [havt havs].
      destruct (iht _ havt) as [ty [redty hav]].
      eapply invert_red_prod in redty as [A' [B' [[eq redA] redB]]]. subst ty.
      move: hav => /= /andP [hA' hB'].
      eexists (B' {0 := a}); split. 1:admit.
      eapply on_free_vars_subst=> /=; rewrite ?havs //. }
  2:{ - intros Σ wfΣ Γ wfΓ n decl isdecl ihΓ P.
        simpl in * => hn.
        eexists; split; eauto.
        eapply (nth_error_All_local_env (n:=n)) in ihΓ.
        2:{ eapply nth_error_Some_length in isdecl; eauto. }
        rewrite isdecl in ihΓ. simpl in ihΓ. rewrite /closedP in hn.
        move: hn; nat_compare_specs => //. intros pn.
        move: ihΓ. unfold on_local_decl. 
        destruct decl_body eqn:db;
        unfold lift_typing; simpl.
        * intros ih. specialize (ih P).
          rewrite skipn_length // in ih.
          rewrite on_free_vars_lift0 //.
          admit.
        * admit. }

  13:{
    - intros Σ wfΣ Γ wfΓ t A B X hwf ht iht htB ihB cum P hav.
      specialize (iht _ hav) as [Af [redAf havaf]].
      admit. (* certainly provable *)
  }
Admitted.*)

(* 
Lemma typing_rename_prop' : env_prop
  (fun Σ Γ t A =>
    forall Δ f,
    renaming (closedP #|Γ| xpredT) Σ Δ Γ f ->
    Σ ;;; Δ |- rename f t : rename f A)
   (fun Σ Γ =>
   All_local_env
   (lift_typing (fun (Σ : global_env_ext) (Γ : context) (t T : term)
    =>
    forall P (Δ : PCUICEnvironment.context) (f : nat -> nat),
    renaming (closedP #|Γ| P) Σ Δ Γ f -> 
    Σ;;; Δ |- rename f t : rename f T) Σ) Γ).
Proof.
  red. intros.
  destruct (typing_rename_prop Σ wfΣ Γ t T ty) as [? []].
  split.
  - eapply on_global_env_impl. 2:eapply f.
    intros.
    red in X0. destruct T0; red.
    * intros.
      eapply (X0 xpredT).
      


  destruct X. *)