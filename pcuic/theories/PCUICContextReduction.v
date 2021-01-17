(* Distributed under the terms of the MIT license. *)
From Coq Require Import CRelationClasses.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICAstUtils
     PCUICLiftSubst PCUICEquality PCUICUnivSubst PCUICInduction 
     PCUICContextRelation PCUICReduction PCUICCases PCUICWeakening
     PCUICTyping.

Require Import ssreflect.
Require Import Equations.Prop.DepElim.
From Equations.Type Require Import Relation Relation_Properties.
From Equations Require Import Equations.
Set Equations Transparent.
Set Default Goal Selector "!".

Section CtxReduction.
  Context {cf : checker_flags}.
  Context {Σ : global_env}.
  Context (wfΣ : wf Σ).

  Lemma weakening_red_0 Γ Γ' M N n :
    n = #|Γ'| ->
    red Σ Γ M N ->
    red Σ (Γ ,,, Γ') (lift0 n M) (lift0 n N).
  Proof. now move=> ->; apply (weakening_red Σ Γ [] Γ'). Qed.

  Lemma red_abs_alt Γ na M M' N N' : red Σ Γ M M' -> red Σ (Γ ,, vass na M) N N' ->
                                 red Σ Γ (tLambda na M N) (tLambda na M' N').
  Proof.
    intros. eapply (transitivity (y := tLambda na M N')).
    * now eapply (red_ctx_congr (tCtxLambda_r _ _ tCtxHole)).
    * now eapply (red_ctx_congr (tCtxLambda_l _ tCtxHole _)).
  Qed.

  Lemma red_letin_alt Γ na d0 d1 t0 t1 b0 b1 :
    red Σ Γ d0 d1 -> red Σ Γ t0 t1 -> red Σ (Γ ,, vdef na d0 t0) b0 b1 ->
    red Σ Γ (tLetIn na d0 t0 b0) (tLetIn na d1 t1 b1).
  Proof.
    intros; eapply (transitivity (y := tLetIn na d0 t0 b1)).
    * now eapply (red_ctx_congr (tCtxLetIn_r _ _ _ tCtxHole)).
    * eapply (transitivity (y := tLetIn na d0 t1 b1)).
      + now eapply (red_ctx_congr (tCtxLetIn_b _ _ tCtxHole _)).
      + now apply (red_ctx_congr (tCtxLetIn_l _ tCtxHole _ _)).
  Qed.

  Lemma red_prod_alt Γ na M M' N N' :
    red Σ Γ M M' -> red Σ (Γ ,, vass na M') N N' ->
    red Σ Γ (tProd na M N) (tProd na M' N').
  Proof.
    intros. eapply (transitivity (y := tProd na M' N)).
    * now eapply (red_ctx_congr (tCtxProd_l _ tCtxHole _)).
    * now eapply (red_ctx_congr (tCtxProd_r _ _ tCtxHole)).
  Qed.

  Lemma red_decls_refl Γ Δ d : red_decls Σ Γ Δ d d.
  Proof.
    destruct d as [na [b|] ty]; constructor; auto.
  Qed.

  Lemma red_context_refl Γ : red_context Σ Γ Γ.
  Proof.
    apply context_relation_refl => ? ?.
    apply red_decls_refl.
  Qed.
  
  Lemma red_context_app_same {Γ Δ Γ'} : 
    red_context Σ Γ Δ ->
    red_context Σ (Γ ,,, Γ') (Δ ,,, Γ').
  Proof.
    intros r.
    eapply context_relation_app => //.
    apply context_relation_refl.
    intros; apply red_decls_refl.
  Qed.

  Lemma red1_red_ctx Γ Δ t u :
    red1 Σ Γ t u ->
    red_context Σ Δ Γ ->
    red Σ Δ t u.
  Proof.
    move=> r Hctx.
    revert Δ Hctx.
    induction r using red1_ind_all; intros Δ Hctx; try solve [eapply red_step; repeat (constructor; eauto)].
    - red in Hctx.
      destruct nth_error eqn:hnth => //; simpl in H; noconf H.
      eapply context_relation_nth_r in Hctx; eauto.
      destruct Hctx as [x' [? ?]].
      destruct p as [cr rd]. destruct c => //; simpl in *.
      depelim rd => //. noconf H.
      eapply red_step.
      * constructor. rewrite e => //.
      * rewrite -(firstn_skipn (S i) Δ).
        eapply weakening_red_0; auto.
        rewrite firstn_length_le //.
        eapply nth_error_Some_length in e. lia.
    - repeat econstructor; eassumption.
    - repeat econstructor; eassumption.
    - repeat econstructor; eassumption.
    - repeat econstructor; eassumption.
    - eapply red_abs_alt; eauto.
    - eapply red_abs_alt; eauto. apply (IHr (Δ ,, vass na N)).
      constructor; auto. constructor; auto.
    - eapply red_letin; eauto.
    - eapply red_letin; eauto.
    - eapply red_letin_alt; eauto.
      eapply (IHr (Δ ,, vdef na b t)). constructor; eauto.
      constructor; auto.
    - eapply red_case_pars; eauto; pcuic.
      eapply OnOne2_All2; tea => /=; intuition eauto.
    - eapply red_case_pcontext; eauto.
      eapply red_one_decl_red_ctx_rel.
      eapply OnOne2_local_env_impl; tea.
      intros Δ' x y.
      eapply on_one_decl_impl => Γ' t t' IH.
      apply IH. 
      now eapply red_context_app_same.
    - eapply red_case_p. eapply IHr.
      now apply red_context_app_same.
    - eapply red_case_c; eauto. 
    - eapply red_case_brs.
      unfold on_Trel; pcuic.
      unfold on_Trel.
      eapply OnOne2_All2; eauto.
      * simpl. intuition eauto.
        + apply b0. now apply red_context_app_same.
        + rewrite -b. reflexivity.
        + rewrite -b0. now reflexivity.
        + eapply red_one_decl_red_ctx_rel.
          eapply OnOne2_local_env_impl; tea.
          intros Δ' x' y'.
          eapply on_one_decl_impl => Γ' t t' IH.
          apply IH. 
          now eapply red_context_app_same.
      * intros x. split; pcuic.
    - eapply red_proj_c; eauto.
    - eapply red_app; eauto.
    - eapply red_app; eauto.
    - eapply red_prod_alt; eauto.
    - eapply red_prod_alt; eauto. apply (IHr (Δ ,, vass na M1)); constructor; auto.
      now constructor.
    - eapply red_evar.
      eapply OnOne2_All2; simpl; eauto. simpl. intuition eauto.
    - eapply red_fix_one_ty.
      eapply OnOne2_impl ; eauto.
      intros [? ? ? ?] [? ? ? ?] [[r ih] e]. simpl in *.
      inversion e. subst. clear e.
      split ; auto.
    - eapply red_fix_one_body.
      eapply OnOne2_impl ; eauto.
      intros [? ? ? ?] [? ? ? ?] [[r ih] e]. simpl in *.
      inversion e. subst. clear e.
      split ; auto.
      eapply ih.
      clear - Hctx. induction (fix_context mfix0).
      + assumption.
      + simpl. destruct a as [na [b|] ty].
        * constructor ; pcuicfo (constructor ; auto).
        * constructor ; pcuicfo (constructor ; auto).
    - eapply red_cofix_one_ty.
      eapply OnOne2_impl ; eauto.
      intros [? ? ? ?] [? ? ? ?] [[r ih] e]. simpl in *.
      inversion e. subst. clear e.
      split ; auto.
    - eapply red_cofix_one_body.
      eapply OnOne2_impl ; eauto.
      intros [? ? ? ?] [? ? ? ?] [[r ih] e]. simpl in *.
      inversion e. subst. clear e.
      split ; auto.
      eapply ih.
      clear - Hctx. induction (fix_context mfix0).
      + assumption.
      + simpl. destruct a as [na [b|] ty].
        * constructor ; pcuicfo (constructor ; auto).
        * constructor ; pcuicfo (constructor ; auto).
  Qed.

  Lemma red_red_ctx Γ Δ t u :
    red Σ Γ t u ->
    red_context Σ Δ Γ ->
    red Σ Δ t u.
  Proof.
    induction 1; eauto using red1_red_ctx.
    intros H.
    now transitivity y.
  Qed.

  Lemma red_context_app {Γ Γ' Δ Δ'} : 
    red_context Σ Γ Δ ->
    red_context_rel Σ Γ Γ' Δ' ->
    red_context Σ (Γ ,,, Γ') (Δ ,,, Δ').
  Proof.
    intros r r'.
    eapply context_relation_app => //.
    * now rewrite (context_relation_length r').
    * eapply context_relation_impl; tea => /= Γ0 Γ'0 d d'.
      intros h; depelim h; constructor; auto.
  Qed.

  Lemma red_context_app_same_left {Γ Γ' Δ'} : 
    red_context_rel Σ Γ Γ' Δ' ->
    red_context Σ (Γ ,,, Γ') (Γ ,,, Δ').
  Proof.
    intros h.
    eapply context_relation_app => //.
    * now rewrite (context_relation_length h).
    * apply red_context_refl.
  Qed.
  
  Lemma red_context_app_right {Γ Γ' Δ Δ'} : 
    red_context Σ Γ Δ ->
    red_context_rel Σ Δ Γ' Δ' ->
    red_context Σ (Γ ,,, Γ') (Δ ,,, Δ').
  Proof.
    intros r r'.
    eapply context_relation_app => //.
    * now rewrite (context_relation_length r').
    * eapply context_relation_impl; tea => /= Γ0 Γ'0 d d'.
      intros h; depelim h; constructor; auto; eapply red_red_ctx; tea;
        now eapply red_context_app_same.
  Qed.
  
  Lemma OnOne2_local_env_context_relation {P Q Γ Δ} :
    OnOne2_local_env P Γ Δ ->
    (forall Γ d d', P Γ d d' -> Q Γ Γ d d') ->
    (forall Γ Δ d, Q Γ Δ d d) ->
    context_relation Q Γ Δ.
  Proof.
    intros onc HPQ HQ. 
    induction onc; try constructor; auto.
    - apply context_relation_refl => //.
    - apply context_relation_refl => //.
    - destruct d as [na [b|] ty];constructor; auto.
  Qed.

  Lemma red_ctx_rel_red_context_rel Γ : 
    CRelationClasses.relation_equivalence (red_ctx_rel Σ Γ) (red_context_rel Σ Γ).
  Proof.
    split.
    - rewrite /red_ctx_rel /red_context_rel; induction 1.
      * eapply OnOne2_local_env_context_relation; tea => ? d d'.
        2:{ eapply red_decls_refl. }
        destruct d as [na [b|] ty], d' as [na' [b'|] ty']; cbn; intuition auto;
          subst; constructor; auto.
      * eapply context_relation_refl => Δ [na [b|] ty]; constructor; auto; constructor 2.
      * eapply context_relation_trans; eauto.
        intros.
        depelim X4; depelim X5; constructor; etransitivity; 
          eauto; eapply red_red_ctx; tea; eauto using red_context_app_same_left.
    - induction 1; try solve [constructor].
      + depelim p.
        transitivity (vass na U :: Γ0).
        * eapply red_one_decl_red_ctx_rel.
          do 2 constructor; auto.
        * clear -IHX.
          induction IHX; try now do 2 constructor.
          econstructor 3; tea.
      + depelim p.
        transitivity (vdef na u T :: Γ0).
      * eapply red_one_decl_red_ctx_rel.
        do 2 constructor; auto. 
      * transitivity (vdef na u U :: Γ0).
        ++ eapply red_one_decl_red_ctx_rel.
          do 2 constructor; auto. 
        ++ clear -IHX.
          induction IHX; try now do 2 constructor.
          econstructor 3; tea.
  Qed.
        
End CtxReduction.    



