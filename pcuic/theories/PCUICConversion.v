(* Distributed under the terms of the MIT license. *)
From Coq Require Import ssreflect ssrbool.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils PCUICCases PCUICLiftSubst PCUICTyping
     PCUICSubstitution PCUICPosition PCUICCumulativity PCUICReduction
     PCUICConfluence PCUICClosed PCUICParallelReductionConfluence PCUICEquality
     PCUICSigmaCalculus PCUICContextReduction
     PCUICContextConversion PCUICWeakening PCUICUnivSubst
     PCUICWellScopedCumulativity PCUICUnivSubstitution
.

Require Import CRelationClasses.
Require Import Equations.Type.Relation Equations.Type.Relation_Properties.
Require Import Equations.Prop.DepElim.

Set Default Goal Selector "!".

Ltac pcuic := intuition eauto 5 with pcuic ||
  (try solve [repeat red; cbn in *; intuition auto; eauto 5 with pcuic || (try lia || congruence)]).

Hint Resolve eq_universe_leq_universe' : pcuic.

Derive Signature for conv cumul assumption_context.
Derive Signature for clos_refl_trans_1n.

(* todo move *)
Lemma All2_refl {A} {P : A -> A -> Type} l :
  (forall x, P x x) ->
  All2 P l l.
Proof.
  intros HP. induction l; constructor; auto.
Qed.

Section EquivalenceConvCumulDefs.

  Context {cf:checker_flags} (Σ : global_env_ext) (wfΣ : wf Σ) (Γ : closed_context).
  (** We need conv1 to be defined on closed terms *)
  (*Proposition conv_conv1 (M N : open_term Γ) :
    conv1 Σ Γ M N <~> conv Σ Γ M N.
  Proof.
    split; intro H.
    - destruct M as [M HM], N as [N HN].
      cbn in H |- *.
      induction H in HM, HN |- *.
      + destruct r as [[r|r]|r].
        * eapply red_conv; eauto.
        * now econstructor 3; tea.
        * now constructor.
      + reflexivity.
      + eapply ws_equality_trans. conv_trans. etransitivity; tea.
    - induction H.
      + constructor. now right.
      + etransitivity; tea.
        constructor. left. now left.
      + etransitivity; tea.
        constructor. left. now right.
  Qed.


  Proposition cumul_cumul1 M N :
    cumul1 Σ Γ M N <~> cumul Σ Γ M N.
  Proof.
    split; intro H.
    - induction H.
      + destruct r as [[r|r]|r].
        * eapply red_cumul; eauto.
        * now econstructor 3; tea.
        * now constructor.
      + reflexivity.
      + etransitivity; tea.
    - induction H.
      + constructor. now right.
      + etransitivity; tea.
        constructor. left. now left.
      + etransitivity; tea.
        constructor. left. now right.
  Qed.*)

End EquivalenceConvCumulDefs.

(* TODO MOVE *)
Fixpoint isFixApp t : bool :=
  match t with
  | tApp f u => isFixApp f
  | tFix mfix idx => true
  | _ => false
  end.

(* TODO MOVE *)
Lemma isFixApp_mkApps :
  forall t l,
    isFixApp (mkApps t l) = isFixApp t.
Proof.
  intros t l. induction l in t |- *.
  - cbn. reflexivity.
  - cbn. rewrite IHl. reflexivity.
Qed.

Import PCUICOnFreeVars.

Lemma on_fvs_prod {n na M1 M2} : 
  on_free_vars (shiftnP n xpred0) (tProd na M1 M2) = 
  on_free_vars (shiftnP n xpred0) M1 &&
  on_free_vars (shiftnP (S n) xpred0) M2.
Proof. cbn. rewrite shiftnP_add. reflexivity. Qed.

Lemma on_fvs_lambda {n na M1 M2} : 
  on_free_vars (shiftnP n xpred0) (tLambda na M1 M2) = 
  on_free_vars (shiftnP n xpred0) M1 &&
  on_free_vars (shiftnP (S n) xpred0) M2.
Proof. cbn. rewrite shiftnP_add. reflexivity. Qed.

Lemma on_fvs_letin {n na M1 M2 M3} : 
  on_free_vars (shiftnP n xpred0) (tLetIn na M1 M2 M3) = 
  [&& on_free_vars (shiftnP n xpred0) M1,
  on_free_vars (shiftnP n xpred0) M2 &
  on_free_vars (shiftnP (S n) xpred0) M3].
Proof. cbn. rewrite shiftnP_add. reflexivity. Qed.

