(* Distributed under the terms of the MIT license. *)
From Coq Require Import ssreflect ssrbool.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst PCUICCases PCUICLiftSubst PCUICUnivSubst
     PCUICTyping PCUICCumulativity PCUICConfluence PCUICConversion
     PCUICWellScopedCumulativity.

Require Import Equations.Prop.DepElim.
(* todo: make wf arguments implicit *)
Section Inversion.

  Context `{checker_flags}.
  Context (Σ : global_env_ext).
  Context (wfΣ : wf Σ).

  Ltac insum :=
    match goal with
    | |- ∑ x : _, _ =>
      eexists
    end.

  Ltac intimes :=
    match goal with
    | |- _ × _ =>
      split
    end.

  Ltac outsum :=
    match goal with
    | ih : ∑ x : _, _ |- _ =>
      destruct ih as [? ?]
    end.

  Ltac outtimes :=
    match goal with
    | ih : _ × _ |- _ =>
      destruct ih as [? ?]
    end.

  Lemma into_ws_cumul {Γ t T U s} : 
    Σ ;;; Γ |- t : T ->
    Σ ;;; Γ |- U : tSort s ->
    Σ ;;; Γ |- T <= U ->
    Σ ;;; Γ ⊢ T ≤ U.
  Proof.
    intros. eapply into_equality; tea.
    - eapply typing_wf_local in X; eauto with fvs.
    - eapply PCUICClosed.type_closed in X.
      eapply PCUICOnFreeVars.closedn_on_free_vars in X; tea.
    - eapply PCUICClosed.subject_closed in X0.
      eapply PCUICOnFreeVars.closedn_on_free_vars in X0; tea.
  Qed.

  Lemma typing_closed_ctx Γ t T : 
    Σ ;;; Γ |- t : T ->
    is_closed_context Γ.
  Proof.
    move/typing_wf_local; eauto with fvs.
  Qed.
  Hint Immediate typing_closed_ctx : fvs.

  Lemma typing_equality Γ t T : 
    Σ ;;; Γ |- t : T ->
    Σ ;;; Γ ⊢ T ≤ T.
  Proof.
    intros ht. apply into_equality; auto. reflexivity.
    eauto with fvs.
    eapply PCUICClosed.type_closed in ht.
    now rewrite -is_open_term_closed.
    eapply PCUICClosed.type_closed in ht.
    now rewrite -is_open_term_closed.
  Qed.
  Hint Immediate typing_closed_ctx : fvs.

  Ltac invtac h :=
    dependent induction h ; [
      repeat insum ;
      repeat intimes ;
      [ first [ eassumption | try reflexivity ] .. | try solve [eapply typing_equality; econstructor; eauto] ]
    | repeat outsum ;
      repeat outtimes ;
      repeat insum ;
      repeat intimes ;
      [ first [ eassumption | reflexivity ] ..
      | try etransitivity ; try eassumption; try solve [eapply into_ws_cumul; tea] ]
    ].

  Derive Signature for typing.

  Import PCUICClosed PCUICOnFreeVars.

  Lemma nth_error_closed_context {Γ n d} :
    is_closed_context Γ ->
    nth_error Γ n = Some d ->
    is_open_term Γ (lift0 (S n) (decl_type d)).
  Proof.
    intros isc hnth.
    rewrite -on_free_vars_ctx_on_ctx_free_vars in isc.
    rewrite <- (addnP0) in isc.
    eapply nth_error_on_free_vars_ctx in isc; tea.
    2:{ rewrite /shiftnP orb_false_r. eapply Nat.ltb_lt. 
        eapply nth_error_Some_length in hnth. lia. }
    now move/andP: isc=> [] _ /on_free_vars_lift0 /=.
  Qed.

  Lemma inversion_Rel :
    forall {Γ n T},
      Σ ;;; Γ |- tRel n : T ->
      ∑ decl,
        wf_local Σ Γ ×
        (nth_error Γ n = Some decl) ×
        Σ ;;; Γ ⊢ lift0 (S n) (decl_type decl) ≤ T.
  Proof.
    intros Γ n T h. invtac h.
  Qed.

  Lemma inversion_Var :
    forall {Γ i T},
      Σ ;;; Γ |- tVar i : T -> False.
  Proof.
    intros Γ i T h. dependent induction h. assumption.
  Qed.

  Lemma inversion_Evar :
    forall {Γ n l T},
      Σ ;;; Γ |- tEvar n l : T -> False.
  Proof.
    intros Γ n l T h. dependent induction h. assumption.
  Qed.

  Lemma inversion_Sort :
    forall {Γ s T},
      Σ ;;; Γ |- tSort s : T ->
      wf_local Σ Γ ×
      wf_universe Σ s ×
      Σ ;;; Γ ⊢ tSort (Universe.super s) ≤ T.
  Proof.
    intros Γ s T h. invtac h.
  Qed.

  Lemma inversion_Prod :
    forall {Γ na A B T},
      Σ ;;; Γ |- tProd na A B : T ->
      ∑ s1 s2,
        Σ ;;; Γ |- A : tSort s1 ×
        Σ ;;; Γ ,, vass na A |- B : tSort s2 ×
        Σ ;;; Γ ⊢ tSort (Universe.sort_of_product s1 s2) ≤ T.
  Proof.
    intros Γ na A B T h. invtac h.
  Qed.

  Lemma inversion_Lambda :
    forall {Γ na A t T},
      Σ ;;; Γ |- tLambda na A t : T ->
      ∑ s B,
        Σ ;;; Γ |- A : tSort s ×
        Σ ;;; Γ ,, vass na A |- t : B ×
        Σ ;;; Γ ⊢ tProd na A B ≤ T.
  Proof.
    intros Γ na A t T h. invtac h.
  Qed.

  Lemma inversion_LetIn :
    forall {Γ na b B t T},
      Σ ;;; Γ |- tLetIn na b B t : T ->
      ∑ s1 A,
        Σ ;;; Γ |- B : tSort s1 ×
        Σ ;;; Γ |- b : B ×
        Σ ;;; Γ ,, vdef na b B |- t : A ×
        Σ ;;; Γ ⊢ tLetIn na b B A ≤ T.
  Proof.
    intros Γ na b B t T h. invtac h.
  Qed.

  Lemma inversion_App :
    forall {Γ u v T},
      Σ ;;; Γ |- tApp u v : T ->
      ∑ na A B,
        Σ ;;; Γ |- u : tProd na A B ×
        Σ ;;; Γ |- v : A ×
        Σ ;;; Γ ⊢ B{ 0 := v } ≤ T.
  Proof.
    intros Γ u v T h. invtac h.
  Qed.

  Lemma inversion_Const :
    forall {Γ c u T},
      Σ ;;; Γ |- tConst c u : T ->
      ∑ decl,
        wf_local Σ Γ ×
        declared_constant Σ c decl ×
        (consistent_instance_ext Σ decl.(cst_universes) u) ×
        Σ ;;; Γ ⊢ subst_instance u (cst_type decl) ≤ T.
  Proof.
    intros Γ c u T h. invtac h.
  Qed.

  Lemma inversion_Ind :
    forall {Γ ind u T},
      Σ ;;; Γ |- tInd ind u : T ->
      ∑ mdecl idecl,
        wf_local Σ Γ ×
        declared_inductive Σ ind mdecl idecl ×
        consistent_instance_ext Σ (ind_universes mdecl) u ×
        Σ ;;; Γ ⊢ subst_instance u idecl.(ind_type) ≤ T.
  Proof.
    intros Γ ind u T h. invtac h.
  Qed.

  Lemma inversion_Construct :
    forall {Γ ind i u T},
      Σ ;;; Γ |- tConstruct ind i u : T ->
      ∑ mdecl idecl cdecl,
        wf_local Σ Γ ×
        declared_constructor (fst Σ) (ind, i) mdecl idecl cdecl ×
        consistent_instance_ext Σ (ind_universes mdecl) u ×
        Σ;;; Γ ⊢ type_of_constructor mdecl cdecl (ind, i) u ≤ T.
  Proof.
    intros Γ ind i u T h. invtac h.
  Qed.
  Import PCUICEquality.
  Variant case_inversion_data Γ ci p c brs mdecl idecl indices :=
   | case_inv
       (ps : Universe.t)
       (eq_npars : mdecl.(ind_npars) = ci.(ci_npar))
       (predctx := case_predicate_context ci.(ci_ind) mdecl idecl p)
       (wf_pred : wf_predicate mdecl idecl p)
       (cons : consistent_instance_ext Σ (ind_universes mdecl) p.(puinst))
       (wf_pctx : wf_local Σ (Γ ,,, predctx))
       (conv_pctx : All2 (compare_decls eq eq) p.(pcontext) (ind_predicate_context ci.(ci_ind) mdecl idecl))
       (pret_ty : Σ ;;; Γ ,,, predctx |- p.(preturn) : tSort ps)
       (allowed_elim : is_allowed_elimination Σ ps idecl.(ind_kelim))
       (ind_inst : ctx_inst typing Σ Γ (p.(pparams) ++ indices)
                            (List.rev (subst_instance p.(puinst)
                                                      (ind_params mdecl ,,, ind_indices idecl))))
       (scrut_ty : Σ ;;; Γ |- c : mkApps (tInd ci.(ci_ind) p.(puinst)) (p.(pparams) ++ indices))
       (not_cofinite : isCoFinite mdecl.(ind_finite) = false)
       (ptm := it_mkLambda_or_LetIn predctx p.(preturn))
       (wf_brs : wf_branches idecl brs)
       (brs_ty :
          All2i (fun i cdecl br =>
                   All2 (compare_decls eq eq) br.(bcontext) (cstr_branch_context ci mdecl cdecl) ×
                   let brctxty := case_branch_type ci.(ci_ind) mdecl idecl p br ptm i cdecl in
                   (wf_local Σ (Γ ,,, brctxty.1) ×
                   ((Σ ;;; Γ ,,, brctxty.1 |- br.(bbody) : brctxty.2) ×
                    (Σ ;;; Γ ,,, brctxty.1 |- brctxty.2 : tSort ps))))
                0 idecl.(ind_ctors) brs).

  Lemma inversion_Case :
    forall {Γ ci p c brs T},
      Σ ;;; Γ |- tCase ci p c brs : T ->
      ∑ mdecl idecl (isdecl : declared_inductive Σ.1 ci.(ci_ind) mdecl idecl) indices, 
        let predctx := case_predicate_context ci.(ci_ind) mdecl idecl p in
        let ptm := it_mkLambda_or_LetIn predctx p.(preturn) in
        case_inversion_data Γ ci p c brs mdecl idecl indices ×
        Σ ;;; Γ ⊢ mkApps ptm (indices ++ [c]) ≤ T.
  Proof.
    intros Γ ci p c brs T h.
    dependent induction h.
    { repeat insum; repeat intimes; try eapply case_inv ; 
	    [ try first [ eassumption | reflexivity ].. | try eapply typing_equality; econstructor; eauto ]. }
    repeat outsum; repeat outtimes; repeat insum; repeat intimes ; tea;
      [ try first
      [ eassumption | reflexivity ]..
      | try etransitivity; try eassumption; eapply into_ws_cumul; tea ].
  Qed.

  Lemma inversion_Proj :
    forall {Γ p c T},
      Σ ;;; Γ |- tProj p c : T ->
      ∑ u mdecl idecl cdecl pdecl args,
        declared_projection Σ p mdecl idecl cdecl pdecl ×
        Σ ;;; Γ |- c : mkApps (tInd (fst (fst p)) u) args ×
        #|args| = ind_npars mdecl ×
        let ty := snd pdecl in
        Σ ;;; Γ ⊢ (subst0 (c :: List.rev args)) (subst_instance u ty) ≤ T.
  Proof.
    intros Γ p c T h. invtac h.
  Qed.

  Lemma inversion_Fix :
    forall {Γ mfix n T},
      Σ ;;; Γ |- tFix mfix n : T ->
      ∑ decl,
        let types := fix_context mfix in
        fix_guard Σ Γ mfix ×
        nth_error mfix n = Some decl ×
        All (fun d => isType Σ Γ (dtype d)) mfix ×
        All (fun d =>
          Σ ;;; Γ ,,, types |- dbody d : (lift0 #|types|) (dtype d)) mfix ×
        wf_fixpoint Σ mfix ×
        Σ ;;; Γ ⊢ dtype decl ≤ T.
  Proof.
    intros Γ mfix n T h. invtac h.
  Qed.

  Lemma inversion_CoFix :
    forall {Γ mfix idx T},
      Σ ;;; Γ |- tCoFix mfix idx : T ->
      ∑ decl,
        cofix_guard Σ Γ mfix ×
        let types := fix_context mfix in
        nth_error mfix idx = Some decl ×
        All (fun d => isType Σ Γ (dtype d)) mfix ×
        All (fun d =>
          Σ ;;; Γ ,,, types |- d.(dbody) : lift0 #|types| d.(dtype)
        ) mfix ×
        wf_cofixpoint Σ mfix ×
        Σ ;;; Γ ⊢ decl.(dtype) ≤ T.
  Proof.
    intros Γ mfix idx T h. invtac h.
  Qed.

  (** At this stage we don't typecheck primitive values *)
  Lemma inversion_Prim :
    forall {Γ i T},
      Σ ;;; Γ |- tPrim i : T -> False.
  Proof.
    intros Γ i T h. now depind h.
  Qed.

  Lemma inversion_it_mkLambda_or_LetIn :
    forall {Γ Δ t T},
      Σ ;;; Γ |- it_mkLambda_or_LetIn Δ t : T ->
      ∑ A,
        Σ ;;; Γ ,,, Δ |- t : A ×
        Σ ;;; Γ ⊢ it_mkProd_or_LetIn Δ A ≤ T.
  Proof.
    intros Γ Δ t T h.
    induction Δ as [| [na [b|] A] Δ ih ] in Γ, t, h |- *.
    - eexists. split ; eauto. cbn.
      eapply into_equality; [reflexivity|..].
      eauto with fvs.
      eapply type_closed in h.
      now eapply closedn_on_free_vars in h.
      eapply type_closed in h.
      now eapply closedn_on_free_vars in h.
    - simpl. apply ih in h. cbn in h.
      destruct h as [B [h c]].
      apply inversion_LetIn in h as hh.
      destruct hh as [s1 [A' [? [? [? ?]]]]].
      exists A'. split ; eauto.
      cbn. etransitivity; tea.
      eapply equality_it_mkProd_or_LetIn_codom.
      assumption.
    - simpl. apply ih in h. cbn in h.
      destruct h as [B [h c]].
      apply inversion_Lambda in h as hh.
      pose proof hh as [s1 [B' [? [? ?]]]].
      exists B'. split ; eauto.
      cbn. etransitivity; tea.
      eapply equality_it_mkProd_or_LetIn_codom.
      assumption.
  Qed.

End Inversion.