Lemma on_free_vars_shiftnP_S (ctx : context) t d :
  on_free_vars (shiftnP #|ctx ,, d| xpred0) t ->
  on_free_vars (shiftnP (S #|ctx|) xpred0) t.
Proof.
  now len.
Qed.

Lemma is_open_term_closed (Γ : context) t :
  closedn #|Γ| t = is_open_term Γ t.
Proof.
  rewrite closedP_on_free_vars.
  eapply on_free_vars_ext.
  now rewrite PCUICConfluence.closedP_shiftnP.
Qed.

Lemma is_closed_ctx_closed (Γ : context) :
  closed_ctx Γ = is_closed_context Γ.
Proof.
  rewrite closedn_ctx_on_free_vars //.
Qed.

Hint Rewrite is_open_term_closed is_closed_ctx_closed : fvs.

Hint Resolve on_free_vars_shiftnP_S : fvs.
Hint Rewrite @on_fvs_prod @on_fvs_lambda @on_fvs_letin : fvs.
Hint Rewrite @on_free_vars_ctx_snoc : fvs.
Hint Extern 4 => progress autorewrite with fvs : fvs.
Hint Resolve closed_red_open_right : fvs.

Ltac fvs := eauto 10 with fvs.

Section ConvCongruences.
  Context {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ}.
  
  Lemma into_closed_red {Γ t u} :
    red Σ Γ t u ->
    is_closed_context Γ ->
    is_open_term Γ t ->
    Σ ;;; Γ ⊢ t ⇝ u.
  Proof.
    now constructor.
  Qed.

  Lemma congr_prod_l {Γ na na' M1 M2 N1 le} :
    eq_binder_annot na na' ->
    is_open_term (Γ ,, vass na M1) M2 ->
    Σ ;;; Γ ⊢ M1 = N1 ->
    Σ ;;; Γ ⊢ (tProd na M1 M2) ≤[le] (tProd na' N1 M2).
  Proof.
    intros.
    eapply equality_red in X as (dom & dom' & rdom & rdom' & eqdom); tea.
    eapply equality_red.
    exists (tProd na dom M2), (tProd na' dom' M2).
    split; [|split]; auto.
    - eapply into_closed_red; [eapply red_prod|..]; eauto with fvs.
    - eapply into_closed_red; [eapply red_prod|..]; eauto with fvs.
    - destruct le; (constructor; [assumption|try apply eqdom|try reflexivity]).
  Qed.

  Lemma congr_prod {Γ na na'} {M1 M2 N1 N2} le :
    eq_binder_annot na na' ->
    Σ ;;; Γ ⊢ M1 = N1 ->
    Σ ;;; (Γ ,, vass na M1) ⊢ M2 ≤[le] N2 ->
    Σ ;;; Γ ⊢ (tProd na M1 M2) ≤[le] (tProd na' N1 N2).
  Proof.
    intros * ? ? ?.
    transitivity (tProd na' N1 M2).
    - eapply congr_prod_l; eauto with fvs.
    - eapply (equality_equality_ctx (le':=false) (Γ' := Γ ,, vass na' N1)) in X0.
      2:{ constructor. 1:{ eapply closed_context_equality_refl; eauto with fvs. }
          constructor; auto. 1:now symmetry. now symmetry. }
      eapply equality_red in X0 as (codom & codom' & rcodom & rcodom' & eqcodom).
      eapply equality_red.
      exists (tProd na' N1 codom), (tProd na' N1 codom').
      split; [|split].
      + eapply into_closed_red; [eapply red_prod|..]; fvs.
      + eapply into_closed_red; [eapply red_prod|..]; fvs.
      + destruct le; (constructor; auto); reflexivity.
  Qed.

  Lemma equality_Sort_inv {Γ s s'} le :
    Σ ;;; Γ ⊢ tSort s ≤[le] tSort s' ->
    compare_universe le Σ s s'.
  Proof.
    intros H; depind H.
    - destruct le; now inversion c.
    - depelim r. solve_discr.
    - depelim r. solve_discr.
  Qed.

  Lemma cumul_Sort_Prod_inv {Γ s na dom codom} le :
    Σ ;;; Γ ⊢ tSort s ≤[le] tProd na dom codom ->
    False.
  Proof.
    intros H. depind H.
    - destruct le; now inversion c.
    - depelim r. solve_discr.
    - depelim r; solve_discr.
      + eapply IHws_equality. reflexivity.
      + eapply IHws_equality. reflexivity.
  Qed.

  Lemma cumul_Prod_Sort_inv {Γ s na dom codom} :
    Σ ;;; Γ ⊢ tProd na dom codom ≤ tSort s -> False.
  Proof.
    intros H; depind H; auto.
    - now inversion c.
    - depelim r.
      + solve_discr.
      + eapply IHws_equality; reflexivity.
      + eapply IHws_equality; reflexivity.
    - depelim r. solve_discr.
  Qed.

  Lemma eq_universe_leq_universe u v : 
    eq_universe Σ u v -> leq_universe Σ u v.
  Proof.
    now eapply eq_universe_leq_universe.
  Qed.
  Hint Resolve eq_universe_leq_universe : core.

  Lemma cumul_Sort_l_inv {Γ s T} le :
    Σ ;;; Γ ⊢ tSort s ≤[le] T ->
    ∑ s', Σ ;;; Γ ⊢ T ⇝ tSort s' × compare_universe le Σ s s'.
  Proof.
    intros H. depind H.
    - destruct le; inversion c; eauto using into_closed_red.
    - depelim r. solve_discr.
    - destruct IHws_equality as [s' [redv leq]].
      exists s'. split; auto. eapply into_closed_red; tea.
      eapply red_step with v; eauto with fvs.
  Qed.


  Lemma cumul_Sort_r_inv {Γ s T} le :
    Σ ;;; Γ ⊢ T ≤[le] tSort s ->
    ∑ s', Σ ;;; Γ ⊢ T ⇝ tSort s' × compare_universe le Σ s' s.
  Proof.
    intros H. depind H.
    - destruct le; inversion c; eauto using into_closed_red.
    - destruct IHws_equality as [s' [redv leq]].
      exists s'. split; auto. eapply into_closed_red; tea.
      eapply red_step with v; eauto with fvs.
    - depelim r. solve_discr.
  Qed.
  
  (* #[global]
  Instance red_decls_refl Γ Δ : Reflexive (red_decls Σ Γ Δ).
  Proof.
    intros x. apply red_decls_refl.
  Qed.

  #[global]
  Instance red_ctx_refl : Reflexive (All2_fold (fun Γ _ => All_decls (closed_red Σ Γ))).
  Proof.
    intros x. eapply All2_fold_refl. intros. apply All_decls_refl.
  Qed. *)
  
  (* Lemma clos_rt_monotone_hetero {A B} (R : relation A) (S : relation B) (f : A -> B) :
    (forall x y, R x y -> on_Trel S f x y) ->
    (forall x y, R x y -> inclusion (clos_refl_trans R) (clos_refl_trans S). *)

  Notation "( x | y )" := (exist x y).

  Lemma closed_red_clos {Γ t u} :
    closed_red Σ Γ t u ->
    clos_refl_trans (closed_red1 Σ Γ) t u.
  Proof.
    intros [clΓ clt r].
    assert (clu := red_on_free_vars r clt byfvs).
    unshelve eapply (red_ws_red _ (Γ | clΓ) (exist t byfvs) (exist u byfvs)) in r; cbn; eauto with fvs.
    depind r. all:try solve [econstructor; split; eauto with fvs].
    destruct y as [y hy]; econstructor 3; [eapply IHr1|eapply IHr2]; reflexivity.
  Qed.

  Lemma on_free_vars_subst {Γ Γ' : context} {s b} : 
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    on_free_vars (shiftnP (#|Γ| + #|s| + #|Γ'|) xpred0) b ->
    on_free_vars (shiftnP (#|Γ'| + #|Γ|) xpred0) (subst s #|Γ'| b).
  Proof.
    intros.
    eapply on_free_vars_impl.
    2:eapply on_free_vars_subst_gen; tea.
    intros i.
    rewrite /substP /shiftnP !orb_false_r.
    repeat nat_compare_specs => //. cbn.
    repeat nat_compare_specs => //.
  Qed.

  Lemma is_closed_subst_context Γ Δ s Γ' :
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    #|s| = #|Δ| ->
    is_closed_context (Γ,,, subst_context s 0 Γ').
  Proof.
    rewrite !on_free_vars_ctx_app.
    move/andP => [] /andP[] -> /= onΔ onΓ' ons Hs.
    apply on_free_vars_ctx_subst_context.
    * rewrite shiftnP_add Hs. now len in onΓ'.
    * eapply All_forallb. solve_all; eauto with fvs.
  Qed.

  Lemma is_open_term_subst_gen {Γ Δ Γ' s s' b} :
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s' ->
    #|s| = #|Δ| -> #|s| = #|s'| ->
    is_open_term (Γ,,, Δ,,, Γ') b ->
    is_open_term (Γ,,, subst_context s 0 Γ') (subst s' #|Γ'| b).
  Proof.
    len; intros. apply on_free_vars_subst. 1:solve_all; eauto with fvs.
    len in H2. rewrite -H3 H2.
    red. rewrite -H4; lia_f_equal.
  Qed.

  Lemma is_open_term_subst {Γ Δ Γ' s b} :
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    #|s| = #|Δ| ->
    is_open_term (Γ,,, Δ,,, Γ') b ->
    is_open_term (Γ,,, subst_context s 0 Γ') (subst s #|Γ'| b).
  Proof.
    intros. now eapply is_open_term_subst_gen; tea.
  Qed.

  Lemma closed_red_red_subst {Γ Δ Γ' s s' b} : 
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    All2 (closed_red Σ Γ) s s' ->
    untyped_subslet Γ s Δ ->
    is_open_term (Γ ,,, Δ ,,, Γ') b ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| b ⇝ subst s' #|Γ'| b.
  Proof.
    intros.
    split; eauto with fvs.
    - eapply is_closed_subst_context; tea. 1:solve_all; eauto with fvs.
      now rewrite (untyped_subslet_length X0).
    - eapply is_open_term_subst; tea.
      1:solve_all; eauto with fvs.
      now rewrite (untyped_subslet_length X0).
    - eapply red_red; tea; eauto with fvs.
      * solve_all. exact X.
      * solve_all. len.
        rewrite Nat.add_assoc -shiftnP_add addnP_shiftnP; eauto with fvs.
  Qed.

  Lemma closed_red_red_subst0 {Γ Δ s s' b} : 
    is_closed_context (Γ ,,, Δ) ->
    All2 (closed_red Σ Γ) s s' ->
    untyped_subslet Γ s Δ ->
    is_open_term (Γ ,,, Δ) b ->
    Σ ;;; Γ ⊢ subst0 s b ⇝ subst0 s' b.
  Proof.
    intros. eapply (closed_red_red_subst (Γ' := [])); tea.
  Qed.

  Hint Resolve closed_red_red : pcuic.
  
  (*Inductive closed_subslet (Γ : context) : list term -> context -> Type :=
  | closed_emptyslet : closed_subslet Γ [] []
  | closed_cons_let_ass Δ s na t T :
      closed_subslet Γ s Δ ->
      is_open_term Γ t ->
      closed_subslet Γ (t :: s) (Δ ,, vass na T)
  | closed_cons_let_def Δ s na t T :
      closed_subslet Γ s Δ ->
      is_open_term Γ (subst0 s t) ->
      closed_subslet Γ (subst0 s t :: s) (Δ ,, vdef na t T).
  
  Lemma closed_subslet_untyped_subslet {Γ s Δ} : 
    closed_subslet Γ s Δ ->
    untyped_subslet Γ s Δ.
  Proof.
    induction 1; constructor; auto.
  Qed.*)

  Hint Resolve untyped_subslet_length : pcuic.

  (* Lemma closed_red1_substitution {Γ Δ Γ' s M N} :
    untyped_subslet Γ s Δ ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    Σ ;;; Γ ,,, Δ ,,, Γ' ⊢ M ⇝ N ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| M ⇝ subst s #|Γ'| N.
  Proof.
    intros Hs H. split.
    - eapply is_closed_subst_context; eauto with fvs pcuic.
    - eapply is_open_term_subst; tea; eauto with fvs pcuic.
    - eapply substitution_untyped_red; tea; eauto with fvs.
  Qed. *)

  Lemma closed_red_untyped_substitution {Γ Δ Γ' s M N} :
    untyped_subslet Γ s Δ ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    Σ ;;; Γ ,,, Δ ,,, Γ' ⊢ M ⇝ N ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| M ⇝ subst s #|Γ'| N.
  Proof.
    intros Hs H. split.
    - eapply is_closed_subst_context; eauto with fvs pcuic.
    - eapply is_open_term_subst; tea; eauto with fvs pcuic.
    - eapply substitution_untyped_red; tea; eauto with fvs.
  Qed.

  Lemma closed_red_untyped_substitution0 {Γ Δ s M N} :
    untyped_subslet Γ s Δ ->
    forallb (on_free_vars (shiftnP #|Γ| xpred0)) s ->
    Σ ;;; Γ ,,, Δ ⊢ M ⇝ N ->
    Σ ;;; Γ ⊢ subst s 0 M ⇝ subst s 0 N.
  Proof.
    intros Hs H. now apply (closed_red_untyped_substitution (Γ' := [])).
  Qed.

  Lemma invert_red_letin {Γ C na d ty b} :
    Σ ;;; Γ ⊢ (tLetIn na d ty b) ⇝ C ->
    (∑ d' ty' b',
    ((C = tLetIn na d' ty' b') ×
      Σ ;;; Γ ⊢ d ⇝ d' ×
      Σ ;;; Γ ⊢ ty ⇝ ty' ×
      Σ ;;; (Γ ,, vdef na d ty) ⊢ b ⇝ b')) +
    (Σ ;;; Γ ⊢ (subst10 d b) ⇝ C)%type.
  Proof.
    generalize_eq x (tLetIn na d ty b).
    move=> e [clΓ clt] red.
    assert (clC : is_open_term Γ C) by eauto with fvs.
    revert na d ty b e.
    eapply clos_rt_rt1n_iff in red.
    induction red; simplify_dep_elim.
    + autorewrite with fvs in clC; move/and3P: clC => [] ond onty onb.
      left; do 3 eexists. split; eauto with pcuic fvs.
      repeat split; eauto with fvs.
    + assert (is_open_term Γ y) by eauto with fvs. intuition auto.
      autorewrite with fvs in clt; move/and3P: clt => [] ond onty onb.
      depelim r; try specialize (X0 _ _ _ _ eq_refl) as
        [(? & ? & ? & ? & ? & ? & ?)|?].
      - right. split; try apply clos_rt_rt1n_iff; eauto.
      - solve_discr.
      - left. do 3 eexists. intuition eauto with pcuic.
        * transitivity r; eauto with pcuic.
        * eapply red_red_ctx_inv'; eauto.
          simpl. constructor.
          1:{ apply closed_red_ctx_refl => //. }
          constructor. all:constructor; eauto with fvs.
      - right; auto. transitivity (b {0 := r}); auto.
        eapply (closed_red_red_subst (Δ := [vass na ty]) (Γ' := [])); eauto with fvs.
        * rewrite on_free_vars_ctx_snoc clΓ /= //.
        * constructor; [|constructor]. eapply into_closed_red; eauto with fvs.
        * constructor. constructor.
      - left. do 3 eexists. repeat split; eauto with pcuic.
        * transitivity r; pcuic.
        * rewrite on_free_vars_ctx_snoc clΓ /= //; eauto with fvs.
        * eapply red_red_ctx_inv' in c1; [exact c1|].
          simpl. constructor; [now apply closed_red_ctx_refl|].
          constructor; eauto with fvs pcuic.
      - right; auto.
      - left. do 3 eexists. split; tea.
        split => //. split => //.
        now transitivity r; eauto with pcuic fvs.
      - right; auto.
        transitivity (r {0 := d}); auto.
        eapply (closed_red_untyped_substitution (Δ := [vdef na d ty]) (Γ' := [])); eauto.
        * rewrite -{1}(subst_empty 0 d). constructor. constructor.
        * cbn. eauto with fvs.
        * split; eauto with fvs.
          rewrite on_free_vars_ctx_snoc. eauto with fvs.
  Qed.

  Lemma invert_red_prod {Γ na dom codom T} :
    Σ ;;; Γ ⊢ tProd na dom codom ⇝ T ->
    ∑ dom' codom',
      T = tProd na dom' codom' ×
      Σ ;;; Γ ⊢ dom ⇝ dom' ×
      Σ ;;; Γ ,, vass na dom ⊢ codom ⇝ codom'.
  Proof.
    generalize_eq x (tProd na dom codom).
    move=> e [clΓ clt] red.
    revert na dom codom e.
    eapply clos_rt_rt1n_iff in red.
    induction red; simplify_dep_elim.
    - move: clt.
      rewrite on_fvs_prod => /andP[] ondom oncodom.
      exists dom, codom; repeat split; eauto with fvs.
    - move: clt; rewrite on_fvs_prod => /andP [] ondom oncodom.
      forward IHred. { eauto with fvs. }
      depelim r; solve_discr.
      * specialize (IHred _ _ _ eq_refl).
        destruct IHred as [dom' [codom' [-> [redl redr]]]].
        eexists _, _; split => //.
        split.
        { transitivity N1; split; eauto with fvs. }
        { eapply red_red_ctx_inv'; tea. constructor; eauto with fvs.
          { now eapply closed_red_ctx_refl. }
          constructor; split; eauto with fvs. }
      * specialize (IHred _ _ _ eq_refl) as [dom' [codom' [-> [redl redr]]]].
        eexists _, _; split => //.
        split => //.
        transitivity N2; split; eauto with fvs.
  Qed.

  Lemma untyped_subslet_def_tip {Γ na d ty} : untyped_subslet Γ [d] [vdef na d ty].
  Proof.
    rewrite -{1}(subst_empty 0 d). constructor. constructor.
  Qed.
  Hint Resolve untyped_subslet_def_tip : pcuic.

  Lemma cumul_LetIn_l_inv {Γ na d ty b T} :
    Σ ;;; Γ ⊢ tLetIn na d ty b ≤ T ->
    ∑ b', Σ ;;; Γ ⊢ T ⇝ b' × Σ ;;; Γ ⊢ b {0 := d} ≤ b'.
  Proof.
    intros H.
    eapply equality_red in H as (v & v' & tv & tv' & eqp).
    exists v'. split; auto.
    destruct (invert_red_letin tv) as [(d' & ty' & b' & -> & redb & redty & redbod)|tv''].
    - cbn in eqp.
      etransitivity.
      2:{ eapply ws_equality_refl; tea; eauto with fvs. }
      transitivity (b' {0 := d'}).
      * transitivity (b' {0 := d}).
        + eapply red_equality.
          eapply (closed_red_untyped_substitution0 (Δ := [_])); tea; cbn; eauto with pcuic fvs.
        + eapply red_equality.
          eapply (closed_red_red_subst0 (Δ := [_])); eauto with fvs pcuic.
      * apply red_equality_inv.
        split; eauto with fvs.
        eapply red1_red. constructor.
    - eapply equality_red. exists v, v'.
      intuition pcuic. split; eauto with fvs.
  Qed.

  Lemma cumul_LetIn_r_inv {Γ na d ty b T} :
    Σ ;;; Γ ⊢ T ≤ tLetIn na d ty b ->
    ∑ b', Σ ;;; Γ ⊢ T ⇝ b' × Σ ;;; Γ ⊢ b' ≤ b {0 := d}.
  Proof.
    intros H.
    eapply equality_red in H as (v & v' & tv & tv' & eqp).
    exists v. split; auto.
    destruct (invert_red_letin tv') as [(d' & ty' & b' & -> & redb & redty & redbod)|tv''].
    - cbn in eqp.
      etransitivity.
      1:{ eapply ws_equality_refl; tea; eauto with fvs. }
      eapply equality_eq_le.
      transitivity (b' {0 := d'}).
      + eapply red_equality. split; eauto with fvs.
        apply red1_red. constructor.
      + symmetry.
        transitivity (b' {0 := d}).
        * eapply red_equality.
          eapply (closed_red_untyped_substitution0 (Δ := [_])); tea; cbn; eauto with pcuic fvs.
        * apply red_equality.
          eapply (closed_red_red_subst0 (Δ := [_])); eauto with fvs pcuic.
    - eapply equality_red. exists v, v'.
      intuition pcuic. split; eauto with fvs.
  Qed.

  Lemma equality_Prod_l_inv {le Γ na dom codom T} :
    Σ ;;; Γ ⊢ tProd na dom codom ≤[le] T ->
    ∑ na' dom' codom', Σ ;;; Γ ⊢ T ⇝ (tProd na' dom' codom') ×
    (eq_binder_annot na na') × (Σ ;;; Γ ⊢ dom = dom') × (Σ ;;; Γ ,, vass na dom ⊢ codom ≤[le] codom').
  Proof.
    intros H.
    eapply equality_red in H as (v & v' & tv & tv' & eqp).
    destruct (invert_red_prod tv) as (dom' & codom' & -> & reddom & redcod).
    destruct le.
    - depelim eqp.
      exists na', a', b'; split => //.
      split => //.
      eapply closed_red_open_right in tv'.
      move: tv'. rewrite on_fvs_prod => /andP[] // ona' onb'.
      split.
      * transitivity dom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
      * transitivity codom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
    - depelim eqp.
      exists na', a', b'; split => //.
      split => //.
      eapply closed_red_open_right in tv'.
      move: tv'. rewrite on_fvs_prod => /andP[] // ona' onb'.
      split.
      * transitivity dom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
      * transitivity codom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
  Qed.

  Lemma equality_Prod_r_inv {le Γ na dom codom T} :
    Σ ;;; Γ ⊢ T ≤[le] tProd na dom codom ->
    ∑ na' dom' codom', Σ ;;; Γ ⊢ T ⇝ (tProd na' dom' codom') ×
    (eq_binder_annot na na') × (Σ ;;; Γ ⊢ dom' = dom) × (Σ ;;; Γ ,, vass na dom ⊢ codom' ≤[le] codom).
  Proof.
    intros H.
    eapply equality_red in H as (v & v' & tv & tv' & eqp).
    destruct (invert_red_prod tv') as (dom' & codom' & -> & reddom & redcod).
    destruct le.
    - depelim eqp.
      exists na0, a, b; split => //.
      split => //.
      eapply closed_red_open_right in tv.
      move: tv. rewrite on_fvs_prod => /andP[] // ona' onb'.
      split.
      * transitivity dom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
      * transitivity codom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
    - depelim eqp.
      exists na0, a, b; split => //.
      split => //.
      eapply closed_red_open_right in tv.
      move: tv. rewrite on_fvs_prod => /andP[] // ona' onb'.
      split.
      * transitivity dom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
      * transitivity codom'; pcuic.
        eapply ws_equality_refl; eauto with fvs.
  Qed.
  
  Ltac splits := repeat split.

  Lemma equality_Prod_Prod_inv {le Γ na na' dom dom' codom codom'} :
    Σ ;;; Γ ⊢ tProd na dom codom ≤[le] tProd na' dom' codom' ->
    (eq_binder_annot na na') × (Σ ;;; Γ ⊢ dom = dom') × (Σ ;;; Γ ,, vass na' dom' ⊢ codom ≤[le] codom').
  Proof.
    intros H.
    eapply equality_red in H as (v & v' & tv & tv' & eqp).
    destruct (invert_red_prod tv) as (dom0 & codom0 & -> & reddom0 & redcod0).
    destruct (invert_red_prod tv') as (dom0' & codom0' & -> & reddom0' & redcod0').
    destruct le.
    - depelim eqp.
      split => //.
      assert (Σ ;;; Γ ⊢ dom = dom').
      { transitivity dom0; pcuic.
        transitivity dom0'; pcuic.
        eapply ws_equality_refl; eauto with fvs. }
      split => //.
      transitivity codom0'; pcuic.
      transitivity codom0; pcuic.
      { eapply PCUICContextConversion.equality_equality_ctx_inv; pcuic.
        constructor; [apply closed_context_equality_refl|]; eauto with fvs.
        constructor; auto. exact X. }
      constructor; eauto with fvs.
      cbn. eauto with fvs.
    - depelim eqp.
      split => //.
      assert (Σ ;;; Γ ⊢ dom = dom').
      { transitivity dom0; pcuic.
        transitivity dom0'; pcuic.
        eapply ws_equality_refl; eauto with fvs. }
      split => //.
      transitivity codom0'; pcuic.
      transitivity codom0; pcuic.
      { eapply PCUICContextConversion.equality_equality_ctx_inv; pcuic.
        constructor; [apply closed_context_equality_refl|]; eauto with fvs.
        constructor; auto. exact X. }
      constructor. 2:cbn. all:eauto with fvs.
  Qed.

End ConvCongruences.

Section Inversions.
  Context {cf : checker_flags}.
  Context (Σ : global_env_ext).
  Context {wfΣ : wf Σ}.

  Definition Is_conv_to_Arity Σ Γ T :=
    exists T', ∥ Σ ;;; Γ ⊢ T ⇝ T' ∥ /\ isArity T'.

  (*Lemma arity_red_to_prod_or_sort :
    forall Γ T,
      is_closed_context Γ ->
      is_open_term Γ T ->
      isArity T ->
      (exists na A B, ∥ Σ ;;; Γ ⊢ T ⇝ (tProd na A B) ∥) \/
      (exists u, ∥ Σ ;;; Γ ⊢ T ⇝ (tSort u) ∥).
  Proof.
    intros Γ T a.
    induction T in Γ, a |- *. all: try contradiction.
    - right. eexists. constructor. pcuic.
    - left. eexists _,_,_. constructor. pcuic.
    - simpl in a. eapply IHT3 in a as [[na' [A [B [r]]]] | [u [r]]].
      + left. eexists _,_,_. constructor.
        eapply red_trans.
        * eapply red1_red. eapply red_zeta.
        * eapply untyped_substitution_red with (s := [T1]) (Γ' := []) in r.
          -- simpl in r. eassumption.
          -- assumption.
          -- instantiate (1 := [],, vdef na T1 T2).
             replace (untyped_subslet Γ [T1] ([],, vdef na T1 T2))
              with (untyped_subslet Γ [subst0 [] T1] ([],, vdef na T1 T2))
              by (now rewrite subst_empty).
             eapply untyped_cons_let_def.
             constructor.
      + right. eexists. constructor.
        eapply red_trans.
        * eapply red1_red. eapply red_zeta.
        * eapply untyped_substitution_red with (s := [T1]) (Γ' := []) in r.
          -- simpl in r. eassumption.
          -- assumption.
          -- replace (untyped_subslet Γ [T1] ([],, vdef na T1 T2))
              with (untyped_subslet Γ [subst0 [] T1] ([],, vdef na T1 T2))
              by (now rewrite subst_empty).
            eapply untyped_cons_let_def.
            constructor.
  Qed.

  Lemma Is_conv_to_Arity_inv :
    forall Γ T,
      Is_conv_to_Arity Σ Γ T ->
      (exists na A B, ∥ Σ ;;; Γ ⊢ T ⇝ (tProd na A B) ∥) \/
      (exists u, ∥ Σ ;;; Γ ⊢ T ⇝ (tSort u) ∥).
  Proof.
    intros Γ T [T' [r a]].
    induction T'.
    all: try contradiction.
    - right. eexists. eassumption.
    - left. eexists _, _, _. eassumption.
    - destruct r as [r1].
      eapply arity_red_to_prod_or_sort in a as [[na' [A [B [r2]]]] | [u [r2]]].
      + left. eexists _,_,_. constructor.
        eapply red_trans. all: eassumption.
      + right. eexists. constructor.
        eapply red_trans. all: eassumption.
  Qed.*)

  Lemma invert_red_sort Γ u v :
    Σ ;;; Γ ⊢ (tSort u) ⇝ v -> v = tSort u.
  Proof.
    intros [clΓ clu H]. generalize_eq x (tSort u).
    induction H; simplify *.
    - depind r. solve_discr.
    - reflexivity.
    - rewrite IHclos_refl_trans2; eauto with fvs. 
  Qed.

  Lemma invert_cumul_sort_r Γ C u :
    Σ ;;; Γ ⊢ C ≤ tSort u ->
               ∑ u', Σ ;;; Γ ⊢ C ⇝ (tSort u') × leq_universe (global_ext_constraints Σ) u' u.
  Proof.
    intros Hcum.
    eapply equality_red in Hcum as [v [v' [redv [redv' leqvv']]]].
    eapply invert_red_sort in redv' as ->.
    depelim leqvv'. exists s. intuition eauto.
  Qed.

  Lemma invert_cumul_sort_l Γ C u :
    Σ ;;; Γ ⊢ tSort u ≤ C ->
               ∑ u', Σ ;;; Γ ⊢ C ⇝ (tSort u') × leq_universe (global_ext_constraints Σ) u u'.
  Proof.
    intros Hcum.
    eapply equality_red in Hcum as [v [v' [redv [redv' leqvv']]]].
    eapply invert_red_sort in redv as ->.
    depelim leqvv'. exists s'. intuition eauto.
  Qed.

  Lemma eq_term_upto_univ_conv_arity_l :
    forall Re Rle Γ u v,
      isArity u ->
      eq_term_upto_univ Σ Re Rle u v ->
      Is_conv_to_Arity Σ Γ v.
  Proof.
    (*intros Re Rle Γ u v a e.
    induction u in Γ, a, v, Rle, e |- *. all: try contradiction.
    all: dependent destruction e.
    - eexists. split.
      + constructor. reflexivity.
      + reflexivity.
    - simpl in a.
      eapply IHu2 in e3. 2: assumption.
      destruct e3 as [b'' [[r] ab]].
      exists (tProd na' a' b''). split.
      + constructor. eapply red_prod_r. eassumption.
      + simpl. assumption.
    - simpl in a.
      eapply IHu3 in e4. 2: assumption.
      destruct e4 as [u'' [[r] au]].
      exists (tLetIn na' t' ty' u''). split.
      + constructor. eapply red_letin.
        all: try solve [ constructor ].
        eassumption.
      + simpl. assumption.*)
    todo "case".      
  Qed.
(*
  Lemma eq_term_upto_univ_conv_arity_r :
    forall Re Rle Γ u v,
      isArity u ->
      eq_term_upto_univ Σ Re Rle v u ->
      Is_conv_to_Arity Σ Γ v.
  Proof.
    intros Re Rle Γ u v a e.
    induction u in Γ, a, v, Rle, e |- *. all: try contradiction.
    all: dependent destruction e.
    - eexists. split.
      + constructor. reflexivity.
      + reflexivity.
    - simpl in a.
      eapply IHu2 in e3. 2: assumption.
      destruct e3 as [b'' [[r] ab]].
      exists (tProd na0 a0 b''). split.
      + constructor. eapply red_prod_r. eassumption.
      + simpl. assumption.
    - simpl in a.
      eapply IHu3 in e4. 2: assumption.
      destruct e4 as [u'' [[r] au]].
      exists (tLetIn na0 t ty u''). split.
      + constructor. eapply red_letin.
        all: try solve [ constructor ].
        eassumption.
      + simpl. assumption.
  Qed.

  Lemma isArity_subst :
    forall u v k,
      isArity u ->
      isArity (u { k := v }).
  Proof.
    intros u v k h.
    induction u in v, k, h |- *. all: try contradiction.
    - simpl. constructor.
    - simpl in *. eapply IHu2. assumption.
    - simpl in *. eapply IHu3. assumption.
  Qed.

  Lemma isArity_red1 :
    forall Γ u v,
      red1 Σ Γ u v ->
      isArity u ->
      isArity v.
  Proof.
    intros Γ u v h a.
    induction u in Γ, v, h, a |- *. all: try contradiction.
    - dependent destruction h.
      apply (f_equal nApp) in H as eq. simpl in eq.
      rewrite nApp_mkApps in eq. simpl in eq.
      destruct args. 2: discriminate.
      simpl in H. discriminate.
    - dependent destruction h.
      + apply (f_equal nApp) in H as eq. simpl in eq.
        rewrite nApp_mkApps in eq. simpl in eq.
        destruct args. 2: discriminate.
        simpl in H. discriminate.
      + assumption.
      + simpl in *. eapply IHu2. all: eassumption.
    - dependent destruction h.
      + simpl in *. apply isArity_subst. assumption.
      + apply (f_equal nApp) in H as eq. simpl in eq.
        rewrite nApp_mkApps in eq. simpl in eq.
        destruct args. 2: discriminate.
        simpl in H. discriminate.
      + assumption.
      + assumption.
      + simpl in *. eapply IHu3. all: eassumption.
  Qed.

  Lemma invert_cumul_arity_r :
    forall (Γ : context) (C : term) T,
      isArity T ->
      Σ;;; Γ ⊢ C ≤ T ->
      Is_conv_to_Arity Σ Γ C.
  Proof.
    intros Γ C T a h.
    induction h.
    - eapply eq_term_upto_univ_conv_arity_r. all: eassumption.
    - forward IHh by assumption. destruct IHh as [v' [[r'] a']].
      exists v'. split.
      + constructor. eapply red_trans.
        * eapply trans_red.
          -- reflexivity.
          -- eassumption.
        * assumption.
      + assumption.
    - eapply IHh. eapply isArity_red1. all: eassumption.


  Qed.

  Lemma invert_cumul_arity_l :
    forall (Γ : context) (C : term) T,
      isArity C ->
      Σ;;; Γ ⊢ C ≤ T ->
      Is_conv_to_Arity Σ Γ T.
  Proof.
    intros Γ C T a h.
    induction h.
    - eapply eq_term_upto_univ_conv_arity_l. all: eassumption.
    - eapply IHh. eapply isArity_red1. all: eassumption.
    - forward IHh by assumption. destruct IHh as [v' [[r'] a']].
      exists v'. split.
      + constructor. eapply red_trans.
        * eapply trans_red.
          -- reflexivity.
          -- eassumption.
        * assumption.
      + assumption.


  Qed. *)

(*   
  Lemma invert_cumul_prod_l Γ C na A B :
    Σ ;;; Γ ⊢ tProd na A B ≤ C ->
               ∑ na' A' B', Σ ;;; Γ ⊢ C ⇝ (tProd na' A' B') *
                  eq_binder_annot na na' *
                  (Σ ;;; Γ ⊢ A = A') *
                  (Σ ;;; (Γ ,, vass na A) ⊢ B ≤ B').
  Proof.
    intros Hprod.
    eapply cumul_alt in Hprod as [v [v' [[redv redv'] leqvv']]].
    eapply invert_red_prod in redv as (A' & B' & ((-> & Ha') & ?)) => //.
    depelim leqvv'.
    do 3 eexists; intuition eauto.
    - eapply conv_trans with A'; auto.
      now constructor.
    - eapply cumul_trans with B'; eauto.
      + now eapply red_cumul.
      + now constructor; apply leqvv'2.
  Qed. *)

  Hint Constructors All_decls conv_decls cumul_decls : core.


  Lemma cumul_red_r_inv {Γ T U U'} :
    Σ ;;; Γ ⊢ T ≤ U ->
    red Σ Γ U U' ->
    Σ ;;; Γ ⊢ T ≤ U'.
  Proof.
    intros * cumtu red.
    transitivity U; tea. eapply red_equality.
    constructor; eauto with fvs.
  Qed.

  Lemma cumul_red_l_inv {Γ T T' U} :
    Σ ;;; Γ ⊢ T ≤ U ->
    red Σ Γ T T' ->
    Σ ;;; Γ ⊢ T' ≤ U.
  Proof.
    intros * cumtu red.
    transitivity T => //. eapply red_equality_inv.
    constructor; eauto with fvs.
  Qed.

  Lemma invert_cumul_letin_l Γ C na d ty b :
    Σ ;;; Γ ⊢ tLetIn na d ty b ≤ C ->
    Σ ;;; Γ ⊢ subst10 d b ≤ C.
  Proof.
    intros Hlet.
    eapply cumul_red_l_inv; eauto.
    eapply red1_red; constructor.
  Qed.

  Lemma invert_cumul_letin_r Γ C na d ty b :
    Σ ;;; Γ ⊢ C ≤ tLetIn na d ty b ->
    Σ ;;; Γ ⊢ C ≤ subst10 d b.
  Proof.
    intros Hlet.
    eapply cumul_red_r_inv; eauto.
    eapply red1_red; constructor.
  Qed.

  Lemma conv_red_l_inv :
    forall (Γ : context) T T' U,
    Σ ;;; Γ ⊢ T = U ->
    red Σ Γ T T' ->
    Σ ;;; Γ ⊢ T' = U.
  Proof.
    intros * cumtu red.
    transitivity T => //.
    apply red_equality_inv.
    constructor; eauto with fvs.
  Qed.

  Lemma invert_conv_letin_l Γ C na d ty b :
    Σ ;;; Γ ⊢ tLetIn na d ty b = C ->
    Σ ;;; Γ ⊢ subst10 d b = C.
  Proof.
    intros Hlet.
    eapply conv_red_l_inv; eauto.
    eapply red1_red; constructor.
  Qed.

  Lemma invert_conv_letin_r Γ C na d ty b :
    Σ ;;; Γ ⊢ C = tLetIn na d ty b ->
    Σ ;;; Γ ⊢ C = subst10 d b.
  Proof.
    intros Hlet. symmetry; symmetry in Hlet.
    now eapply invert_conv_letin_l.
  Qed.

  Lemma app_mkApps :
    forall u v t l,
      isApp t = false ->
      tApp u v = mkApps t l ->
      ∑ l',
        (l = l' ++ [v]) ×
        u = mkApps t l'.
  Proof.
    intros u v t l h e.
    induction l in u, v, t, e, h |- * using list_rect_rev.
    - cbn in e. subst. cbn in h. discriminate.
    - rewrite <- mkApps_nested in e. cbn in e.
      exists l. inversion e. subst. auto.
  Qed.

  Lemma invert_red_mkApps_tInd {Γ : context} {ind u} (args : list term) c :
    Σ ;;; Γ ⊢ mkApps (tInd ind u) args ⇝ c ->
    ∑ args' : list term,
    (c = mkApps (tInd ind u) args') * (All2 (closed_red Σ Γ) args args').
  Proof.
    move=> [clΓ].
    rewrite PCUICOnFreeVars.on_free_vars_mkApps => /= hargs r.
    destruct (red_mkApps_tInd (Γ := exist Γ clΓ) hargs r) as [args' [eq red]].
    exists args'; split => //.
    solve_all; split; eauto with fvs.
  Qed.

  (* TODO deprecate? #[deprecated(note="use red_mkApps_tInd")] *)
  Notation invert_red_ind := red_mkApps_tInd.

  Lemma compare_term_mkApps_l_inv {le} {u : term} {l : list term} {t : term} :
    compare_term le Σ Σ (mkApps u l) t ->
    ∑ (u' : term) (l' : list term),
      (eq_term_upto_univ_napp Σ (eq_universe Σ) (compare_universe le Σ) #|l| u u' × 
      All2 (eq_term Σ Σ) l l') × t = mkApps u' l'.
  Proof.
    destruct le => /=; apply eq_term_upto_univ_mkApps_l_inv.
  Qed.

  Lemma compare_term_mkApps_r_inv {le} {u : term} {l : list term} {t : term} :
    compare_term le Σ Σ t (mkApps u l) ->
    ∑ (u' : term) (l' : list term),
      (eq_term_upto_univ_napp Σ (eq_universe Σ) (compare_universe le Σ) #|l| u' u × 
      All2 (eq_term Σ Σ) l' l) × t = mkApps u' l'.
  Proof.
    destruct le => /=; apply eq_term_upto_univ_mkApps_r_inv.
  Qed.

  Lemma invert_equality_ind_l {le Γ ind ui l T} :
      Σ ;;; Γ ⊢ mkApps (tInd ind ui) l ≤[le] T ->
      ∑ ui' l',
        Σ ;;; Γ ⊢ T ⇝ (mkApps (tInd ind ui') l') ×
        R_global_instance Σ (eq_universe Σ) (compare_universe le Σ) (IndRef ind) #|l| ui ui' ×
        All2 (fun a a' => Σ ;;; Γ ⊢ a = a') l l'.
  Proof.
    move/equality_red=> [v [v' [redv [redv' leqvv']]]].
    eapply invert_red_mkApps_tInd in redv as [l' [? ha]]; auto. subst.
    eapply compare_term_mkApps_l_inv in leqvv' as [u [l'' [[e ?] ?]]].
    subst. depelim e.
    eexists _,_. split ; eauto. split ; auto.
    - now rewrite (All2_length ha).
    - eapply All2_trans.
      * intros x y z h1 h2. etransitivity; tea.
      * eapply All2_impl ; eauto with pcuic.
      * assert (forallb (is_open_term Γ) l'). { eapply All_forallb, All2_All_right; tea; eauto with fvs. }
        assert (forallb (is_open_term Γ) l''). {
          eapply closed_red_open_right in redv'.
          now rewrite PCUICOnFreeVars.on_free_vars_mkApps /= in redv'. }
        solve_all; eauto with fvs.
        constructor; eauto with fvs.
  Qed.

  Lemma closed_red_terms_open_left {Γ l l'}: 
    All2 (closed_red Σ Γ) l l' ->
    All (is_open_term Γ) l.
  Proof. solve_all; eauto with fvs. Qed.
  
  Lemma closed_red_terms_open_right {Γ l l'}: 
    All2 (closed_red Σ Γ) l l' ->
    All (is_open_term Γ) l'.
  Proof. solve_all; eauto with fvs. Qed.

  Lemma invert_equality_ind_r {le Γ ind ui l T} :
      Σ ;;; Γ ⊢ T ≤[le] mkApps (tInd ind ui) l ->
      ∑ ui' l',
        Σ ;;; Γ ⊢ T ⇝ (mkApps (tInd ind ui') l') ×
        R_global_instance Σ (eq_universe Σ) (compare_universe le Σ) (IndRef ind) #|l| ui' ui ×
        All2 (fun a a' => Σ ;;; Γ ⊢ a = a') l' l.
  Proof.
    move/equality_red=> [v [v' [redv [redv' leqvv']]]].
    eapply invert_red_mkApps_tInd in redv' as [l' [? ha]]; auto. subst.
    eapply compare_term_mkApps_r_inv in leqvv' as [u [l'' [[e ?] ?]]].
    subst. depelim e.
    eexists _,_. split ; eauto. split ; auto.
    - now rewrite (All2_length ha).
    - eapply All2_trans.
      * intros x y z h1 h2. etransitivity; tea.
      * assert (forallb (is_open_term Γ) l'). { eapply All_forallb, (All2_All_right ha); tea; eauto with fvs. }
        assert (forallb (is_open_term Γ) l''). {
          eapply closed_red_open_right in redv.
          now rewrite PCUICOnFreeVars.on_free_vars_mkApps /= in redv. }
        solve_all; eauto with fvs.
        constructor; eauto with fvs.
      * eapply All2_impl. 
        + eapply All2_sym; tea.
        + cbn. eauto with pcuic.
  Qed.

  Lemma invert_equality_ind {le Γ ind ind' ui ui' l l'} :
      Σ ;;; Γ ⊢ mkApps (tInd ind ui) l ≤[le] mkApps (tInd ind' ui') l' ->
      ind = ind' ×
      R_global_instance Σ (eq_universe Σ) (compare_universe le Σ) (IndRef ind) #|l| ui ui ×
      All2 (fun a a' => Σ ;;; Γ ⊢ a = a') l l'.
  Proof.
    move/equality_red=> [v [v' [redv [redv' leqvv']]]].
    pose proof (clrel_ctx redv).
    eapply invert_red_mkApps_tInd in redv as [l0 [? ha]]; auto. subst.
    eapply invert_red_mkApps_tInd in redv' as [l1 [? ha']]; auto. subst.
    eapply compare_term_mkApps_l_inv in leqvv' as [u [l'' [[e ?] ?]]].
    depelim e; solve_discr.
    noconf H0. noconf H1. intuition auto.
    + apply R_global_instance_refl; tc.
    + eapply All2_trans; tea; tc.
      { eapply ws_equality_trans. }
      { eapply (All2_impl ha); eauto with pcuic. }
      pose proof (closed_red_terms_open_right ha).
      pose proof (closed_red_terms_open_right ha').
      eapply All2_trans with l1; tea; tc.
      { eapply ws_equality_trans. }
      { solve_all; eauto with fvs. constructor; eauto with fvs. }
      eapply All2_symP; tc.
      { eapply ws_equality_sym. }
      solve_all; eauto with fvs pcuic.
      eauto with pcuic.
  Qed.

End Inversions.

(* Unused... *)
(*Lemma it_mkProd_or_LetIn_ass_inv {cf : checker_flags} (Σ : global_env_ext) Γ ctx ctx' s s' :
  wf Σ ->
  assumption_context ctx ->
  assumption_context ctx' ->
  Σ ;;; Γ ⊢ it_mkProd_or_LetIn ctx (tSort s) ≤ it_mkProd_or_LetIn ctx' (tSort s') ->
  All2_fold (fun ctx ctx' => conv_decls Σ (Γ ,,, ctx) (Γ ,,, ctx')) ctx ctx' *
   leq_term Σ.1 Σ (tSort s) (tSort s').
Proof.
  intros.
  revert Γ ctx' s s'.
  induction ctx using rev_ind.
  - intros. destruct ctx' using rev_ind.
    + simpl in X.
      eapply cumul_Sort_inv in X.
      split; constructor; auto.
    + destruct x as [na [b|] ty].
      * elimtype False.
        apply assumption_context_app in H0.
        destruct H0. inv a0.
      * rewrite it_mkProd_or_LetIn_app in X.
        apply assumption_context_app in H0 as [H0 _].
        specialize (IHctx' H0).
        simpl in IHctx'. simpl in X.
        unfold mkProd_or_LetIn in X. simpl in X.
        eapply cumul_Sort_Prod_inv in X. depelim X.
  - intros.
    rewrite it_mkProd_or_LetIn_app in X.
    simpl in X.
    eapply assumption_context_app in H as [H H'].
    destruct x as [na [b|] ty].
    + elimtype False. inv H'.
    + rewrite /mkProd_or_LetIn /= in X.
      destruct ctx' using rev_ind.
      * simpl in X.
        now eapply cumul_Prod_Sort_inv in X.
      * eapply assumption_context_app in H0 as [H0 Hx].
        destruct x as [na' [b'|] ty']; [elimtype False; inv Hx|].
        rewrite it_mkProd_or_LetIn_app in X.
        rewrite /= /mkProd_or_LetIn /= in X.
        eapply cumul_Prod_Prod_inv in X as [eqann [Hdom Hcodom]]; auto.
        specialize (IHctx (Γ ,, vass na' ty') l0 s s' H H0 Hcodom).
        clear IHctx'.
        intuition auto.
        eapply All2_fold_app.
        ** eapply (All2_fold_length a).
        ** constructor; [constructor|constructor; auto].
        ** unshelve eapply (All2_fold_impl a).
           simpl; intros Γ0 Γ' d d'.
           rewrite !app_context_assoc.
           intros X; destruct X.
           *** constructor; auto.
              eapply conv_conv_ctx; eauto.
              eapply conv_context_app_same.
              constructor; [apply conv_ctx_refl|constructor; auto]; now symmetry.
           *** constructor; auto; eapply conv_conv_ctx; eauto.
              **** eapply conv_context_app_same.
                constructor; [apply conv_ctx_refl|constructor;auto];
                now symmetry.
              **** eapply conv_context_app_same.
                constructor; [apply conv_ctx_refl|constructor;auto];
                now symmetry.
Qed.*)

(** Injectivity of products, the essential property of cumulativity needed for subject reduction. *)
Lemma cumul_Prod_inv {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ} {Γ na na' A B A' B'} :
  Σ ;;; Γ ⊢ tProd na A B ≤ tProd na' A' B' ->
   (eq_binder_annot na na' × (Σ ;;; Γ ⊢ A = A') × (Σ ;;; Γ ,, vass na' A' ⊢ B ≤ B'))%type.
Proof.
  intros H.
  now eapply equality_Prod_Prod_inv in H.
Qed.

(** Injectivity of products for conversion holds as well *)
Lemma conv_Prod_inv {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ} {Γ na na' A B A' B'} :
  Σ ;;; Γ ⊢ tProd na A B = tProd na' A' B' ->
   (eq_binder_annot na na' × (Σ ;;; Γ ⊢ A = A') × (Σ ;;; Γ ,, vass na' A' ⊢ B = B'))%type.
Proof.
  intros H.
  now eapply equality_Prod_Prod_inv in H.
Qed.

Lemma tProd_it_mkProd_or_LetIn na A B ctx s :
  tProd na A B = it_mkProd_or_LetIn ctx (tSort s) ->
  { ctx' & ctx = (ctx' ++ [vass na A]) /\
           destArity [] B = Some (ctx', s) }.
Proof.
  intros. exists (removelast ctx).
  revert na A B s H.
  induction ctx using rev_ind; intros; noconf H.
  rewrite it_mkProd_or_LetIn_app in H. simpl in H.
  destruct x as [na' [b'|] ty']; noconf H; simpl in *.
  rewrite removelast_app. 1: congruence.
  simpl. rewrite app_nil_r. intuition auto.
  rewrite destArity_it_mkProd_or_LetIn. simpl. now rewrite app_context_nil_l.
Qed.

Section Inversions.
  Context {cf : checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ}.

  Lemma equality_App_l {le Γ f f' u} :
    Σ ;;; Γ ⊢ f ≤[le] f' ->
    is_open_term Γ u ->
    Σ ;;; Γ ⊢ tApp f u ≤[le] tApp f' u.
  Proof.
    intros h onu.
    induction h.
    - constructor; cbn; eauto with fvs. cbn in c.
      destruct le; constructor; eauto with fvs; try reflexivity.
      + eapply leq_term_leq_term_napp; tc; tas.
      + apply eq_term_eq_term_napp; tc; tas.
    - eapply red_equality_left; tea.
      econstructor; tea; cbn; eauto with fvs.
      eapply red1_red. constructor; auto.
    - eapply red_equality_right; tea.
      econstructor; tea; cbn; eauto with fvs.
      eapply red1_red. constructor; auto.
  Qed.

  Lemma equality_App_r {le Γ f u v} :
    is_open_term Γ f ->
    Σ ;;; Γ ⊢ u = v ->
    Σ ;;; Γ ⊢ tApp f u ≤[le] tApp f v.
  Proof.
    intros onf h.
    induction h.
    - constructor; cbn; eauto with fvs. cbn in c.
      destruct le; constructor; eauto with fvs; reflexivity.
    - eapply red_equality_left; tea.
      econstructor; tea; cbn; eauto with fvs.
      eapply red1_red. constructor; auto.
    - eapply red_equality_right; tea.
      econstructor; tea; cbn; eauto with fvs.
      eapply red1_red. constructor; auto.
  Qed.
  
  Lemma equality_mkApps {le Γ hd args hd' args'} :
    Σ;;; Γ ⊢ hd ≤[le] hd' ->
    All2 (ws_equality false Σ Γ) args args' ->
    Σ;;; Γ ⊢ mkApps hd args ≤[le] mkApps hd' args'.
  Proof.
    intros cum cum_args.
    revert hd hd' cum.
    induction cum_args; intros hd hd' cum; auto.
    cbn.
    apply IHcum_args.
    etransitivity.
    - eapply equality_App_l; tea; eauto with fvs.
    - eapply equality_App_r; eauto with fvs.
  Qed.
End Inversions.

(*Section ConvCum.
  Import PCUICCumulativity.
  Context {cf : checker_flags}.
  Context (Σ : global_env_ext) (wfΣ : wf Σ).


  Lemma conv_sq_equality {leq Γ u v} :
    ∥ Σ ;;; Γ |-u = v ∥ -> sq_equality leq Σ Γ u v.
  Proof.
    intros h; destruct leq.
    - cbn. assumption.
    - destruct h. cbn.
      constructor. now eapply conv_cumul.
  Qed.

  #[global]
  Instance conv_cum_trans {leq Γ} :
    RelationClasses.Transitive (sq_equality leq Σ Γ).
  Proof.
    intros u v w h1 h2. destruct leq; cbn in *; sq. etransitivity; eassumption.
  Qed.

  Lemma red_conv_cum_l {leq Γ u v} :
    red (fst Σ) Γ u v -> sq_equality leq Σ Γ u v.
  Proof.
    destruct leq; constructor.
    + now eapply red_conv.
    + now eapply red_cumul.
  Qed.

  Lemma red_conv_cum_r {leq Γ u v} :
    red (fst Σ) Γ u v -> sq_equality leq Σ Γ v u.
  Proof.
   induction 1.
   - destruct leq; constructor.
     + now eapply conv_red_r.
     + now eapply cumul_red_r.
   - reflexivity.
   - etransitivity; tea.
  Qed.*)

Definition sq_equality {cf : checker_flags} le Σ Γ T U := ∥ Σ ;;; Γ ⊢ T ≤[le] U ∥.

Section ConvRedConv.

  Context {cf : checker_flags}.
  Context {Σ : global_env_ext} {wfΣ : wf Σ}.

  Lemma conv_red_conv Γ Γ' t tr t' t'r :
    Σ ⊢ Γ = Γ' ->
    Σ ;;; Γ ⊢ t ⇝ tr ->
    Σ ;;; Γ' ⊢ t' ⇝ t'r ->
    Σ ;;; Γ ⊢ tr = t'r ->
    Σ ;;; Γ ⊢ t = t'.
  Proof.
    intros cc r r' ct.
    eapply red_equality_left; eauto.
    eapply equality_equality_ctx in ct.
    2:symmetry; tea.
    eapply equality_equality_ctx; tea.
    eapply red_equality_right; tea.
  Qed.
  
  Lemma Prod_conv_cum_inv {Γ leq na1 na2 A1 A2 B1 B2} :
    sq_equality leq Σ Γ (tProd na1 A1 B1) (tProd na2 A2 B2) ->
      eq_binder_annot na1 na2 /\ ∥ Σ ;;; Γ ⊢ A1 = A2 ∥ /\
      sq_equality leq Σ (Γ,, vass na1 A1) B1 B2.
  Proof.
    intros [].
    apply equality_Prod_Prod_inv in X; intuition auto; sq; auto.
    eapply equality_equality_ctx in b0; tea.
    instantiate (1:=false). constructor; auto.
    - apply closed_context_equality_refl; eauto with fvs.
    - constructor; auto.
  Qed.
  
  Lemma conv_cum_conv_ctx leq le Γ Γ' T U :
    sq_equality leq Σ Γ T U ->
    Σ ⊢ Γ' ≤[le] Γ ->
    sq_equality leq Σ Γ' T U.
  Proof.
    intros [] h.
    now eapply equality_equality_ctx in X; tea.
  Qed.
  
  Lemma conv_cum_red leq Γ t1 t2 t1' t2' :
    Σ ;;; Γ ⊢ t1' ⇝ t1 ->
    Σ ;;; Γ ⊢ t2' ⇝ t2 ->
    sq_equality leq Σ Γ t1 t2 ->
    sq_equality leq Σ Γ t1' t2'.
  Proof.
    intros r1 r2 [cc]. sq.
    eapply red_equality_left; tea.
    eapply red_equality_right; tea.
  Qed.

  Lemma conv_cum_red_conv leq Γ Γ' t1 t2 t1' t2' :
    closed_conv_context Σ Γ Γ' ->
    Σ ;;; Γ ⊢ t1' ⇝ t1 ->
    Σ ;;; Γ' ⊢ t2' ⇝ t2 ->
    sq_equality leq Σ Γ t1 t2 ->
    sq_equality leq Σ Γ t1' t2'.
  Proof.
    intros conv_ctx r1 r2 [cc]; sq.
    eapply red_equality_left; tea.
    eapply equality_equality_ctx in cc; tea. 2:symmetry; tea.
    eapply equality_equality_ctx; tea.
    eapply red_equality_right; tea.
  Qed.

  Lemma conv_cum_red_inv leq Γ t1 t2 t1' t2' :
    Σ ;;; Γ ⊢ t1 ⇝ t1' ->
    Σ ;;; Γ ⊢ t2 ⇝ t2' ->
    sq_equality leq Σ Γ t1 t2 ->
    sq_equality leq Σ Γ t1' t2'.
  Proof.
    intros r1 r2 [cc]; sq.
    transitivity t1.
    - now eapply red_equality_inv.
    - transitivity t2 => //.
      now apply red_equality.
  Qed.
  
  Lemma conv_cum_red_conv_inv leq Γ Γ' t1 t2 t1' t2' :
    closed_conv_context Σ Γ Γ' ->
    Σ ;;; Γ ⊢ t1 ⇝ t1' ->
    Σ ;;; Γ' ⊢ t2 ⇝ t2' ->
    sq_equality leq Σ Γ t1 t2 ->
    sq_equality leq Σ Γ t1' t2'.
  Proof.
    move=> conv_ctx r1 /(red_equality (le:=leq)) r2 [cc]; sq.
    transitivity t1; [now apply red_equality_inv|].
    transitivity t2 => //.
    eapply equality_equality_ctx in r2; tea.
  Qed.
  
  Lemma conv_cum_red_iff leq Γ t1 t2 t1' t2' :
    Σ ;;; Γ ⊢ t1' ⇝ t1 ->
    Σ ;;; Γ ⊢ t2' ⇝ t2 ->
    sq_equality leq Σ Γ t1 t2 <-> sq_equality leq Σ Γ t1' t2'.
  Proof.
    intros r1 r2.
    split; intros cc.
    - eapply conv_cum_red; eauto.
    - eapply conv_cum_red_inv; eauto.
  Qed.

  Lemma conv_cum_red_conv_iff leq Γ Γ' t1 t2 t1' t2' :
    closed_conv_context Σ Γ Γ' ->
    Σ ;;; Γ ⊢ t1' ⇝ t1 ->
    Σ ;;; Γ' ⊢ t2' ⇝ t2 ->
    sq_equality leq Σ Γ t1 t2 <-> sq_equality leq Σ Γ t1' t2'.
  Proof.
    intros conv_ctx r1 r2.
    split; intros cc.
    - eapply conv_cum_red_conv; eauto.
    - eapply conv_cum_red_conv_inv; eauto.
  Qed.

  Import PCUICOnFreeVars.

  (* Lemma equality_Case {Γ indn p brs u v} :
    Σ ;;; Γ ⊢ u = v ->
    Σ ;;; Γ ⊢ tCase indn p u brs ≤ tCase indn p v brs.
  Proof.
    intros Γ [ind n] p brs u v h.
    induction h.
    - constructor. constructor; auto.
      + reflexivity.
      + eapply All2_same.
        intros. split ; reflexivity.
    - eapply cumul_red_l ; eauto.
      constructor. assumption.
    - eapply cumul_red_r ; eauto.
      constructor. assumption.
  Qed. *)

  Lemma cumul_Proj_c {le Γ p u v} :
      Σ ;;; Γ ⊢ u = v ->
      Σ ;;; Γ ⊢ tProj p u ≤[le] tProj p v.
  Proof.
    intros h.
    induction h.
    - eapply ws_equality_refl; eauto.
      destruct le; constructor; assumption.
    - transitivity (tProj p v) => //.
      eapply red_equality. constructor; eauto with fvs.
      econstructor. constructor. assumption.
    - transitivity (tProj p v) => //.
      eapply red_equality_inv. constructor; eauto with fvs.
      econstructor. constructor. assumption.
  Qed.

  Lemma App_conv :
    forall Γ t1 t2 u1 u2,
      Σ ;;; Γ ⊢ t1 = t2 ->
      Σ ;;; Γ ⊢ u1 = u2 ->
      Σ ;;; Γ ⊢ tApp t1 u1 = tApp t2 u2.
  Proof.
    intros. etransitivity.
    - eapply equality_App_l; tea; eauto with fvs.
    - apply equality_App_r; tea. eauto with fvs.
  Qed.

  Lemma mkApps_conv_args Γ f f' u v :
    Σ ;;; Γ ⊢ f = f' ->
    All2 (fun x y => Σ ;;; Γ ⊢ x = y) u v ->
    Σ ;;; Γ ⊢ mkApps f u = mkApps f' v.
  Proof.
    move=> convf cuv.
    eapply equality_mkApps; eauto.
  Qed.

  Definition conv_predicate Γ p p' :=
    All2 (ws_equality false Σ Γ) p.(pparams) p'.(pparams) ×
    R_universe_instance (eq_universe Σ) (puinst p) (puinst p')
    × pcontext p = pcontext p'
    × Σ ;;; Γ ,,, inst_case_predicate_context p ⊢ preturn p = preturn p'.

  #[global]
  Instance all_eq_term_refl : Reflexive (All2 (eq_term_upto_univ Σ.1 (eq_universe Σ) (eq_universe Σ))).
  Proof.
    intros x. apply All2_same. intros. reflexivity.
  Qed.

  Definition set_puinst (p : predicate term) (puinst : Instance.t) : predicate term :=
    {| pparams := p.(pparams);
        puinst := puinst;
        pcontext := p.(pcontext);
        preturn := p.(preturn) |}.
  
  Definition set_preturn_two {p} pret pret' : set_preturn (set_preturn p pret') pret = set_preturn p pret := 
    eq_refl.


  (*Lemma conv_context_red_context Γ Γ' Δ Δ' :
    closed_conv_context Σ (Γ ,,, Δ) (Γ' ,,, Δ') ->
    #|Γ| = #|Γ'| ->
    ∑ Δ1 Δ1', red_ctx_rel Σ Γ Δ Δ1 × red_ctx_rel Σ Γ' Δ' Δ1' × 
      eq_context_upto Σ (eq_universe Σ) (eq_universe Σ) Δ1 Δ1'.
  Proof.
    intros.
    pose proof (closed_con)
    pose proof (length_of X). len in H0.
    eapply conv_context_red_context in X as [Δ1 [Δ1' [[redl redr] eq]]]; auto.
    exists (firstn #|Δ| Δ1), (firstn #|Δ'| Δ1').
    have l := (length_of redl). len in l.
    have l' := (length_of redr). len in l'.
    intuition auto.
    - eapply red_ctx_rel_red_context_rel => //.
      rewrite -(firstn_skipn #|Δ| Δ1) in redl.
      eapply All2_fold_app_inv in redl as [].
      * red. eapply All2_fold_impl; tea => /= //.
        intros ???? []; constructor; auto.
      * rewrite firstn_length_le //.
        pose proof (length_of redl).
        rewrite firstn_skipn in H1.
        len in H0. lia.
    - eapply red_ctx_rel_red_context_rel => //.
      rewrite -(firstn_skipn #|Δ'| Δ1') in redr.
      eapply All2_fold_app_inv in redr as [].
      * red. eapply All2_fold_impl; tea => /= //.
        intros ???? []; constructor; auto.
      * rewrite firstn_length_le //. lia.
    - rewrite -(firstn_skipn #|Δ'| Δ1') in eq.
      rewrite -(firstn_skipn #|Δ| Δ1) in eq.
      eapply All2_fold_app_inv in eq as [] => //.
      rewrite !firstn_length_le => //; try lia.
  Qed.*)

  Notation is_open_brs Γ p brs :=
    (forallb (fun br : branch term =>
      test_context_k (fun k : nat => on_free_vars (closedP k xpredT)) #|pparams p| (bcontext br) &&
      on_free_vars (shiftnP #|bcontext br| (shiftnP #|Γ| xpred0)) (bbody br)) brs).

  Notation is_open_predicate Γ p :=
    ([&& forallb (is_open_term Γ) p.(pparams),
    on_free_vars (shiftnP #|p.(pcontext)| (shiftnP #|Γ| xpred0)) p.(preturn) &
    test_context_k (fun k : nat => on_free_vars (closedP k xpredT)) #|p.(pparams)| p.(pcontext)]).

  (* Lemma OnOne2_conv_open_left {le Γ x y} :
    All2 (ws_equality le Σ Γ) x y ->
    forallb (is_open_term Γ) x.
  Proof.
    induction 1; cbn. *)

  Lemma All2_many_OnOne2_pres {A} (R : A -> A -> Type) (P : A -> Type) l l' :
    All2 R l l' ->
    (forall x y, R x y -> P x × P y) ->
    rtrans_clos (fun x y => #|x| = #|y| × OnOne2 R x y × All P x × All P y) l l'.
  Proof.
    intros h H.
    induction h.
    - constructor.
    - econstructor.
      + split; revgoals.
        * split.
          { constructor; tea. }
          pose proof (All2_impl h H).
          eapply All2_prod_inv in X as [Hl Hl'].
          eapply All2_All_left in Hl; eauto.
          eapply All2_All_right in Hl'; eauto.
          specialize (H _ _ r) as [].
          constructor; constructor; auto.
        * now cbn.
      + pose proof (All2_impl h H).
        eapply All2_prod_inv in X as [Hl Hl'].
        eapply All2_All_left in Hl; eauto.
        eapply All2_All_right in Hl'; eauto.
        specialize (H _ _ r) as [].
        clear -IHh Hl Hl' p p0. rename IHh into h.
        induction h.
        * constructor.
        * destruct r as [hlen [onz [py pz]]].
          econstructor.
          -- split; revgoals. 1:split.
            { econstructor 2; tea. }
            { split; constructor; auto. }
            now cbn.
          -- now apply IHh.
  Qed.

  Lemma rtrans_clos_length {A} {l l' : list A} {P} :
    rtrans_clos (fun x y : list A => #|x| = #|y| × P x y) l l' -> #|l| = #|l'|.
  Proof.
    induction 1; auto.
    destruct r.
    now transitivity #|y|.
  Qed.
  
  Definition is_open_case (Γ : context) p c brs :=
    [&& forallb (is_open_term Γ) p.(pparams),
    on_free_vars (shiftnP #|p.(pcontext)| (shiftnP #|Γ| xpred0)) p.(preturn),
    test_context_k (fun k : nat => on_free_vars (closedP k xpredT)) #|p.(pparams)| p.(pcontext),
    is_open_term Γ c & is_open_brs Γ p brs].

  Lemma is_open_case_split {Γ p c brs} : is_open_case Γ p c brs =
    [&& is_open_predicate Γ p, is_open_term Γ c & is_open_brs Γ p brs].
  Proof.
    rewrite /is_open_case. now repeat bool_congr.
  Qed.

  Lemma is_open_case_set_pparams Γ p c brs pars' :  
    forallb (is_open_term Γ) pars' ->
    #|pars'| = #|p.(pparams)| ->
    is_open_case Γ p c brs ->
    is_open_case Γ (set_pparams p pars') c brs.
  Proof.
    move=> onpars' Hlen.
    move/and5P => [] onpars.
    rewrite /is_open_case => ->.
    rewrite -Hlen => -> -> -> /=.
    rewrite andb_true_r //.
  Qed.

  Lemma is_open_case_set_preturn Γ p c brs pret' :  
    is_open_term (Γ ,,, inst_case_predicate_context p) pret' ->
    is_open_case Γ p c brs ->
    is_open_case Γ (set_preturn p pret') c brs.
  Proof.
    move=> onpret' /and5P[] onpars onpret onpctx onc onbrs.
    rewrite /is_open_case onc onbrs !andb_true_r onpctx /= onpars /= andb_true_r.
    rewrite app_length inst_case_predicate_context_length in onpret'.
    now rewrite shiftnP_add.
  Qed.

  Instance red_brs_refl p Γ : Reflexive (@red_brs Σ p Γ).
  Proof. intros x. eapply All2_refl; split; reflexivity. Qed.

  Instance red_terms_refl Γ : Reflexive (All2 (red Σ Γ)).
  Proof. intros x; eapply All2_refl; reflexivity. Qed.
  
  Instance eqbrs_refl : Reflexive (All2 (fun x y : branch term =>
      eq_context_gen eq eq (bcontext x) (bcontext y) *
      eq_term_upto_univ Σ.1 (eq_universe Σ) (eq_universe Σ) (bbody x) (bbody y))).
  Proof. intros brs; eapply All2_refl; split; reflexivity. Qed.


  Lemma conv_Case_p {Γ ci c brs p p'} :
    is_closed_context Γ ->
    is_open_case Γ p c brs ->
    is_open_predicate Γ p' ->
    conv_predicate Γ p p' ->
    Σ ;;; Γ ⊢ tCase ci p c brs = tCase ci p' c brs.
  Proof.
    intros onΓ oncase onp' [cpars [cu [cctx cret]]].
    assert (Σ ;;; Γ ⊢ tCase ci p c brs = tCase ci (set_preturn p (preturn p')) c brs).
    { eapply equality_red in cret as [v [v' [redl [redr eq]]]].
      eapply equality_red.
      exists (tCase ci (set_preturn p v) c brs).
      exists (tCase ci (set_preturn p v') c brs).
      repeat split; auto.
      - cbn. eapply red_case; try reflexivity.
         apply redl.
      - apply is_open_case_set_preturn => //; eauto with fvs.
      - rewrite -[set_preturn _ v'](set_preturn_two _ (preturn p')).
        eapply red_case; try reflexivity.
        cbn. apply redr.
      - constructor; try reflexivity.
        repeat split; try reflexivity.
        cbn. apply eq. }
    etransitivity; tea.
    set (pret := set_preturn p (preturn p')).
    assert (Σ ;;; Γ ⊢ tCase ci pret c brs = tCase ci (set_puinst pret (puinst p')) c brs).
    { constructor. 1:eauto with fvs. 1:eauto with fvs.
      { eapply ws_equality_is_open_term_right in X. apply X. }
      econstructor; try reflexivity.
      red; intuition try reflexivity. }
    etransitivity; tea.
    set (ppuinst := set_puinst pret (puinst p')) in *.
    assert (Σ ;;; Γ ⊢ tCase ci ppuinst c brs = tCase ci (set_pparams ppuinst p'.(pparams)) c brs).
    { apply ws_equality_is_open_term_right in X0.
      clear -wfΣ cctx cpars onΓ X0.
      eapply All2_many_OnOne2_pres in cpars.
      2:{ intros x y conv. split.
          1:eapply ws_equality_is_open_term_left; tea. eauto with fvs. }
      clear cctx.
      induction cpars.
      * eapply ws_equality_refl; tea.
        destruct p; cbn. reflexivity.
      * destruct r as [hlen [onr [axy az]]].
        transitivity (tCase ci (set_pparams ppuinst y) c brs) => //.
        eapply OnOne2_split in onr as [? [? [? [? [conv [-> ->]]]]]].
        eapply equality_red in conv as [v [v' [redl [redr eq]]]].
        apply equality_red.
        exists (tCase ci (set_pparams ppuinst (x1 ++ v :: x2)) c brs).
        exists (tCase ci (set_pparams ppuinst (x1 ++ v' :: x2)) c brs).
        split.
        { constructor; auto.
          { eapply All_forallb in axy.
            eapply is_open_case_set_pparams => //.
            now apply rtrans_clos_length in cpars. }
          rewrite -[set_pparams _ (x1 ++ v :: _)](set_pparams_two (x1 ++ x :: x2)).
          eapply red_case; try reflexivity.
          { cbn. eapply All2_app.
            { eapply All2_refl. reflexivity. }
            constructor; [apply redl|].
            eapply All2_refl; reflexivity. } }
        split.
        { constructor; auto.
          { eapply All_forallb in az.
            eapply is_open_case_set_pparams => //.
            apply rtrans_clos_length in cpars.
            now rewrite !app_length /= in cpars *. }
          rewrite -[set_pparams _ (x1 ++ v' :: _)](set_pparams_two (x1 ++ x0 :: x2)).
          eapply red_case; try reflexivity.
          { cbn. eapply All2_app; try reflexivity.
            constructor; [apply redr|]; reflexivity. } }
        cbn; constructor; try reflexivity.
        repeat split; try reflexivity.
        cbn. eapply All2_app; try reflexivity.
        constructor => //; reflexivity. }
    etransitivity; tea.
    apply into_ws_equality; auto.
    { destruct p'; cbn in *; unfold set_pparams, ppuinst, pret; cbn; subst pcontext; reflexivity. }
    1:eauto with fvs.
    cbn.
    move/and3P: onp' => [] -> -> -> /=.
    move/and5P: oncase => [] _ _ _ -> /=.
    now rewrite (All2_length cpars).
  Qed.
    
  Lemma conv_Case_c :
    forall Γ indn p brs u v,
      is_open_predicate Γ p ->
      is_open_brs Γ p brs ->
      Σ ;;; Γ ⊢ u = v ->
      Σ ;;; Γ ⊢ tCase indn p u brs = tCase indn p v brs.
  Proof.
    intros Γ ci p brs u v onp onbrs h.
    induction h.
    - constructor; auto with fvs.
      + rewrite [is_open_term _ _]is_open_case_split onp onbrs !andb_true_r /= //.
      + rewrite [is_open_term _ _]is_open_case_split onp onbrs !andb_true_r /= //.
      + cbn. constructor; auto; try reflexivity.
    - eapply red_equality_left ; eauto.
      eapply into_closed_red; tea.
      { constructor. constructor. assumption. }
      rewrite [is_open_term _ _]is_open_case_split onp onbrs /= andb_true_r //.
    - eapply red_equality_right; tea.
      constructor; pcuic.
      rewrite [is_open_term _ _]is_open_case_split onp onbrs /= andb_true_r //.
  Qed.

  Lemma conv_Case_one_brs {Γ indn p c brs brs'} :
    is_closed_context Γ ->
    is_open_predicate Γ p ->
    is_open_term Γ c ->
    is_open_brs Γ p brs ->
    is_open_brs Γ p brs' ->
    OnOne2 (fun u v => u.(bcontext) = v.(bcontext) × 
      Σ ;;; (Γ ,,, inst_case_branch_context p u) ⊢ u.(bbody) = v.(bbody)) brs brs' ->
    Σ ;;; Γ ⊢ tCase indn p c brs = tCase indn p c brs'.
  Proof.
    intros onΓ onp onc onbrs onbrs' h.
    apply OnOne2_split in h as [[bctx br] [[m' br'] [l1 [l2 [[? h] [? ?]]]]]].
    simpl in *. subst m' brs brs'.
    induction h.
    * constructor => //.
      + rewrite [is_open_term _ _]is_open_case_split onp onc /=.
        move: onbrs i0.
        rewrite !forallb_app => /andP[] -> /= /andP[] => /andP[] => -> /= _ ->.
        now rewrite andb_true_r shiftnP_add app_length inst_case_branch_context_length /=.
      + rewrite [is_open_term _ _]is_open_case_split onp onc /=.
        move: onbrs i1.
        rewrite !forallb_app => /andP[] -> /= /andP[] => /andP[] => -> /= _ ->.
        now rewrite andb_true_r shiftnP_add app_length inst_case_branch_context_length /=.
      + constructor; try reflexivity.
        eapply All2_app; try reflexivity.
        constructor; try split; try reflexivity.
        cbn. apply c0.
    * eapply red_equality_left; tea.
      2:{ eapply IHh => //. }
      eapply into_closed_red; eauto.
      { constructor. constructor.
        eapply OnOne2_app. constructor; auto. }
      rewrite [is_open_term _ _]is_open_case_split onp onc /=.
      move: onbrs i0.
      rewrite !forallb_app => /andP[] -> /= /andP[] => /andP[] => -> /= _ ->.
      now rewrite andb_true_r shiftnP_add app_length inst_case_branch_context_length /=.
    * eapply red_equality_right; tea.
      2:{ eapply IHh => //.
          move: onbrs i2.
          rewrite !forallb_app => /andP[] -> /= /andP[] => /andP[] => -> /= _ ->.
          now rewrite andb_true_r shiftnP_add app_length inst_case_branch_context_length /=. }
      eapply into_closed_red; eauto => //.
      { constructor. constructor.
        eapply OnOne2_app. constructor; auto. }
      rewrite [is_open_term _ _]is_open_case_split onp onc /= //.
  Qed.

  Definition conv_brs Γ p :=
    All2 (fun u v =>
      bcontext u = bcontext v × 
      Σ ;;; Γ ,,, inst_case_branch_context p u ⊢ bbody u = bbody v).

  Lemma is_open_brs_OnOne2 Γ p x y : 
    is_open_brs Γ p x ->
    OnOne2 (fun u v : branch term =>
      (bcontext u = bcontext v) *
      (Σ ;;; Γ,,, inst_case_branch_context p u ⊢ bbody u = bbody v)) y x ->
    is_open_brs Γ p y.
  Proof.
    intros op.
    induction 1.
    - cbn. destruct p0.
      move: op => /=; rewrite e; move/andP =>[] /andP[] -> _ ->.
      eapply ws_equality_is_open_term_left in w.
      rewrite app_length inst_case_branch_context_length e in w.
      now rewrite shiftnP_add andb_true_r.
    - now move: op => /= /andP[] => ->.
  Qed.

  Lemma conv_Case_brs {Γ ci p c brs brs'} :
    is_closed_context Γ ->
    is_open_predicate Γ p ->
    is_open_term Γ c ->
    is_open_brs Γ p brs ->
    is_open_brs Γ p brs' ->
    conv_brs Γ p brs brs' ->
    Σ ;;; Γ ⊢ tCase ci p c brs = tCase ci p c brs'.
  Proof.
    intros onΓ onp onc onbrs onbrs' h.
    eapply (All2_many_OnOne2_pres _ (fun br => 
      is_open_term (Γ ,,, inst_case_branch_context p br) br.(bbody))) in h.
    2:{ intros x y [eq cv].
        split; [eapply ws_equality_is_open_term_left|eapply ws_equality_is_open_term_right]; tea.
        now rewrite /inst_case_branch_context -eq. }
    induction h.
    - apply ws_equality_refl; tas.
      1-2:rewrite [is_open_term _ _]is_open_case_split onp onc /= //.
      cbn; reflexivity.
    - destruct r as [o [ony onz]].
      etransitivity.
      + apply IHh.
        eapply is_open_brs_OnOne2; tea.
      + apply conv_Case_one_brs; tea.
        eapply is_open_brs_OnOne2; tea.
  Qed.

  Lemma conv_Case {Γ ci p p' c c' brs brs'} :
    is_open_case Γ p c brs ->
    is_open_case Γ p' c' brs' ->
    conv_predicate Γ p p' ->
    Σ ;;; Γ ⊢ c = c' ->
    conv_brs Γ p brs brs' ->
    Σ ;;; Γ ⊢ tCase ci p c brs = tCase ci p' c' brs'.
  Proof.
    intros onc0. generalize onc0. 
    rewrite !is_open_case_split => /and3P[onp onc onbrs] /and3P[onp' onc' onbrs'].
    move=> cvp cvc.
    assert (clΓ := ws_equality_is_closed_context cvc).
    etransitivity.
    { eapply conv_Case_brs. 6:tea. all:tas.
      destruct cvp as [onpars [oninst [onctx onr]]].
      now rewrite (All2_length onpars). }
    etransitivity.
    { eapply conv_Case_c; tea.
      destruct cvp as [onpars [oninst [onctx onr]]].
      now rewrite (All2_length onpars). }
    eapply conv_Case_p; tea.
    destruct cvp as [onpars [oninst [onctx onr]]].
    rewrite is_open_case_split onp onc' /=.
    now rewrite (All2_length onpars).
  Qed.

  Lemma conv_Proj_c :
    forall Γ p u v,
      Σ ;;; Γ ⊢ u = v ->
      Σ ;;; Γ ⊢ tProj p u = tProj p v.
  Proof.
    intros Γ p u v h.
    induction h.
    - now repeat constructor.
    - eapply red_equality_left ; try eassumption.
      constructor; eauto with fvs. constructor.
      econstructor. assumption.
    - eapply red_equality_right ; try eassumption.
      constructor; eauto with fvs. constructor.
      econstructor. assumption.
  Qed.

  Definition fix_or_cofix b mfix idx :=     
    (if b then tFix else tCoFix) mfix idx.

   Lemma eq_term_fix_or_cofix b mfix idx mfix' :
     All2 (fun x y : def term =>
       ((eq_term_upto_univ Σ.1 (eq_universe Σ) (eq_universe Σ) (dtype x) (dtype y)
        × eq_term_upto_univ Σ.1 (eq_universe Σ) (eq_universe Σ) (dbody x) (dbody y)) × rarg x = rarg y) *
      eq_binder_annot (dname x) (dname y)) mfix mfix' ->
    eq_term Σ Σ (fix_or_cofix b mfix idx) (fix_or_cofix b mfix' idx).
  Proof.
    destruct b; constructor; auto.
  Qed.

  Notation is_open_def Γ n :=
    (test_def (on_free_vars (shiftnP #|Γ| xpred0)) (on_free_vars (shiftnP n (shiftnP #|Γ| xpred0)))).

  Notation is_open_mfix Γ mfix :=
    (forallb (is_open_def Γ #|mfix|) mfix).

  Lemma is_open_fix_or_cofix {b} {Γ : context} {mfix idx} : 
    is_open_term Γ (fix_or_cofix b mfix idx) =
    is_open_mfix Γ mfix.
  Proof. by case: b. Qed.

  Lemma conv_Fix_one_type {b Γ mfix mfix' idx} :
    is_closed_context Γ ->
    is_open_mfix Γ mfix ->
    is_open_mfix Γ mfix' ->
    OnOne2 (fun u v =>
      Σ ;;; Γ ⊢ dtype u = dtype v ×
      dbody u = dbody v ×
      (rarg u = rarg v) *
      eq_binder_annot (dname u) (dname v)
    ) mfix mfix' ->
    Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx.
  Proof.
    intros onΓ onmfix onmfix' h.
    eapply into_ws_equality => //; rewrite ?is_open_fix_or_cofix //.
    clear onmfix onmfix'.
    apply OnOne2_split in h
      as [[na ty bo ra] [[na' ty' bo' ra'] [l1 [l2 [[h [? ?]] [? ?]]]]]].
    simpl in *. subst. destruct p as [eqra eqna]. subst.
    induction h.
    - constructor; tea.
      apply eq_term_fix_or_cofix.
      apply All2_app.
      * apply All2_same. intros. intuition reflexivity.
      * constructor.
        { simpl. intuition reflexivity. }
        apply All2_same. intros. intuition reflexivity.
    - eapply conv_red_l; eauto.
      destruct b; constructor; eapply OnOne2_app;
      constructor; cbn; intuition eauto.
    - eapply conv_red_r ; eauto.
      destruct b; constructor; apply OnOne2_app; constructor; simpl;
      intuition eauto.
  Qed.
  
  Lemma conv_Fix_types {b Γ mfix mfix' idx} :
    is_closed_context Γ ->
    is_open_mfix Γ mfix ->
    is_open_mfix Γ mfix' ->
    All2 (fun u v =>
      Σ ;;; Γ ⊢ dtype u = dtype v ×
      dbody u = dbody v ×
      (rarg u = rarg v) *
      (eq_binder_annot (dname u) (dname v)))
      mfix mfix' ->
    Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx.
  Proof.
    intros onΓ onm onm' h.
    pose proof onm.
    cbn in onm, onm'.
    eapply forallb_All in onm.
    eapply forallb_All in onm'.
    eapply All2_All_mix_left in h; tea.
    eapply All2_All_mix_right in h; tea.
    eapply (All2_many_OnOne2_pres _ (is_open_def Γ #|mfix|)) in h.
    2:{ intuition auto. now rewrite (All2_length h). }
    induction h.
    - eapply ws_equality_refl => //.
      1-2:rewrite is_open_fix_or_cofix //.
      cbn; reflexivity.
    - etransitivity.
      + eapply IHh.  
      + destruct r as [hlen [onone [ay az]]].
        eapply conv_Fix_one_type; tea; solve_all.
        all:now rewrite -?hlen -(rtrans_clos_length h).
  Qed.

  Lemma red_fix_or_cofix_body b (Γ : context) (mfix : mfixpoint term) (idx : nat) (mfix' : list (def term)) :
    All2 (on_Trel_eq (red Σ (Γ,,, fix_context mfix)) dbody
      (fun x0 : def term => (dname x0, dtype x0, rarg x0))) mfix mfix' ->
    red Σ Γ (fix_or_cofix b mfix idx) (fix_or_cofix b mfix' idx).
  Proof.
    destruct b; apply red_fix_body || apply red_cofix_body.
  Qed.
  
  Lemma conv_Fix_one_body {b Γ mfix mfix' idx} :
    is_closed_context Γ ->
    is_open_mfix Γ mfix ->
    is_open_mfix Γ mfix' ->
    OnOne2 (fun u v =>
      dtype u = dtype v ×
      Σ ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
      (rarg u = rarg v) *
      (eq_binder_annot (dname u) (dname v))
    ) mfix mfix' ->
    Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx.
  Proof.
    intros onΓ onmfix onmfix' h.
    assert (All2 (compare_decls eq eq) (fix_context mfix) (fix_context mfix')).
    { clear -h.
      unfold fix_context, mapi.
      generalize 0 at 2 4.
      induction h; intros n.
      + destruct p as [hty [_ [_ eqna]]].
        cbn.
        eapply All2_app; [eapply All2_refl; reflexivity|].
        constructor; cbn; [|constructor].
        constructor; auto. f_equal. auto.
      + cbn.
        eapply All2_app; eauto.
        constructor; auto. constructor; auto. }
    apply OnOne2_split in h
      as [[na ty bo ra] [[na' ty' bo' ra'] [l1 [l2 [[? [h [? ?]]] [? ?]]]]]].
    simpl in *. subst ty' ra'.
    eapply equality_red in h as [v [v' [hbo [hbo' hcomp]]]].
    set (declv := {| dname := na; dtype := ty; dbody := v; rarg := ra |}).
    set (declv' := {| dname := na'; dtype := ty; dbody := v'; rarg := ra |}).
    eapply equality_red.
    exists (fix_or_cofix b (l1 ++ declv :: l2) idx), (fix_or_cofix b (l1 ++ declv' :: l2) idx).
    repeat split; auto; rewrite ?is_open_fix_or_cofix //.
    { destruct b; [eapply red_fix_body | eapply red_cofix_body]; rewrite H;
      eapply All2_app.
      all:try eapply All2_refl; intuition auto.
      all:constructor; [|eapply All2_refl; intuition auto].
      all:cbn; intuition auto; rewrite -H //; tas.
      - apply hbo.
      - apply hbo. }
    { eapply red_fix_or_cofix_body. rewrite H0.
      eapply All2_app; try reflexivity.
      { eapply All2_refl; intuition auto. }
      constructor. 
      - cbn. intuition auto.
        rewrite -H0.
        eapply red_eq_context_upto_names; tea.
        2:exact hbo'.
        eapply All2_fold_All2, All2_app; auto.
        eapply All2_refl; reflexivity.
      - eapply All2_refl. intros.
        intuition auto. }
    { cbn. apply eq_term_fix_or_cofix. eapply All2_app.
      * eapply All2_refl; intuition auto; reflexivity.
      * constructor; intuition auto; try reflexivity.
        eapply All2_refl; intuition auto; reflexivity. }
  Qed.

  Lemma is_open_fix_onone2 {Γ Δ mfix mfix'} : 
    OnOne2
      (fun u v : def term =>
       (dtype u = dtype v) *
       (Σ ;;; Γ,,, Δ ⊢ dbody u = dbody v
        × rarg u = rarg v × eq_binder_annot (dname u) (dname v))) mfix' mfix ->
    #|Δ| = #|mfix| ->
    is_open_mfix Γ mfix ->
    is_open_mfix Γ mfix'.
  Proof.
    cbn.
    intros a hlen hmfix.
    rewrite (OnOne2_length a).
    eapply OnOne2_split in a as [? [? [? [? []]]]].
    destruct a. subst.
    red; rewrite -hmfix.
    rewrite !forallb_app /=. bool_congr. f_equal.
    destruct p. rewrite /test_def /on_free_vars_decl /test_decl /=.
    rewrite e. f_equal.
    destruct p. apply ws_equality_is_open_term in w.
    move/and3P: w => [].
    now rewrite !app_length hlen !app_length /= shiftnP_add => _ -> ->.
  Qed.

  Lemma conv_Fix_bodies {b Γ mfix mfix' idx} :
    is_closed_context Γ ->
    is_open_mfix Γ mfix ->
    is_open_mfix Γ mfix' ->
    All2 (fun u v =>
        dtype u = dtype v ×
        Σ ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
        (rarg u = rarg v) *
        (eq_binder_annot (dname u) (dname v)))
      mfix mfix' ->
    Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx.
  Proof.
    intros onΓ onm onm' h.
    assert (thm :
      Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx ×
      #|mfix| = #|mfix'| ×
      eq_context_upto Σ eq eq (Γ ,,, fix_context mfix) (Γ ,,, fix_context mfix')
    ).
    { eapply (All2_many_OnOne2_pres _ (fun x => True)) in h.
      2:intuition.
      induction h.
      - split; try reflexivity.
        + eapply ws_equality_refl => //; rewrite ?is_open_fix_or_cofix //.
          cbn; reflexivity.
        + split; reflexivity.
      - destruct r as [hl [r _]].
        assert (is_open_mfix Γ y).
        { eapply (is_open_fix_onone2) in r; intuition auto.
          now rewrite fix_context_length -(OnOne2_length r) -(rtrans_clos_length h). }
        destruct (IHh H) as [? []].
        split.
        + etransitivity.
          * eassumption.
          * apply conv_Fix_one_body; tea; eauto with fvs.
            eapply OnOne2_impl. 1: eassumption.
            intros [na ty bo ra] [na' ty' bo' ra'] [? [hh ?]].
            simpl in *. intuition eauto.
            eapply equality_eq_context_upto. 3: eassumption.
            1:eapply eq_context_impl. 4: eassumption.
            all:tc.
            rewrite on_free_vars_ctx_app onΓ /=.
            apply on_free_vars_fix_context. solve_all.
        + split; [lia|].
          etransitivity.
          * eassumption.
          * apply OnOne2_split in r
              as [[na ty bo ra] [[na' ty' bo' ra'] [l1 [l2 [[? [? [? ?]]] [? ?]]]]]].
            simpl in *. subst.
            rewrite 2!fix_context_fix_context_alt.
            rewrite 2!map_app. simpl.
            unfold def_sig at 2 5. simpl.
            eapply eq_context_upto_cat.
            -- eapply eq_context_upto_refl; auto.
            -- eapply eq_context_upto_rev'.
               rewrite 2!mapi_app. cbn.
               eapply eq_context_upto_cat.
               ++ constructor; tas; revgoals.
                  ** constructor; tas. eapply eq_term_upto_univ_refl. all: auto.
                  ** eapply eq_context_upto_refl; auto.
               ++ eapply eq_context_upto_refl; auto.
    }
    apply thm.
  Qed.

  Lemma equality_fix_or_cofix {b Γ mfix mfix' idx} : 
    is_closed_context Γ ->
    All2 (fun u v =>
      Σ;;; Γ ⊢ dtype u = dtype v ×
      Σ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
      (rarg u = rarg v) *
      (eq_binder_annot (dname u) (dname v))) 
      mfix mfix' ->
    Σ ;;; Γ ⊢ fix_or_cofix b mfix idx = fix_or_cofix b mfix' idx.
  Proof.
    intros onΓ h.
    assert (is_open_mfix Γ mfix /\ is_open_mfix Γ mfix') as [opl opr].
    { cbn. rewrite -(All2_length h). solve_all.
      - move: a a0 => /ws_equality_is_open_term /and3P[] _ onty onty'.
        move/ws_equality_is_open_term => /and3P[] _.
        rewrite !app_length !fix_context_length => onbody onbody'.
        rewrite /test_def /= onty /= shiftnP_add //.
      - move: a a0 => /ws_equality_is_open_term/and3P[] _ onty onty'.
        move/ws_equality_is_open_term => /and3P[] _.
        rewrite !app_length !fix_context_length => onbody onbody'.
        rewrite /test_def /= onty' /= shiftnP_add //. }
    assert (h' : ∑ mfix'',
      All2 (fun u v =>
        Σ;;; Γ ⊢ dtype u = dtype v ×
        dbody u = dbody v ×
        rarg u = rarg v ×
        (eq_binder_annot (dname u) (dname v))
      ) mfix'' mfix' ×
      All2 (fun u v =>
        dtype u = dtype v ×
        Σ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
        rarg u = rarg v ×
        (eq_binder_annot (dname u) (dname v))
      ) mfix mfix'' 
    ).
    { set (P1 := fun u v => Σ ;;; Γ ⊢ u = v).
      set (P2 := fun u v => Σ ;;; Γ ,,, fix_context mfix ⊢ u = v).
      change (
        All2 (fun u v =>
          P1 u.(dtype) v.(dtype) ×
          P2 u.(dbody) v.(dbody) ×
          (rarg u = rarg v) *
          (eq_binder_annot (dname u) (dname v))
        ) mfix mfix'
      ) in h.
      change (
        ∑ mfix'',
          All2 (fun u v =>
            P1 u.(dtype) v.(dtype) × dbody u = dbody v × (rarg u = rarg v) ×
            (eq_binder_annot (dname u) (dname v))
          ) mfix'' mfix' ×
          All2 (fun u v =>
            dtype u = dtype v × P2 u.(dbody) v.(dbody) × rarg u = rarg v ×
            (eq_binder_annot (dname u) (dname v))
          ) mfix mfix''
      ).
      clearbody P1 P2. clear opl opr.
      induction h.
      - exists []. repeat split. all: constructor.
      - destruct IHh as [l'' [h1 h2]].
        eexists (mkdef _ (dname x) _ _ _ :: l''). repeat split.
        + constructor. 2: assumption.
          simpl. intuition eauto.
        + constructor. 2: assumption.
          intuition eauto.   
    }
    destruct h' as [mfix'' [h1 h2]].
    assert (is_open_mfix Γ mfix'').
    { cbn in opl. eapply forallb_All in opl.
      eapply All2_All_mix_left in h2; tea.
      cbn. rewrite -(All2_length h2). solve_all.
      move: a => /andP[].
      move: a2 => /ws_equality_is_open_term/and3P[] _.
      rewrite !app_length !fix_context_length => onbody onbody'.
      rewrite /test_def /= a1 => -> /= _.
      rewrite shiftnP_add //. }
    etransitivity.
    - eapply conv_Fix_bodies. 4:tea. all:assumption.
    - eapply conv_Fix_types. all: assumption.
  Qed.

  Lemma conv_fix {Γ mfix mfix' idx} : 
    is_closed_context Γ ->
    All2 (fun u v =>
      Σ;;; Γ ⊢ dtype u = dtype v ×
      Σ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
      (rarg u = rarg v) *
      (eq_binder_annot (dname u) (dname v))) 
      mfix mfix' ->
    Σ ;;; Γ ⊢ tFix mfix idx = tFix mfix' idx.
  Proof. eapply (equality_fix_or_cofix (b:=true)). Qed.

  Lemma conv_cofix {Γ mfix mfix' idx} : 
    is_closed_context Γ ->
    All2 (fun u v =>
      Σ;;; Γ ⊢ dtype u = dtype v ×
      Σ;;; Γ ,,, fix_context mfix ⊢ dbody u = dbody v ×
      (rarg u = rarg v) *
      (eq_binder_annot (dname u) (dname v))) 
      mfix mfix' ->
    Σ ;;; Γ ⊢ tCoFix mfix idx = tCoFix mfix' idx.
  Proof. eapply (equality_fix_or_cofix (b:=false)). Qed.
  
  Lemma conv_Lambda_l {Γ na A b na' A'} :
    eq_binder_annot na na' ->
    is_open_term (Γ ,, vass na A) b ->
    Σ ;;; Γ ⊢ A = A' ->
    Σ ;;; Γ ⊢ tLambda na A b = tLambda na' A' b.
  Proof.
    intros hna hb h.
    eapply into_ws_equality.
    { clear -h hna; induction h.
      - constructor. constructor; auto. reflexivity.
      - eapply conv_red_l; tea; pcuic.
      - eapply conv_red_r; tea; pcuic. }
    { eauto with fvs. }
    all:rewrite on_fvs_lambda; eauto with fvs.
  Qed.

  Lemma conv_Lambda_r {le Γ na A b b'} : 
    Σ ;;; Γ,, vass na A ⊢ b ≤[le] b' ->
    Σ ;;; Γ ⊢ tLambda na A b ≤[le] tLambda na A b'.
  Proof.
    intros h.
    generalize (ws_equality_is_closed_context h).
    rewrite on_free_vars_ctx_snoc /on_free_vars_decl /test_decl => /andP[] onΓ /= onA.
    eapply into_ws_equality => //.
    { induction h.
      - destruct le; now repeat constructor.
      - destruct le.
        + eapply cumul_red_l ; try eassumption; try econstructor; assumption.
        + eapply conv_red_l ; try eassumption. try econstructor; assumption.
      - destruct le.
        + eapply cumul_red_r ; pcuic.
        + eapply conv_red_r ; pcuic. }
    all:rewrite on_fvs_lambda onA /=; eauto with fvs.
  Qed.
  
  Lemma cumul_Lambda_r :
    forall Γ na A b b',
      Σ ;;; Γ,, vass na A ⊢ b ≤ b' ->
      Σ ;;; Γ ⊢ tLambda na A b ≤ tLambda na A b'.
  Proof.
    intros. now eapply (conv_Lambda_r (le:=true)).
  Qed.

  Lemma congr_LetIn_bo {le Γ na ty t u u'} :
    Σ ;;; Γ ,, vdef na ty t ⊢ u ≤[le] u' ->
    Σ ;;; Γ ⊢ tLetIn na ty t u ≤[le] tLetIn na ty t u'.
  Proof.
    intros h.
    generalize (ws_equality_is_open_term h).
    rewrite on_free_vars_ctx_snoc /= => /and3P[]/andP[] onΓ.
    rewrite /on_free_vars_decl /test_decl => /andP[] /= onty ont onu onu'.
    eapply into_ws_equality => //.
    { clear -h. induction h.
      - destruct le.
        { eapply cumul_refl. constructor.
          all: try eapply eq_term_refl; auto. }
        { eapply conv_refl. constructor.
          all: try eapply eq_term_refl; auto. }
      - destruct le.
        { eapply cumul_red_l; tea; pcuic. }
        { eapply conv_red_l; tea; pcuic. }
      - destruct le.
        { eapply cumul_red_r ; pcuic. }
        { eapply conv_red_r; pcuic. } }
    { rewrite on_fvs_letin onty ont //. }
    { rewrite on_fvs_letin onty ont //. }
  Qed.

  Lemma cumul_it_mkLambda_or_LetIn :
    forall Δ Γ u v,
      Σ ;;; (Δ ,,, Γ) ⊢ u ≤ v ->
      Σ ;;; Δ ⊢ it_mkLambda_or_LetIn Γ u ≤ it_mkLambda_or_LetIn Γ v.
  Proof.
    intros Δ Γ u v h. revert Δ u v h.
    induction Γ as [| [na [b|] A] Γ ih ] ; intros Δ u v h.
    - assumption.
    - simpl. cbn. eapply ih.
      eapply congr_LetIn_bo. assumption.
    - simpl. cbn. eapply ih.
      eapply conv_Lambda_r. assumption.
  Qed.

  Lemma ws_equality_refl' {Γ A} : 
    is_closed_context Γ ->
    is_open_term Γ A ->
    Σ ;;; Γ ⊢ A = A.
  Proof.
    intros; apply ws_equality_refl => //; cbn; reflexivity.
  Qed.

  Lemma cumul_it_mkProd_or_LetIn_codom :
    forall Δ Γ B B',
      Σ ;;; (Δ ,,, Γ) ⊢ B ≤ B' ->
      Σ ;;; Δ ⊢ it_mkProd_or_LetIn Γ B ≤ it_mkProd_or_LetIn Γ B'.
  Proof.
    intros Δ Γ B B' h.
    induction Γ as [| [na [b|] A] Γ ih ] in Δ, B, B', h |- *.
    - assumption.
    - simpl. cbn. eapply ih.
      eapply congr_LetIn_bo. assumption.
    - simpl. cbn. eapply ih.
      eapply congr_prod; try reflexivity; tas.
      move/ws_equality_is_closed_context: h.
      rewrite /= on_free_vars_ctx_snoc /on_free_vars_decl /test_decl /= => /andP[] onΓΔ ont.
      apply ws_equality_refl' => //.
  Qed.

  Lemma mkApps_conv_weak :
    forall Γ u1 u2 l,
      forallb (is_open_term Γ) l -> 
      Σ ;;; Γ ⊢ u1 = u2 ->
      Σ ;;; Γ ⊢ mkApps u1 l = mkApps u2 l.
  Proof.
    intros Γ u1 u2 l.
    induction l in u1, u2 |- *; cbn. 1: trivial.
    move=> /andP[] ona onl.
    intros X. apply IHl => //. apply equality_App_l => //.
  Qed.

  Lemma congr_Lambda {leq Γ na1 na2 A1 A2 t1 t2} :
    eq_binder_annot na1 na2 ->
    Σ ;;; Γ ⊢ A1 = A2 ->
    Σ ;;; Γ ,, vass na1 A1 ⊢ t1 ≤[leq] t2 ->
    Σ ;;; Γ ⊢ tLambda na1 A1 t1 ≤[leq] tLambda na2 A2 t2.
  Proof.
    intros eqna X.
    etransitivity.
    - eapply conv_Lambda_r; tea.
    - destruct leq.
      + eapply equality_eq_le, conv_Lambda_l => //. eauto with fvs.
      + eapply conv_Lambda_l; tea; eauto with fvs.
  Qed.

  Lemma conv_cum_Lambda leq Γ na1 na2 A1 A2 t1 t2 :
    eq_binder_annot na1 na2 ->
    Σ ;;; Γ ⊢ A1 = A2 ->
    sq_equality leq Σ (Γ ,, vass na1 A1) t1 t2 ->
    sq_equality leq Σ Γ (tLambda na1 A1 t1) (tLambda na2 A2 t2).
  Proof.
    intros eqna X []; sq. now apply congr_Lambda.
  Qed.

  Lemma conv_LetIn_tm Γ na na' ty t t' u :
    eq_binder_annot na na' ->
    is_open_term Γ ty ->
    is_open_term (Γ ,, vdef na t ty) u ->
    Σ ;;; Γ ⊢ t = t' ->
    Σ ;;; Γ ⊢ tLetIn na t ty u = tLetIn na' t' ty u.
  Proof.
    intros hna onty onu ont.
    eapply into_ws_equality.
    { clear onu. induction ont.
      - constructor 1. constructor; try reflexivity;
        assumption.
      - econstructor 2; tea. now constructor.
      - econstructor 3; tea. now constructor. }
    { eauto with fvs. }
    all:rewrite on_fvs_letin onty; eauto with fvs.
  Qed.

  Lemma conv_LetIn_ty {Γ na na' ty ty' t u} :
    eq_binder_annot na na' ->
    is_open_term Γ t ->
    is_open_term (Γ ,, vdef na t ty) u ->
    Σ ;;; Γ ⊢ ty = ty' ->
    Σ ;;; Γ ⊢ tLetIn na t ty u = tLetIn na' t ty' u.
  Proof.
    intros hna ont onu onty.
    eapply into_ws_equality.
    { clear onu. induction onty.
      - constructor 1. constructor; try reflexivity;
        assumption.
      - econstructor 2; tea. now constructor.
      - econstructor 3; tea. now constructor. }
    { eauto with fvs. }
    all:rewrite on_fvs_letin ont onu andb_true_r; eauto with fvs.
  Qed.

  Lemma conv_LetIn_bo :
    forall Γ na ty t u u',
      Σ ;;; Γ ,, vdef na ty t ⊢ u = u' ->
      Σ ;;; Γ ⊢ tLetIn na ty t u = tLetIn na ty t u'.
  Proof.
    intros Γ na ty t u u' h.
    now eapply congr_LetIn_bo.
  Qed.

  Lemma equality_eq_le_gen {le Γ T U} :
    Σ ;;; Γ ⊢ T = U ->
    Σ ;;; Γ ⊢ T ≤[le] U.
  Proof.
    destruct le => //.
    eapply equality_eq_le.
  Qed.

  Lemma congr_LetIn {leq Γ na1 na2 t1 t2 A1 A2 u1 u2} :
    eq_binder_annot na1 na2 ->
    Σ;;; Γ ⊢ t1 = t2 ->
    Σ;;; Γ ⊢ A1 = A2 ->
    Σ ;;; Γ ,, vdef na1 t1 A1 ⊢ u1 ≤[leq] u2 ->
    Σ ;;; Γ ⊢ tLetIn na1 t1 A1 u1 ≤[leq] tLetIn na2 t2 A2 u2.
  Proof.
    intros hna ont ona onu.
    etransitivity.
    { eapply congr_LetIn_bo; tea. }
    eapply equality_eq_le_gen.
    etransitivity.
    { eapply conv_LetIn_ty; tea; eauto with fvs. }
    eapply conv_LetIn_tm; tea; eauto with fvs.
    now move/ws_equality_is_open_term_right: onu.
  Qed.

  Lemma it_mkLambda_or_LetIn_conv_cum {leq Γ Δ1 Δ2 t1 t2} :
    closed_conv_context Σ (Γ ,,, Δ1) (Γ ,,, Δ2) ->
    Σ ;;; (Γ ,,, Δ1) ⊢ t1 ≤[leq] t2 ->
    Σ ;;; Γ ⊢ (it_mkLambda_or_LetIn Δ1 t1) ≤[leq] (it_mkLambda_or_LetIn Δ2 t2).
  Proof.
    induction Δ1 in Δ2, t1, t2 |- *; intros X Y.
    - apply All2_fold_length in X.
      destruct Δ2; cbn in *; [trivial|].
      rewrite app_length in X; lia.
    - apply All2_fold_length in X as X'.
      destruct Δ2 as [|c Δ2]; simpl in *; [rewrite app_length in X'; lia|].
      dependent destruction X.
      + eapply IHΔ1; tas; cbn.
        depelim e.
        * eapply congr_Lambda; simpl; tea.
        * eapply congr_LetIn; simpl; tea.
  Qed.

  Lemma it_mkLambda_or_LetIn_conv Γ Δ1 Δ2 t1 t2 :
    Σ ⊢ Γ ,,, Δ1 = Γ ,,, Δ2 ->
    Σ ;;; Γ ,,, Δ1 ⊢ t1 = t2 ->
    Σ ;;; Γ ⊢ it_mkLambda_or_LetIn Δ1 t1 = it_mkLambda_or_LetIn Δ2 t2.
  Proof.
    induction Δ1 in Δ2, t1, t2 |- *; intros X Y.
    - apply All2_fold_length in X.
      destruct Δ2; cbn in *; [trivial|].
      exfalso. rewrite app_length in X; lia.
    - apply All2_fold_length in X as X'.
      destruct Δ2 as [|c Δ2]; simpl in *; [exfalso; rewrite app_length in X'; lia|].
      dependent destruction X.
      + eapply IHΔ1; tas; cbn.
        assert (foo := ws_equality_is_open_term_right Y).
        depelim e.
        * etransitivity.
          { eapply conv_Lambda_r; tea. }
          eapply conv_Lambda_l; tea.
        * etransitivity.
          { eapply conv_LetIn_bo; tea. }
          etransitivity.
          ++ eapply conv_LetIn_tm; tea; cbn; eauto with fvs.
          ++ eapply conv_LetIn_ty; tea; cbn; eauto with fvs.
  Qed.

  Lemma red_lambda_inv Γ na A1 b1 T :
    Σ ;;; Γ ⊢ (tLambda na A1 b1) ⇝ T ->
    ∑ A2 b2, (T = tLambda na A2 b2) ×
        Σ ;;; Γ ⊢ A1 ⇝ A2 × Σ ;;; (Γ ,, vass na A1) ⊢ b1 ⇝ b2.
  Proof.
    intros [onΓ onl ont].
    rewrite on_fvs_lambda in onl.
    move: onl => /=/andP [] onA1 onb1.
    eapply clos_rt_rt1n_iff in ont. depind ont.
    - eexists _, _.
      intuition eauto.
      * eapply closed_red_refl; eauto with fvs.
      * eapply closed_red_refl; eauto with fvs.
    - depelim r; solve_discr; specialize (IHont _ _ _ _ onΓ eq_refl byfvs).
      + forward IHont by tas.
        destruct IHont as [A2 [B2 [-> [? ?]]]].
        eexists _, _; intuition eauto.
        1:{ split; tas. eapply red_step with M' => //. apply c. }
        eapply red_red_ctx_inv'; eauto.
        constructor; auto.
        * now eapply closed_red_ctx_refl.
        * constructor; auto.
          split; tas; pcuic.
      + forward IHont.
        { eapply red1_on_free_vars; tea.
          rewrite (@on_free_vars_ctx_on_ctx_free_vars _ (Γ ,, vass na A1)).
          eauto with fvs. }
          destruct IHont as [A2 [B2 [-> [? ?]]]].
          eexists _, _; intuition eauto.
          split; eauto with fvs. eapply red_step with M' => //.
          apply c0.
  Qed.

  Lemma congr_Lambda_inv :
    forall leq Γ na1 na2 A1 A2 b1 b2,
      Σ ;;; Γ ⊢ tLambda na1 A1 b1 ≤[leq] tLambda na2 A2 b2 ->
      eq_binder_annot na1 na2 × Σ ;;; Γ ⊢ A1 = A2 × Σ ;;; Γ ,, vass na1 A1 ⊢ b1 ≤[leq] b2.
  Proof.
    intros *.
    move/equality_red; intros (v & v' & redv & redv' & eq).
    eapply red_lambda_inv in redv as (A1' & b1' & -> & rA1 & rb1).
    eapply red_lambda_inv in redv' as (v0 & v0' & redv0 & redv0' & eq0).
    subst v'.
    destruct leq; depelim eq.
    { assert (Σ ;;; Γ ⊢ A1 = A2).
      - eapply equality_red.
        exists A1', v0; intuition auto.
      - intuition auto. transitivity b1'; pcuic.
        eapply equality_equality_ctx; revgoals.
        { transitivity v0'; tea. 2:eapply red_equality_inv; tea.
          constructor; tea. 1,3:eauto with fvs.
          now generalize (closed_red_open_right rb1). }
        constructor.
        { eapply closed_context_equality_refl; eauto with fvs. }
        constructor; eauto. }
    { assert (Σ ;;; Γ ⊢ A1 = A2).
      - eapply equality_red.
        exists A1', v0; intuition auto.
      - intuition auto. transitivity b1'; pcuic.
        eapply equality_equality_ctx; revgoals.
        { transitivity v0'; tea. 2:eapply red_equality_inv; tea.
          constructor; tea. 1,3:eauto with fvs.
          now generalize (closed_red_open_right rb1). }
        constructor.
        { eapply closed_context_equality_refl; eauto with fvs. }
        constructor; eauto. }
  Qed.

  Lemma Lambda_conv_cum_inv :
    forall leq Γ na1 na2 A1 A2 b1 b2,
      sq_equality leq Σ Γ (tLambda na1 A1 b1) (tLambda na2 A2 b2) ->
      eq_binder_annot na1 na2 /\ ∥ Σ ;;; Γ ⊢ A1 = A2 ∥ /\ sq_equality leq Σ (Γ ,, vass na1 A1) b1 b2.
  Proof.
    intros * []. eapply congr_Lambda_inv in X.
    intuition auto. all:sq; auto.
  Qed.

End ConvRedConv.

(* Lemma untyped_substitution_conv `{cf : checker_flags} (Σ : global_env_ext) Γ Γ' Γ'' s M N :
  wf Σ -> wf_local Σ (Γ ,,, Γ' ,,, Γ'') ->
  untyped_subslet Γ s Γ' ->
  Σ ;;; Γ ,,, Γ' ,,, Γ'' ⊢ M = N ->
  Σ ;;; Γ ,,, subst_context s 0 Γ'' ⊢ subst s #|Γ''| M = subst s #|Γ''| N.
Proof.
  intros wfΓ Hs. induction 1.
  - cbn. now rewrite !subst_empty /= subst0_context.
  - eapply substitution_untyped_let_red in r. 3:eauto. all:eauto with wf.
    eapply red_conv_conv; eauto.
  - eapply substitution_untyped_let_red in r. 3:eauto. all:eauto with wf.
    eapply red_conv_conv_inv; eauto.
Qed. *)


Section ConvSubst.
  Context {cf : checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ}.

  Import PCUICOnFreeVars.

  Lemma subslet_open {Γ s Γ'} : subslet Σ Γ s Γ' ->
    forallb (is_open_term Γ) s.
  Proof.
    induction 1; simpl; auto.
    - apply subject_closed in t0.
      rewrite (closedn_on_free_vars t0) //.
    - eapply subject_closed in t0.
      rewrite (closedn_on_free_vars t0) //.
  Qed.
  Hint Resolve subslet_open : fvs.

  Lemma closed_red_subst {Γ Δ Γ' s M N} :
    subslet Σ Γ s Δ ->
    Σ ;;; Γ ,,, Δ ,,, Γ' ⊢ M ⇝ N ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| M ⇝ subst s #|Γ'| N.
  Proof.
    intros Hs H. split.
    - eapply is_closed_subst_context; eauto with fvs pcuic.
      eapply (subslet_length Hs).
    - eapply is_open_term_subst; tea; eauto with fvs pcuic.
      eapply (subslet_length Hs).
    - eapply substitution_untyped_red; tea; eauto with fvs.
      now eapply subslet_untyped_subslet.
  Qed.

  Lemma substitution_equality {le Γ Γ' Γ'' s M N} :
    subslet Σ Γ s Γ' ->
    Σ ;;; Γ ,,, Γ' ,,, Γ'' ⊢ M ≤[le] N ->
    Σ ;;; Γ ,,, subst_context s 0 Γ'' ⊢ subst s #|Γ''| M ≤[le] subst s #|Γ''| N.
  Proof.
    intros Hs. induction 1.
    - cbn. constructor; eauto with fvs.
      { eapply is_closed_subst_context; tea; eauto with fvs.
        now apply (subslet_length Hs). }
      { eapply is_open_term_subst; tea; eauto with fvs.
        now eapply (subslet_length Hs). }
      { eapply is_open_term_subst; tea; eauto with fvs.
        now apply (subslet_length Hs). }
      destruct le. 2:now apply subst_eq_term.
      now apply subst_leq_term.
    - eapply red_equality_left; tea.
      eapply closed_red_subst; tea.
      constructor; eauto.
    - eapply red_equality_right; tea.
      eapply closed_red_subst; tea.
      constructor; eauto.
  Qed.

  Derive Signature for untyped_subslet.

  Lemma equality_substs_red {Γ Δ s s'} : 
    All2 (ws_equality false Σ Γ) s s' ->
    untyped_subslet Γ s Δ ->
    (∑ s0 s'0, All2 (closed_red Σ Γ) s s0 × All2 (closed_red Σ Γ) s' s'0 × All2 (eq_term Σ Σ) s0 s'0).
  Proof.
    move=> eqsub subs.
    induction eqsub in Δ, subs |- *.
    * depelim subs. exists [], []; split; auto.
    * depelim subs.
    - specialize (IHeqsub _ subs) as [s0 [s'0 [redl [redr eqs0]]]].
      eapply equality_red in r as [v [v' [redv [redv' eqvv']]]].
      exists (v :: s0), (v' :: s'0). repeat split; constructor; auto.
    - specialize (IHeqsub _ subs) as [s0 [s'0 [redl [redr eqs0]]]].
      eapply equality_red in r as [v [v' [redv [redv' eqvv']]]].
      exists (v :: s0), (v' :: s'0). repeat split; constructor; auto.
  Qed.

  Lemma All2_fold_fold_context_k P (f g : nat -> term -> term) ctx ctx' :
    All2_fold (fun Γ Γ' d d' => P (fold_context_k f Γ) (fold_context_k g Γ') 
    (map_decl (f #|Γ|) d) (map_decl (g #|Γ'|) d')) ctx ctx' ->
    All2_fold P (fold_context_k f ctx) (fold_context_k g ctx').
  Proof.
    intros a. rewrite - !mapi_context_fold.
    eapply All2_fold_mapi.
    eapply PCUICContextRelation.All2_fold_impl_ind; tea.
    intros par par' x y H IH; cbn.
    rewrite !mapi_context_fold.
    now rewrite -(length_of H).
  Qed.

  Import PCUICInst.

  Lemma All_decls_alpha_le_impl le P Q d d' : 
    All_decls_alpha_le le P d d' ->
    (forall le x y, P le x y -> Q le x y) ->
    All_decls_alpha_le le Q d d'.
  Proof.
    intros [] H; constructor; auto.
  Qed.

  Lemma All_decls_alpha_le_map le P f g d d' : 
    All_decls_alpha_le le (fun le x y => P le (f x) (g y)) d d' ->
    All_decls_alpha_le le P (map_decl f d) (map_decl g d').
  Proof.
    intros []; constructor; cbn; auto.
  Qed.

  Lemma test_decl_conv_decls_map {Γ Γ' : context} {p f g} {d : context_decl} :
    test_decl p d ->
    (forall x, p x -> conv Σ Γ (f x) (g x)) ->
    conv_decls Σ Γ Γ' (map_decl f d) (map_decl g d).
  Proof.
    intros ht hxy.
    destruct d as [na [b|] ty]; cbn; constructor; red; eauto.
    - move/andP: ht => /= [] pb pty; eauto.
    - move/andP: ht => /= [] pb pty; eauto.
  Qed.
    
  Lemma closed_red_red_subst_context {Γ Δ Γ' s s'} : 
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    All2 (closed_red Σ Γ) s s' ->
    untyped_subslet Γ s Δ ->
    Σ ⊢ Γ ,,, subst_context s 0 Γ' = Γ ,,, subst_context s' 0 Γ'.
  Proof.
    intros.
    eapply into_closed_context_equality.
    { eapply is_closed_subst_context; tea; solve_all; eauto with fvs.
      apply (untyped_subslet_length X0). }
    { eapply is_closed_subst_context; tea; solve_all; eauto with fvs.
      rewrite -(All2_length X). apply (untyped_subslet_length X0). }
    eapply All2_fold_app; len => //; try reflexivity.
    eapply All2_fold_fold_context_k.
    induction Γ'; constructor; auto.
    { apply IHΓ'. move: H; rewrite /= on_free_vars_ctx_snoc => /andP[] //. }
    move: H; rewrite /= on_free_vars_ctx_snoc => /andP[] // iscl wsdecl.
    eapply test_decl_conv_decls_map; tea.
    intros x hx.
    eapply PCUICCumulativity.red_conv. 
    rewrite - !/(subst_context _ _ _) Nat.add_0_r.
    eapply red_red; tea.
    { erewrite on_free_vars_ctx_on_ctx_free_vars; tea. }
    { solve_all; pcuic. exact X1. }
    { solve_all. rewrite !app_length Nat.add_assoc -shiftnP_add addnP_shiftnP.
      eauto with fvs. }
  Qed.

  Lemma subst_context_app0 s Γ Γ' : 
    subst_context s 0 Γ ,,, subst_context s #|Γ| Γ' = 
    subst_context s 0 (Γ ,,, Γ').
  Proof.
    now rewrite -(Nat.add_0_r #|Γ|) subst_context_app.
  Qed.

  (*Lemma conv_ctx_subst {Γ Γ' Γ'0 Γ'' Δ Δ' s s'} :
    wf_local Σ (Γ ,,, Γ' ,,, Γ'' ,,, Δ) ->
    context_equality_rel Σ false (Γ ,,, Γ' ,,, Γ'') Δ Δ' ->
    All2 (ws_equality false Σ Γ) s s' ->
    untyped_subslet Γ s Γ' ->
    untyped_subslet Γ s' Γ'0 ->
    context_equality_rel Σ false (Γ ,,, subst_context s 0 Γ'') (subst_context s #|Γ''| Δ) (subst_context s' #|Γ''| Δ').
  Proof.
    intros wf [cl H] Hs subs subs'.
    split.
    { eapply is_closed_subst_context; tea. 1:solve_all; eauto with fvs.
      apply (untyped_subslet_length subs). }
    rewrite !subst_context_inst_context.
    rewrite /PCUICInst.inst_context.
    eapply All2_fold_fold_context_k, All2_fold_impl_ind; tea; clear H.
    cbn. intros Γ0 Δ0 d d' H IH Hd.
    eapply All_decls_alpha_le_map, All_decls_alpha_le_impl; tea.
    intros le x y; cbn.
    rewrite - !/(inst_context _ _).
    intros eq.


  Admitted.*)

  Lemma eq_context_upto_context_equality {le Γ Γ'} : 
    is_closed_context Γ ->
    is_closed_context Γ' ->
    eq_context_upto Σ (eq_universe Σ) (compare_universe le Σ) Γ Γ' ->
    closed_context_equality le Σ Γ Γ'.
  Proof.
    intros cl cl' eq.
    apply into_closed_context_equality; auto.
    destruct le.
    { now eapply eq_context_upto_univ_cumul_context. }
    { now eapply eq_context_upto_univ_conv_context. }
  Qed.

  Lemma context_equality_subst {Γ Δ Δ' Γ' s s'} : 
    untyped_subslet Γ s Δ ->
    untyped_subslet Γ s' Δ' ->
    All2 (ws_equality false Σ Γ) s s' ->
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    is_closed_context (Γ ,,, Δ' ,,, Γ') ->
    Σ ⊢ Γ ,,, subst_context s 0 Γ' = Γ ,,, subst_context s' 0 Γ'.
  Proof.
    move=> subs subs' eqsub cl cl'.
    destruct (equality_substs_red eqsub subs) as (s0 & s'0 & rs' & rs'0 & eqs).
    transitivity (Γ ,,, subst_context s0 0 Γ').
    { eapply closed_red_red_subst_context; revgoals; tea. }
    symmetry. transitivity (Γ ,,, subst_context s'0 0 Γ').
    { eapply closed_red_red_subst_context; revgoals; tea. }
    eapply eq_context_upto_context_equality.
    { clear eqs; eapply is_closed_subst_context; tea; solve_all; eauto with fvs.
      rewrite -(All2_length rs'0). apply (untyped_subslet_length subs'). }
    { clear eqs; eapply is_closed_subst_context; tea; solve_all; eauto with fvs.
      rewrite -(All2_length rs') (All2_length eqsub). apply (untyped_subslet_length subs'). }
    eapply eq_context_upto_cat; try reflexivity.
    apply eq_context_upto_subst_context; tc; try reflexivity.
    eapply All2_symP; tc. assumption.
  Qed.

  Lemma equality_subst_conv {Γ Δ Δ' Γ' s s' b} : 
    All2 (ws_equality false Σ Γ) s s' ->
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    is_closed_context (Γ ,,, Δ' ,,, Γ') ->
    untyped_subslet Γ s Δ ->
    untyped_subslet Γ s' Δ' ->
    is_open_term (Γ ,,, Δ ,,, Γ') b ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| b = subst s' #|Γ'| b.
  Proof.
    move=> eqsub cl cl' subs subs' clb.
    assert(∑ s0 s'0, All2 (closed_red Σ Γ) s s0 × All2 (closed_red Σ Γ) s' s'0 × All2 (eq_term Σ Σ) s0 s'0)
      as [s0 [s'0 [redl [redr eqs]]]].
    { apply (equality_substs_red eqsub subs). }
    etransitivity.
    * apply red_conv. apply (closed_red_red_subst (Δ := Δ) (s' := s0)); tas.
    * symmetry; etransitivity.
    ** eapply equality_equality_ctx; revgoals.
      + apply red_conv. eapply (closed_red_red_subst (Δ := Δ') (s' := s'0)); tea.
        rewrite !app_length -(untyped_subslet_length subs') -(All2_length eqsub).
        rewrite (untyped_subslet_length subs) - !app_length //.
      + eapply context_equality_subst; tea.
    ** assert (All (is_open_term Γ) s0) by (eapply (All2_All_right redl); eauto with fvs).
      assert (All (is_open_term Γ) s'0) by (eapply (All2_All_right redr); eauto with fvs).
      eapply ws_equality_refl.
      { eapply (is_closed_subst_context _ Δ); tea. 1:solve_all; eauto with fvs.
        apply (untyped_subslet_length subs). }
      { eapply is_open_term_subst_gen. 6:tea. all:tea; solve_all; eauto with fvs.
        1:apply (untyped_subslet_length subs).
        now rewrite (All2_length eqsub) (All2_length redr). }
      { eapply is_open_term_subst_gen. 6:tea. all:tea; solve_all; eauto with fvs.
        1:apply (untyped_subslet_length subs).
        now rewrite (All2_length redl). }
      cbn; symmetry.
      eapply eq_term_upto_univ_substs; tc; try reflexivity.
      solve_all.
  Qed.

  Lemma subst_equality {le Γ Γ0 Γ1 Δ s s' T U} :
    subslet Σ Γ s Γ0 ->
    subslet Σ Γ s' Γ1 ->
    All2 (ws_equality false Σ Γ) s s' ->
    is_closed_context (Γ ,,, Γ1) ->
    Σ;;; Γ ,,, Γ0 ,,, Δ ⊢ T ≤[le] U ->
    Σ;;; Γ ,,, subst_context s 0 Δ ⊢ subst s #|Δ| T ≤[le] subst s' #|Δ| U.
  Proof.
    move=> subss subss' eqsub cl eqty.
    generalize (ws_equality_is_open_term eqty) => /and3P[] clctx clT clU.
    assert (#|Γ0| = #|Γ1|).
    { rewrite -(subslet_length subss) -(subslet_length subss').
      apply (All2_length eqsub). }
    assert (is_open_term (Γ ,,, Γ1 ,,, Δ) U).
    { move: clU. now rewrite !app_context_length H. }
    assert (is_open_term (Γ ,,, Γ1 ,,, Δ) T).
    { move: clT. now rewrite !app_context_length H. }
    assert (is_closed_context (Γ ,,, Γ1 ,,, Δ)).
    { rewrite on_free_vars_ctx_app cl /=.
      move: clctx. rewrite on_free_vars_ctx_app !app_context_length H => /andP[] //. }
    etransitivity.
    * eapply substitution_equality; tea.
    * eapply equality_eq_le_gen.
      eapply (equality_subst_conv (Δ := Γ0) (Δ' := Γ1)); tea; eauto using subslet_untyped_subslet.
  Qed.

  (* 
  Lemma All2_fold_subst {Γ Γ0 Γ1 Δ Δ' s s'} :
    wf_local Σ (Γ ,,, Γ0 ,,, Δ) ->
    subslet Σ Γ s Γ0 ->
    subslet Σ Γ s' Γ1 ->
    All2 (conv Σ Γ) s s' ->
    All2_fold
    (fun Γ0 Γ' : context => conv_decls Σ (Γ ,,, Γ0) (Γ ,,, Γ'))
    (Γ0 ,,, Δ)
    (Γ1 ,,, Δ') ->
    All2_fold
    (fun Γ0 Γ' : context => conv_decls Σ (Γ ,,, Γ0) (Γ ,,, Γ'))
    (subst_context s 0 Δ)
    (subst_context s' 0 Δ').
  Proof.
    move=> wfl subss subss' eqsub ctxr.
    assert (hlen: #|Γ0| = #|Γ1|).
    { rewrite -(subslet_length subss) -(subslet_length subss').
      now apply All2_length in eqsub. }
    assert(clen := All2_fold_length ctxr).
    autorewrite with len in clen. rewrite hlen in clen.
    assert(#|Δ| = #|Δ'|) by lia.
    clear clen.
    move: Δ' wfl ctxr H.
    induction Δ as [|d Δ]; intros * wfl ctxr len0; destruct Δ' as [|d' Δ']; simpl in len0; try lia.
    - constructor.
    - rewrite !subst_context_snoc. specialize (IHΔ Δ'). depelim wfl; specialize (IHΔ wfl);
      depelim ctxr; depelim c; noconf len0; simpl.
      * constructor; auto. constructor; tas. simpl.
        ** rewrite !Nat.add_0_r -H. red.
          eapply subst_conv; eauto. now rewrite -app_context_assoc.
      * constructor; auto. constructor; tas; simpl;
        rewrite !Nat.add_0_r -H;
        eapply subst_conv; eauto; now rewrite -app_context_assoc.
  Qed. *)

  Lemma ws_equality_elim {le} {Γ} {x y} :
    ws_equality le Σ Γ x y ->
    [× is_closed_context Γ, is_open_term Γ x, is_open_term Γ y &
    if le then cumul Σ Γ x y else conv Σ Γ x y].
  Proof.
    intros ws.
    repeat split; eauto with fvs.
    now eapply ws_equality_forget in ws.
  Qed.

  Lemma is_closed_context_lift Γ Γ'' Γ' :
    is_closed_context (Γ,,, Γ') ->
    is_closed_context (Γ,,, Γ'') ->
    is_closed_context (Γ,,, Γ'',,, lift_context #|Γ''| 0 Γ').
  Proof.
    move=> cl cl'.
    rewrite on_free_vars_ctx_app cl' /=.
    rewrite on_free_vars_ctx_lift_context0 //.
    rewrite app_length -shiftnP_add addnP_shiftnP //.
    move: cl. rewrite on_free_vars_ctx_app => /andP[] //.
  Qed.
  Hint Resolve is_closed_context_lift : fvs.

  Lemma is_open_term_lift Γ Γ' Γ'' t :
    is_open_term (Γ ,,, Γ') t ->
    is_open_term (Γ ,,, Γ'' ,,, lift_context #|Γ''| 0 Γ') (lift #|Γ''| #|Γ'| t).
  Proof.
    intros op.
    eapply on_free_vars_impl.
    2:erewrite on_free_vars_lift; tea.
    intros i.
    rewrite /strengthenP /shiftnP /= !orb_false_r !app_length lift_context_length.
    repeat nat_compare_specs => //.
  Qed.
  Hint Resolve is_open_term_lift : fvs.

  Lemma weakening_equality {le Γ Γ' Γ'' M N} :
    Σ ;;; Γ ,,, Γ' ⊢ M ≤[le] N ->
    is_closed_context (Γ ,,, Γ'') ->
    Σ ;;; Γ ,,, Γ'' ,,, lift_context #|Γ''| 0 Γ' ⊢ lift #|Γ''| #|Γ'| M ≤[le] lift #|Γ''| #|Γ'| N.
  Proof.
    move=> /ws_equality_elim [] iscl onM onN eq onΓ''.
    eapply into_ws_equality; eauto with fvs.
    destruct le.
    { eapply weakening_cumul in eq; eauto with fvs. }
    { eapply weakening_conv in eq; eauto with fvs. }
  Qed.

  Lemma weakening_equality_eq {Γ Γ' Γ'' : context} {M N : term} k :
    k = #|Γ''| ->
    Σ;;; Γ ,,, Γ' ⊢ M = N ->
    is_closed_context (Γ ,,, Γ'') ->
    Σ;;; Γ ,,, Γ'' ,,, lift_context k 0 Γ' ⊢ lift k #|Γ'| M = lift k #|Γ'| N.
  Proof.
    intros -> conv; eapply weakening_equality; auto.
  Qed.

  Lemma weaken_equality {le Γ t u} Δ :
    is_closed_context Δ ->
    is_open_term Γ t -> 
    is_open_term Γ u ->
    Σ ;;; Γ ⊢ t ≤[le] u ->
    Σ ;;; Δ ,,, Γ ⊢ t ≤[le] u.
  Proof.
    move=> clΔ clt clu a.
    epose proof (weakening_equality (Γ := []) (Γ'' := Δ)).
    rewrite !app_context_nil_l in X.
    specialize (X a clΔ).
    rewrite !lift_closed in X => //; eauto with fvs.
    rewrite closed_ctx_lift in X.
    1:rewrite is_closed_ctx_closed //; eauto with fvs.
    assumption.
  Qed.

End ConvSubst.

Notation "x @[ u ]" := (subst_instance u x) (at level 2, 
  format "x @[ u ]").

Hint Rewrite @on_free_vars_subst_instance : fvs.
Hint Rewrite @on_free_vars_subst_instance_context subst_instance_length : fvs.

Lemma conv_subst_instance {cf : checker_flags} (Σ : global_env_ext) Γ u A B univs :
  valid_constraints (global_ext_constraints (Σ.1, univs))
                    (subst_instance_cstrs u Σ) ->
  Σ ;;; Γ ⊢ A = B ->
  (Σ.1,univs) ;;; Γ@[u] ⊢ A@[u] = B@[u].
Proof.
  intros HH X0. induction X0.
  - econstructor. 1-3:eauto with fvs.
    eapply eq_term_subst_instance; tea.
  - econstructor 2; revgoals; cycle 1.
    { eapply (red1_subst_instance Σ.1 Γ u t v r). }
    all:eauto with fvs.
  - econstructor 3. 6:eapply red1_subst_instance; cbn; eauto.
    all: eauto with fvs.
Qed.

Implicit Types (cf : checker_flags) (Σ : global_env_ext).

Definition context_equality_rel {cf} le Σ Γ Δ Δ' :=
  is_closed_context Γ ×
  All2_fold (fun Γ' _ => All_decls_alpha_le le (fun le x y => Σ ;;; Γ ,,, Γ' ⊢ x ≤[le] y)) Δ Δ'.    

Lemma context_equality_rel_app {cf} {Σ} {wfΣ : wf Σ} {le Γ Δ Δ'} :
  context_equality_rel le Σ Γ Δ Δ' <~> closed_context_equality le Σ (Γ ,,, Δ) (Γ ,,, Δ').
Proof.
  split; intros h.
  + eapply All2_fold_app => //.
    * now apply (length_of (snd h)).
    * destruct h. now apply closed_context_equality_refl.
    * eapply All2_fold_impl; tea. 1:apply h.
      intros ???? []; constructor; auto.
  + eapply All2_fold_app_inv in h as [].
    2:{ move: (length_of h). len; lia. }
    split.
    { now apply closed_context_equality_closed_left in a. }
    eapply All2_fold_impl; tea => /=.
    intros ???? []; constructor; auto.
Qed.

Lemma conv_context_subst_instance {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ} {Δ u u'} leq :
  wf_local Σ (subst_instance u Δ) ->
  R_universe_instance (eq_universe (global_ext_constraints Σ)) u u' ->
  closed_context_equality leq Σ (subst_instance u Δ) (subst_instance u' Δ).
Proof.
  move=> wf equ.
  eapply All2_fold_map.
  induction Δ as [|d Δ] in wf |- *.
  - constructor.
  - simpl. depelim wf.
    * cbn; constructor. 
      + apply IHΔ => //.
      + destruct d as [na [b|] ty]; constructor; cbn in *; auto; try congruence.
        destruct l as [s Hs].
        constructor. 1:eauto with fvs.
        { now eapply subject_closed in Hs; rewrite is_open_term_closed in Hs. }
        { erewrite on_free_vars_subst_instance.
          eapply subject_closed in Hs; rewrite is_open_term_closed in Hs.
          now rewrite on_free_vars_subst_instance in Hs. }
        destruct leq; apply eq_term_upto_univ_subst_instance; try typeclasses eauto; auto.
    * cbn; constructor. 
      + apply IHΔ => //.
      + destruct d as [na [b'|] ty]; constructor; cbn in *; auto; try congruence; noconf H.
        { destruct l as [s Hs].
          constructor. 1:eauto with fvs.
          { now eapply subject_closed in l0; rewrite is_open_term_closed in l0. }
          { erewrite on_free_vars_subst_instance.
            eapply subject_closed in l0; rewrite is_open_term_closed in l0.
            now rewrite on_free_vars_subst_instance in l0. }
          apply eq_term_upto_univ_subst_instance; try typeclasses eauto. auto. }
        { destruct l as [s Hs].
          constructor. 1:eauto with fvs.
          { now eapply subject_closed in Hs; rewrite is_open_term_closed in Hs. }
          { erewrite on_free_vars_subst_instance.
            eapply subject_closed in Hs; rewrite is_open_term_closed in Hs.
            now rewrite on_free_vars_subst_instance in Hs. }
          destruct leq; apply eq_term_upto_univ_subst_instance; try typeclasses eauto; auto. }
Qed.

Lemma cumul_ctx_subst_instance {cf:checker_flags} {Σ} Γ Δ u u' :
  wf Σ.1 ->
  wf_local Σ Γ ->
  R_universe_instance (eq_universe (global_ext_constraints Σ)) u u' ->
  cumul_ctx_rel Σ Γ (subst_instance u Δ) (subst_instance u' Δ).
Proof.
  move=> wfΣ wf equ.
  induction Δ as [|d Δ].
  - constructor.
  - simpl.
    destruct d as [na [b|] ty] => /=.
    * constructor; eauto. simpl. constructor. 
      + reflexivity.
      + constructor.
        eapply eq_term_upto_univ_subst_instance; try typeclasses eauto; auto.
      + constructor. eapply eq_term_leq_term.
        eapply eq_term_upto_univ_subst_instance; try typeclasses eauto; auto.
    * constructor; auto.
      constructor; auto. simpl. constructor.
      apply eq_term_upto_univ_subst_instance; try typeclasses eauto. auto.
Qed.

Lemma All2_fold_over_same {cf:checker_flags} Σ Γ Δ Δ' :
  All2_fold (fun Γ0 Γ'  => conv_decls Σ (Γ ,,, Γ0) (Γ ,,, Γ')) Δ Δ' ->
  All2_fold (conv_decls Σ) (Γ ,,, Δ) (Γ ,,, Δ').
Proof.
  induction 1; simpl; try constructor; pcuic.
Qed.

Lemma All2_fold_over_same_app {cf:checker_flags} Σ Γ Δ Δ' :
  All2_fold (conv_decls Σ) (Γ ,,, Δ) (Γ ,,, Δ') ->
  All2_fold (fun Γ0 Γ' => conv_decls Σ (Γ ,,, Γ0) (Γ ,,, Γ')) Δ Δ'.
Proof.
  move=> H. pose (All2_fold_length H).
  autorewrite with len in e. assert(#|Δ| = #|Δ'|) by lia.
  move/All2_fold_app_inv: H => H.
  now specialize (H H0) as [_ H].
Qed.

Lemma eq_term_inds {cf:checker_flags} (Σ : global_env_ext) u u' ind mdecl :
  R_universe_instance (eq_universe (global_ext_constraints Σ)) u u' ->
  All2 (eq_term Σ Σ) (inds (inductive_mind ind) u (ind_bodies mdecl))
    (inds (inductive_mind ind) u' (ind_bodies mdecl)).
Proof.
  move=> equ.
  unfold inds. generalize #|ind_bodies mdecl|.
  induction n; constructor; auto.
  clear IHn.
  repeat constructor. destruct ind; simpl in *.
  eapply (R_global_instance_empty_impl _ _ _ _ _ _ 0).
  4:{ unfold R_global_instance. simpl. eauto. }
  all:typeclasses eauto.
Qed.

Lemma conv_inds {cf:checker_flags} (Σ : global_env_ext) Γ u u' ind mdecl :
  R_universe_instance (eq_universe (global_ext_constraints Σ)) u u' ->
  is_closed_context Γ ->
  All2 (ws_equality false Σ Γ) (inds (inductive_mind ind) u (ind_bodies mdecl))
    (inds (inductive_mind ind) u' (ind_bodies mdecl)).
Proof.
  move=> equ.
  unfold inds. generalize #|ind_bodies mdecl|.
  induction n; constructor; auto.
  clear IHn.
  repeat constructor; auto. destruct ind; simpl in *.
  eapply (R_global_instance_empty_impl _ _ _ _ _ _ 0).
  4:{ unfold R_global_instance. simpl. eauto. }
  all:typeclasses eauto.
Qed.

Lemma R_global_instance_length Σ Req Rle ref napp i i' :
  R_global_instance Σ Req Rle ref napp i i' -> #|i| = #|i'|.
Proof.
  unfold R_global_instance.
  destruct global_variance.
  { induction i in l, i' |- *; destruct l, i'; simpl; auto; try lia; try easy.
    * specialize (IHi i' []). simpl in IHi. intuition.
    * intros []. intuition.
    }
  { unfold R_universe_instance.
    intros H % Forall2_length. now rewrite !map_length in H. }
Qed.

Lemma R_universe_instance_variance_irrelevant Re Rle i i' :
  #|i| = #|i'| ->
  R_universe_instance_variance Re Rle [] i i'.
Proof.
  now induction i in i' |- *; destruct i'; simpl; auto.
Qed.

Lemma congr_it_mkProd_or_LetIn {cf leq Σ} {wfΣ : wf Σ} (Δ Γ Γ' : context) (B B' : term) :
  context_equality_rel false Σ Δ Γ Γ' ->
  Σ ;;; Δ ,,, Γ ⊢ B ≤[leq] B' ->
  Σ ;;; Δ ⊢ it_mkProd_or_LetIn Γ B ≤[leq] it_mkProd_or_LetIn Γ' B'.
Proof.
  intros [_ cv].
  move: B B' Γ' Δ cv.
  induction Γ as [|d Γ] using rev_ind; move=> B B' Γ' Δ;
  destruct Γ' as [|d' Γ'] using rev_ind; try clear IHΓ';
    move=> H; try solve [simpl; auto].
  + depelim H. apply app_eq_nil in H; intuition discriminate.
  + depelim H. apply app_eq_nil in H; intuition discriminate.
  + assert (clen : #|Γ| = #|Γ'|).
    { apply All2_fold_length in H.
      autorewrite with len in H; simpl in H. lia. }
    apply All2_fold_app_inv in H as [cd cctx] => //.
    depelim cd; depelim a.
    - rewrite !it_mkProd_or_LetIn_app => //=.
      simpl. move=> HB. apply congr_prod => /= //.
      eapply IHΓ.
      * unshelve eapply (All2_fold_impl cctx).
        simpl. intros ? ? * X. now rewrite !app_context_assoc in X.
      * now rewrite app_context_assoc in HB.
    - rewrite !it_mkProd_or_LetIn_app => //=.
      simpl. intros HB. cbn. apply congr_LetIn => //; auto.
      eapply IHΓ.
      * unshelve eapply (All2_fold_impl cctx).
        simpl. intros ?? * X. now rewrite !app_context_assoc in X.
      * now rewrite app_context_assoc in HB.
Qed.

Lemma congr_it_mkLambda_or_LetIn {cf leq Σ} {wfΣ : wf Σ} (Δ Γ Γ' : context) (B B' : term) :
  context_equality_rel false Σ Δ Γ Γ' ->
  Σ ;;; Δ ,,, Γ ⊢ B ≤[leq] B' ->
  Σ ;;; Δ ⊢ it_mkLambda_or_LetIn Γ B ≤[leq] it_mkLambda_or_LetIn Γ' B'.
Proof.
  intros [_ cv].
  move: B B' Γ' Δ cv.
  induction Γ as [|d Γ] using rev_ind; move=> B B' Γ' Δ;
  destruct Γ' as [|d' Γ'] using rev_ind; try clear IHΓ';
    move=> H; try solve [simpl; auto].
  + depelim H. apply app_eq_nil in H; intuition discriminate.
  + depelim H. apply app_eq_nil in H; intuition discriminate.
  + assert (clen : #|Γ| = #|Γ'|).
    { apply All2_fold_length in H.
      autorewrite with len in H; simpl in H. lia. }
    apply All2_fold_app_inv in H as [cd cctx] => //.
    depelim cd; depelim a.
    - rewrite !it_mkLambda_or_LetIn_app => //=.
      simpl. move=> HB. apply congr_Lambda => /= //.
      eapply IHΓ.
      * unshelve eapply (All2_fold_impl cctx).
        simpl. intros ? ? * X. now rewrite !app_context_assoc in X.
      * now rewrite app_context_assoc in HB.
    - rewrite !it_mkLambda_or_LetIn_app => //=.
      simpl. intros HB. cbn. apply congr_LetIn => //; auto.
      eapply IHΓ.
      * unshelve eapply (All2_fold_impl cctx).
        simpl. intros ?? * X. now rewrite !app_context_assoc in X.
      * now rewrite app_context_assoc in HB.
Qed.

Require Import CMorphisms.
Notation conv_terms Σ Γ := (All2 (ws_equality false Σ Γ)).
Instance conv_terms_Proper {cf:checker_flags} Σ Γ : CMorphisms.Proper (eq ==> eq ==> arrow)%signature (conv_terms Σ Γ).
Proof. intros x y -> x' y' -> f. exact f. Qed.

Instance conv_terms_trans {cf} Σ {wfΣ : wf Σ} Γ : Transitive (conv_terms Σ Γ).
Proof.
  intros x y z.
  eapply All2_trans; tc.
Qed.

Instance conv_terms_sym {cf} Σ {wfΣ : wf Σ} Γ : Symmetric (conv_terms Σ Γ).
Proof.
  intros x y.
  eapply All2_symP; tc.
Qed.

Section ConvTerms.
  Context {cf} {Σ} {wfΣ : wf Σ}.

  Lemma conv_terms_alt {Γ args args'} :
    conv_terms Σ Γ args args' <~>
    ∑ argsr argsr',
      All2 (closed_red Σ Γ) args argsr ×
      All2 (closed_red Σ Γ) args' argsr' ×
      All2 (eq_term Σ Σ) argsr argsr'.
  Proof.
    split.
    - intros conv.
      induction conv.
      + exists [], []; eauto with pcuic.
      + apply equality_red in r as (xr&yr&xred&yred&xy).
        specialize IHconv as (argsr&argsr'&?&?&?).
        exists (xr :: argsr), (yr :: argsr').
        eauto 7 with pcuic.
    - intros (argsr&argsr'&r&r'&eqs).
      induction eqs in args, args', r, r' |- *; depelim r; depelim r'; [constructor|].
      constructor; auto.
      apply equality_red; eauto.
  Qed.

  Lemma conv_terms_conv_ctx {Γ Γ' ts ts'} :
    closed_conv_context Σ Γ Γ' ->
    conv_terms Σ Γ ts ts' ->
    conv_terms Σ Γ' ts ts'.
  Proof.
    intros ctx conv.
    induction conv; [constructor|].
    constructor; auto.
    eapply PCUICContextConversion.equality_equality_ctx_inv; eauto.
  Qed.

  Lemma conv_terms_red {Γ ts ts' tsr tsr'} :
    All2 (closed_red Σ Γ) ts tsr ->
    All2 (closed_red Σ Γ) ts' tsr' ->
    conv_terms Σ Γ tsr tsr' ->
    conv_terms Σ Γ ts ts'.
  Proof.
    intros all all' conv.
    induction conv in ts, ts', all, all' |- *; depelim all; depelim all'; [constructor|].
    constructor; [|auto].
    eapply red_equality_left; tea.
    symmetry.
    eapply red_equality_left; eauto.
    now symmetry.
  Qed.

  Lemma conv_terms_red_inv {Γ ts ts' tsr tsr'} :
    All2 (closed_red Σ Γ) ts tsr ->
    All2 (closed_red Σ Γ) ts' tsr' ->
    conv_terms Σ Γ ts ts' ->
    conv_terms Σ Γ tsr tsr'.
  Proof.
    intros all all' conv.
    induction conv in tsr, tsr', all, all' |- *; depelim all; depelim all'; [constructor|].
    constructor; [|auto].
    eapply conv_red_l_inv with x; eauto with fvs.
    symmetry.
    eapply conv_red_l_inv with y0; eauto with fvs.
    now symmetry.
  Qed.

  Lemma conv_terms_red_conv {Γ Γ' ts ts' tsr tsr'} :
    closed_conv_context Σ Γ Γ' ->
    All2 (closed_red Σ Γ) ts tsr ->
    All2 (closed_red Σ Γ') ts' tsr' ->
    conv_terms Σ Γ tsr tsr' ->
    conv_terms Σ Γ ts ts'.
  Proof.
    intros convctx all all2 conv.
    transitivity tsr.
    { solve_all. now eapply red_conv. }
    symmetry.
    transitivity tsr'.
    { solve_all. eapply equality_equality_ctx; tea.
      now eapply red_conv. }
    now symmetry.
  Qed.

  Lemma conv_terms_weaken {Γ Γ' args args'} :
    wf_local Σ Γ ->
    wf_local Σ Γ' ->
    conv_terms Σ Γ args args' ->
    conv_terms Σ (Γ' ,,, Γ) args args'.
  Proof.
    intros wf wf' conv.
    solve_all.
    eapply weaken_equality; eauto with fvs.
  Qed.

  Lemma conv_terms_subst {Γ Γ' Γ'' Δ s s' args args'} :
    is_closed_context (Γ ,,, Γ'') ->
    subslet Σ Γ s Γ' ->
    subslet Σ Γ s' Γ'' ->
    conv_terms Σ Γ s s' ->
    conv_terms Σ (Γ ,,, Γ' ,,, Δ) args args' ->
    conv_terms Σ (Γ ,,, subst_context s 0 Δ) (map (subst s #|Δ|) args) (map (subst s' #|Δ|) args').
  Proof.
    intros wf cl cl' convs conv.
    eapply All2_map.
    eapply (All2_impl conv).
    intros x y eqxy.
    eapply subst_equality; eauto with fvs.
  Qed.
  
End ConvTerms.

Section CumulSubst.
  Context {cf} {Σ} {wfΣ : wf Σ}.

  Lemma equality_subst_conv' {le Γ Δ Δ' Γ' s s' b} :
    is_closed_context (Γ ,,, Δ ,,, Γ') ->
    is_closed_context (Γ ,,, Δ') ->
    is_open_term (Γ ,,, Δ ,,, Γ') b ->
    conv_terms Σ Γ s s' ->
    subslet Σ Γ s Δ ->
    subslet Σ Γ s' Δ' ->
    Σ ;;; Γ ,,, subst_context s 0 Γ' ⊢ subst s #|Γ'| b ≤[le] subst s' #|Γ'| b.
  Proof.
    move=> cl cl' clb eqsub subs subs'.
    eapply equality_eq_le_gen.
    eapply subst_equality; tea; eauto with pcuic.
  Qed.

  (* Lemma subst_cumul {le Γ Γ0 Γ1 Δ s s' T U} :
    untyped_subslet Γ s Γ0 ->
    untyped_subslet Γ s' Γ1 ->
    is_closed_context (Γ ,,, Γ1) ->
    conv_terms Σ Γ s s' ->
    wf_local Σ (Γ ,,, Γ0 ,,, Δ) ->
    Σ;;; Γ ,,, Γ0 ,,, Δ ⊢ T ≤[le] U ->
    Σ;;; Γ ,,, subst_context s 0 Δ ⊢ subst s #|Δ| T ≤[le] subst s' #|Δ| U.
  Proof.
    move=> subss subss' cl eqsub wfctx eqty.
    etransitivity.
    { eapply equality_eq_le_gen.
      eapply equality_subst_conv; tea => //. all:eauto with fvs.
      admit. }
    eapply equality_equality_ctx.
    2:{ eapply substitution_equality; tea.
  Qed. *)
    
  (* Lemma untyped_subst_cumul {Γ Γ0 Γ1 Δ s s' T U} :
    untyped_subslet Γ s Γ0 ->
    untyped_subslet Γ s' Γ1 ->
    is_closed_context (Γ ,,, Γ1) ->
    All2 (conv Σ Γ) s s' ->
    wf_local Σ (Γ ,,, Γ0 ,,, Δ) ->
    Σ;;; Γ ,,, Γ0 ,,, Δ ⊢ T ≤[le] U ->
    Σ;;; Γ ,,, subst_context s 0 Δ ⊢ subst s #|Δ| T ≤[le] subst s' #|Δ| U.
  Proof.
    move=> wfΣ subss subss' eqsub wfctx eqty.
    eapply cumul_trans => //.
    * eapply substitution_untyped_cumul => //.
    ** eauto.
    ** eapply eqty.
    * clear eqty.
      rewrite -(subst_context_length s 0 Δ).
      eapply cumul_subst_conv => //; eauto using subslet_untyped_subslet.
  Qed. *)

  Lemma conv_terms_open_terms_left {Γ s s'} : 
    conv_terms Σ Γ s s' ->
    forallb (is_open_term Γ) s.
  Proof.
    solve_all; eauto with fvs.
  Qed.

  Lemma conv_terms_open_terms_right {Γ s s'} : 
    conv_terms Σ Γ s s' ->
    forallb (is_open_term Γ) s'.
  Proof.
    solve_all; eauto with fvs.
  Qed.
  Hint Resolve conv_terms_open_terms_left conv_terms_open_terms_right : fvs.

  Lemma cumul_ctx_subst {Γ Γ' Γ'0 Γ'' Δ Δ' s s'} :
    context_equality_rel false Σ (Γ ,,, Γ' ,,, Γ'') Δ Δ' ->
    conv_terms Σ Γ s s' ->
    subslet Σ Γ s Γ' ->
    subslet Σ Γ s' Γ'0 ->
    is_closed_context (Γ ,,, Γ'0) ->
    context_equality_rel false Σ (Γ ,,, subst_context s 0 Γ'') (subst_context s #|Γ''| Δ) (subst_context s' #|Γ''| Δ').
  Proof.
    intros [cl cum] eqs hs hs' cl'.
    split.
    { eapply is_closed_subst_context; tea; eauto with fvs.
      apply (subslet_length hs). }
    eapply All2_fold_fold_context_k.
    eapply All2_fold_impl_ind; tea. clear cum.
    move=> Δ0 Δ'0 d d'; cbn => /All2_fold_length len _ ad.
    eapply All_decls_alpha_le_map.
    eapply All_decls_alpha_le_impl; tea.
    intros le x y; cbn => leq.
    rewrite -/(subst_context _ _ _).
    rewrite -app_context_assoc (subst_context_app0 s Γ'' Δ0).
    rewrite - !app_length.
    relativize #|Δ'0 ++ Γ''|; [apply (subst_equality (le:=le) hs hs' eqs)|] => //.
    1:rewrite app_context_assoc //.
    len. now rewrite len.
  Qed. 

  (* Lemma cumul_ctx_rel_nth_error {le Γ Δ Δ'} :
    context_equality_rel le Σ Γ Δ Δ' ->
    assumption_context Δ ->
    forall n decl, nth_error Δ n = Some decl ->
    ∑ decl', (nth_error Δ' n = Some decl') × (Σ ;;; Γ ,,, skipn (S n) Δ |- decl_type decl ≤ decl_type decl').
  Proof.
    induction 1.
    - move=> n decl /= //. now rewrite nth_error_nil.
    - move=> H [|n'] decl /= //.
      + rewrite /nth_error /= => [= <-].
        eexists; intuition eauto.
        rewrite skipn_S skipn_0. simpl.
        now depelim p.
      + rewrite /= => Hnth.
        forward IHX by now depelim H.
        destruct (IHX _ _ Hnth) as [decl' [Hnth' cum]].
        eexists; intuition eauto.
  Qed. *)

  Require Import ssrbool.

  Lemma weaken_cumul_ctx {le Γ Γ' Δ Δ'} :
    is_closed_context Γ ->
    context_equality_rel le Σ Γ' Δ Δ' ->
    context_equality_rel le Σ (Γ ,,, Γ') Δ Δ'.
  Proof.
    intros wf [cl eq].
    split.
    { rewrite on_free_vars_ctx_app wf /=. 
      eapply on_free_vars_ctx_impl; tea => //.
      congruence. }
    induction eq.
    - simpl. constructor.
    - constructor; auto.
      eapply All_decls_alpha_le_impl; tea.
      move=> /= le' x y c.
      rewrite -app_context_assoc.
      eapply weaken_equality; tea; eauto with fvs.
  Qed.

Local Open Scope sigma_scope.
From MetaCoq.PCUIC Require Import PCUICParallelReduction.

(* Lemma clos_rt_image {A B} (R : A -> A -> Type) (f g : B -> A) x y: 
  (forall x, R (f x) (g x)) ->
  (forall x, R (f x) (g x)) ->
  clos_refl_trans (fun x y => R (f x) (g y)) x y ->
  clos_refl_trans R (f x) (g y).
Proof.
  intros Hf. induction 1; try solve [econstructor; eauto].
  * econstructor 3. 2:tea.
    econstructor 3; tea.
    now rewrite -Hf.
Qed. *)

(*Lemma strong_substitutivity_clos_rt {P Q Γ Δ s t} σ τ :
  pred1_subst (Σ := Σ) P Q Γ Γ Δ Δ σ τ ->
  on_free_vars P s ->
  on_free_vars Q s.[σ] ->
  clos_refl_trans (pred1 Σ Γ Γ) s t ->
  clos_refl_trans (pred1 Σ Δ Δ) s.[σ] t.[τ].
Proof.
  intros ps ons ons' h.
  induction h in σ, τ, ps, ons, ons' |- *.
  * constructor 1.
    now eapply strong_substitutivity.
  * eapply strong_substitutivity in ps; tea.
    2:{ eapply pred1_ctx_refl. }
    constructor. apply ps.
  * econstructor 3.
    + eapply IHh1; tea.
    + eapply IHh2; tea.
      intros h.
      split. 
      - eapply pred1_refl.
      - destruct option_map as [[]|] => //.
Qed.*)
(*
Lemma red_strong_substitutivity {cf:checker_flags} {Σ} {wfΣ : wf Σ} Γ Δ s t σ τ :
  Σ ;;; Γ ⊢ s ⇝ t ->
  ctxmap Γ Δ σ ->
  ctxmap Γ Δ τ ->
  (forall x, Σ ;;; Γ ⊢ (σ x) (τ x)) ⇝ ->
  Σ ;;; Δ ⊢ s.[σ] ⇝ t.[τ].
Proof.
  intros r ctxm ctxm' IH.
  eapply red_pred in r; eauto.
  eapply (strong_substitutivity_clos_rt σ τ) in r; tea.
  - eapply pred_red => //.
  - intros x.
*)

Lemma map_branches_k_map_branches_k
      (f : nat -> term -> term) k
      (f' : nat -> term -> term) k'
      (l : list (branch term)) :
  map_branches_k f id k (map_branches_k f' id k' l) =
  map (map_branch_k (fun (i : nat) (x : term) => f (i + k) (f' (i + k') x)) id 0) l.
Proof.
  rewrite map_map.
  eapply map_ext => b.
  rewrite map_branch_k_map_branch_k; auto.
Qed.

Lemma red_rel_all {Γ i body t} :
  option_map decl_body (nth_error Γ i) = Some (Some body) ->
  red Σ Γ t (lift 1 i (t {i := body})).
Proof.
  induction t using PCUICInduction.term_forall_list_ind in Γ, i |- *; intro H; cbn;
    eauto using red_prod, red_abs, red_app, red_letin, red_proj_c.
  - case_eq (i <=? n); intro H0.
    + apply Nat.leb_le in H0.
      case_eq (n - i); intros; cbn.
      * apply red1_red.
        assert (n = i) by lia; subst.
        rewrite simpl_lift; cbn; try lia.
        now constructor.
      * enough (nth_error (@nil term) n0 = None) as ->;
          [cbn|now destruct n0].
        enough (i <=? n - 1 = true) as ->; try (apply Nat.leb_le; lia).
        enough (S (n - 1) = n) as ->; try lia. auto.
    + cbn. rewrite H0. auto.
  - eapply red_evar. repeat eapply All2_map_right.
    eapply All_All2; tea. intro; cbn; eauto.
  - destruct X as (IHparams&IHctx&IHret).
    rewrite map_predicate_k_map_predicate_k.
    assert (ctxapp: forall Γ',
               option_map decl_body (nth_error (Γ,,, Γ') (#|Γ'| + i)) = Some (Some body)).
    { unfold app_context.
      intros.
      rewrite nth_error_app2; [lia|].
      rewrite minus_plus; auto. }
    eapply red_case.
    + induction IHparams; pcuic.
    + apply IHret; auto.
      rewrite nth_error_app_ge ?inst_case_predicate_context_length; try lia.
      rewrite -H. lia_f_equal.
    + eapply IHt; auto.
    + clear -wfΣ X0 ctxapp.
      induction X0; pcuic.
      constructor; auto.
      destruct p0 as (IHctx&IHbody).
      unfold on_Trel.
      rewrite map_branch_k_map_branch_k => //.
      split.
      * eapply IHbody.
        rewrite Nat.add_0_r.
        eauto.
        rewrite nth_error_app_ge ?inst_case_branch_context_length; try lia.
        rewrite -(ctxapp []) /=. lia_f_equal.
      * cbn. auto.
  - eapply red_fix_congr. repeat eapply All2_map_right.
    eapply All_All2; tea. intros; cbn in *; rdest; eauto.
    rewrite map_length. eapply r0.
    rewrite nth_error_app_context_ge; rewrite fix_context_length; try lia.
    enough (#|m| + i - #|m| = i) as ->; tas; lia.
  - eapply red_cofix_congr. repeat eapply All2_map_right.
    eapply All_All2; tea. intros; cbn in *; rdest; eauto.
    rewrite map_length. eapply r0.
    rewrite nth_error_app_context_ge; rewrite fix_context_length; try lia.
    enough (#|m| + i - #|m| = i) as ->; tas; lia.
Qed.

Lemma closed_red_rel_all {Γ i body t} :
  is_closed_context Γ ->
  is_open_term Γ t ->
  option_map decl_body (nth_error Γ i) = Some (Some body) ->
  Σ ;;; Γ ⊢ t ⇝ lift 1 i (t {i := body}).
Proof.
  intros cl clt h; split; auto.
  now apply red_rel_all.
Qed.