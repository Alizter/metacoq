(* Distributed under the terms of the MIT license. *)
From Coq Require Import Morphisms.
From MetaCoq.Template Require Import config utils.
From MetaCoq.PCUIC Require Import PCUICAst
     PCUICLiftSubst PCUICTyping
     PCUICClosed PCUICWeakeningEnv PCUICWeakening PCUICInversion
     PCUICSubstitution PCUICReduction PCUICCumulativity PCUICGeneration
     PCUICUnivSubst PCUICUnivSubstitution PCUICConfluence
     PCUICUnivSubstitution PCUICConversion PCUICContexts 
     PCUICArities PCUICSpine PCUICInductives
     PCUICContexts PCUICWfUniverses.
     
From Equations Require Import Equations.
Require Import Equations.Prop.DepElim.
Require Import ssreflect ssrbool.

Derive Signature for typing cumul.

Arguments Nat.sub : simpl never.

Section Validity.
  Context `{cf : config.checker_flags}.
                                                
  Lemma isType_weaken_full : weaken_env_prop_full (fun Σ Γ t T => isType Σ Γ T).
  Proof.
    red. intros.
    destruct X1 as [u Hu]; exists u; pcuic.
    unshelve eapply (weaken_env_prop_typing _ _ _ _ X0 _ _ (Some (tSort u))); eauto with pcuic.
    red. simpl. destruct Σ. eapply Hu.
  Qed.

  Hint Resolve isType_weaken_full : pcuic.

  Lemma isType_weaken :
    weaken_env_prop
      (lift_typing (fun Σ Γ (_ T : term) => isType Σ Γ T)).
  Proof.
    red. intros.
    unfold lift_typing in *. destruct T. now eapply (isType_weaken_full (_, _)).
    destruct X1 as [s Hs]; exists s. now eapply (isType_weaken_full (_, _)).
  Qed.
  Hint Resolve isType_weaken : pcuic.

  Lemma isType_extends (Σ : global_env) (Σ' : PCUICEnvironment.global_env) (φ : universes_decl) :
    wf Σ' ->
    extends Σ Σ' ->
    forall Γ : context,
    forall t0 : term,
    isType (Σ, φ) Γ t0 -> isType (Σ', φ) Γ t0.
  Proof.
    intros.
    destruct X1 as [s Hs].
    exists s.
    eapply (env_prop_typing _ _ PCUICWeakeningEnv.weakening_env (Σ, φ)); auto.
    simpl; auto. now eapply wf_extends.
  Qed.

  Lemma weaken_env_prop_isType :
    weaken_env_prop
    (lift_typing
        (fun (Σ0 : PCUICEnvironment.global_env_ext)
          (Γ0 : PCUICEnvironment.context) (_ T : term) =>
        isType Σ0 Γ0 T)).
  Proof.
    red. intros.
    red in X1 |- *.
    destruct T. now eapply isType_extends.
    destruct X1 as [s Hs]; exists s; now eapply isType_extends.
  Qed.

  Lemma isType_Sort_inv {Σ : global_env_ext} {Γ s} : wf Σ -> isType Σ Γ (tSort s) -> wf_universe Σ s.
  Proof.
    intros wfΣ [u Hu].
    now eapply inversion_Sort in Hu as [? [? ?]].
  Qed.

  Lemma isType_subst_instance_decl {Σ Γ T c decl u} :
    wf Σ.1 ->
    lookup_env Σ.1 c = Some decl ->
    isType (Σ.1, universes_decl_of_decl decl) Γ T ->
    consistent_instance_ext Σ (universes_decl_of_decl decl) u ->
    isType Σ (subst_instance u Γ) (subst_instance u T).
  Proof.
    destruct Σ as [Σ φ]. intros X X0 [s Hs] X1.
    exists (subst_instance_univ u s).
    eapply (typing_subst_instance_decl _ _ _ (tSort _)); eauto.
  Qed.
  
  Lemma isWfArity_subst_instance_decl {Σ Γ T c decl u} :
    wf Σ.1 ->
    lookup_env Σ.1 c = Some decl ->
    isWfArity (Σ.1, universes_decl_of_decl decl) Γ T ->
    consistent_instance_ext Σ (universes_decl_of_decl decl) u ->
    isWfArity Σ (subst_instance u Γ) (subst_instance u T).
  Proof.
    destruct Σ as [Σ φ]. intros X X0 [isTy [ctx [s eq]]] X1.
    split. eapply isType_subst_instance_decl; eauto.
    exists (subst_instance u ctx), (subst_instance_univ u s).
    rewrite (subst_instance_destArity []) eq. intuition auto.
  Qed.
  
  Lemma isType_weakening {Σ Γ T} : 
    wf Σ.1 ->
    wf_local Σ Γ ->
    isType Σ [] T ->
    isType Σ Γ T.
  Proof.
    intros wfΣ wfΓ [s HT].
    exists s; auto.
    eapply (weaken_ctx (Γ:=[])); eauto.
  Qed.

  Lemma nth_error_All_local_env {P : context -> term -> option term -> Type} {Γ n d} :
    nth_error Γ n = Some d ->
    All_local_env P Γ ->
    on_local_decl P (skipn (S n) Γ) d.
  Proof.
    intros heq hΓ.
    epose proof (nth_error_Some_length heq).
    eapply (nth_error_All_local_env) in H; tea.
    now rewrite heq in H.
  Qed.

  Notation type_ctx := (type_local_ctx (lift_typing typing)).
  Lemma type_ctx_wf_univ Σ Γ Δ s : type_ctx Σ Γ Δ s -> wf_universe Σ s.
  Proof.
    induction Δ as [|[na [b|] ty]]; simpl; auto with pcuic.
  Qed.
  Hint Resolve type_ctx_wf_univ : pcuic.

  Definition case_predicate_binder idecl ci p :=
    {| decl_name := {|
                  binder_name := nNamed (ind_name idecl);
                  binder_relevance := ind_relevance idecl |};
      decl_body := None;
      decl_type := mkApps (tInd ci (puinst p))
                    (map (lift0 #|ind_indices idecl|) (pparams p) ++
                      to_extended_list (ind_indices idecl)) |}.
  
  Lemma All2_fold_All2 (P : context_decl -> context_decl -> Type) Γ Δ : 
    All2_fold (fun _ _ => P) Γ Δ <~>
    All2 P Γ Δ.
  Proof.
    split; induction 1; constructor; auto.
  Qed.

  Lemma All2_map2_left {A B C D} {P : A -> A -> Type} Q (R : B -> D -> Type) {f : B -> C -> A} {l l' l'' l'''} : 
   All2 R l l''' ->
   All2 Q l' l'' ->
   #|l| = #|l'| ->
   (forall x y z w, R x w -> Q y z -> P (f x y) z) ->
   All2 P (map2 f l l') l''.
  Proof.
    intros hb ha hlen hPQ.
    induction ha in l, l''', hlen, hb |- *; simpl; try constructor; auto.
    - destruct l => //. simpl. constructor.
    - destruct l => //.
      noconf hlen. depelim hb.
      specialize (IHha _ _ hb H).
      simpl. constructor; auto. eapply hPQ; eauto.
  Qed.

  Lemma All2_map2_left_All3 {A B C} {P : A -> A -> Type} {f : B -> C -> A} {l l' l''} : 
    All3 (fun x y z => P (f x y) z) l l' l'' ->
    All2 P (map2 f l l') l''.
  Proof.
    induction 1; constructor; auto.
  Qed.

  Lemma All3_impl {A B C} {P Q : A -> B -> C -> Type} {l l' l''} : 
    All3 P l l' l'' ->
    (forall x y z, P x y z -> Q x y z) ->
    All3 Q l l' l''.
  Proof.
    induction 1; constructor; auto.
  Qed.

  Lemma case_predicate_context_eq ci mdecl idecl p :
    wf_predicate mdecl idecl p ->
    eq_context_upto_names (case_predicate_context ci mdecl idecl p)
      (case_predicate_binder idecl ci p :: 
        subst_context (pparams p) 0 (subst_instance p.(puinst) 
          (expand_lets_ctx (ind_params mdecl) (ind_indices idecl)))).
  Proof.
    intros [].
    rewrite /case_predicate_context /case_predicate_context_gen.
    eapply Forall2_All2 in H0.
    eapply All2_fold_All2.
    eapply All2_map2_left_All3.
    todo "cases".
  Admitted.

  Theorem validity :
    env_prop (fun Σ Γ t T => isType Σ Γ T)
      (fun Σ Γ => All_local_env 
        (fun Γ t T => match T with Some T => isType Σ Γ T | None => isType Σ Γ t end) Γ).
  Proof.
    apply typing_ind_env; intros; rename_all_hyps.

    - induction X; constructor; auto.
      (* * induction X; intros Γ' Δ eq.
        + destruct Δ.
          exists Universe.type1.
          unfold type_local_ctx. eapply wf_universe_type1.
          noconf eq.
        + destruct Δ.
          exists Universe.type1; eapply wf_universe_type1.
          noconf eq.
          red in tu.
          destruct (IHX _ _ eq_refl).
          exists (Universe.sup tu.π1 x).
          split. eapply type_local_ctx_cum; tea.
          eapply wf_universe_sup; eauto with pcuic.
          admit. *)


    - have hd := (nth_error_All_local_env heq_nth_error X).
      destruct decl as [na [b|] ty]; cbn -[skipn] in *.
      + eapply isType_lift; eauto.
        now apply nth_error_Some_length in heq_nth_error.
      + eapply isType_lift; eauto.
        now apply nth_error_Some_length in heq_nth_error.

    - (* Universe *) 
       exists (Universe.super (Universe.super u)).
       constructor; auto.
       now apply wf_universe_super.
        
    - (* Product *) 
      eexists.
      eapply isType_Sort_inv in X1; eapply isType_Sort_inv in X3; auto.
      econstructor; eauto.
      now apply wf_universe_product.

    - (* Lambda *)
      destruct X3 as [bs tybs].
      eapply isType_Sort_inv in X1; auto.
      exists (Universe.sort_of_product s1 bs).
      constructor; auto.

    - (* Let *)
      destruct X5 as [u Hu]. red in Hu.
      exists u.
      eapply type_Cumul.
      eapply type_LetIn; eauto. econstructor; pcuic.
      eapply cumul_alt. exists (tSort u), (tSort u); intuition auto.
      apply red1_red; repeat constructor.
      reflexivity.

    - (* Application *)
      destruct X3 as [u' Hu']. exists u'.
      move: (typing_wf_universe wf Hu') => wfu'.
      eapply (substitution0 _ _ na _ _ _ (tSort u')); eauto.
      apply inversion_Prod in Hu' as [na' [s1 [s2 Hs]]]; tas. intuition.
      eapply (weakening_cumul Σ Γ [] [vass na A]) in b; pcuic.
      simpl in b.
      eapply type_Cumul; eauto.
      econstructor; eauto.
      eapply cumul_trans. auto. 2:eauto.
      constructor. constructor. simpl. apply leq_universe_product.

    - destruct decl as [ty [b|] univs]; simpl in *.
      * eapply declared_constant_inv in X; eauto.
        red in X. simpl in X.
        eapply isType_weakening; eauto.
        eapply (isType_subst_instance_decl (Γ:=[])); eauto. simpl.
        eapply weaken_env_prop_isType.
      * have ond := on_declared_constant wf H.
        do 2 red in ond. simpl in ond.
        simpl in ond.
        eapply isType_weakening; eauto.
        eapply (isType_subst_instance_decl (Γ:=[])); eauto.
     
     - (* Inductive type *)
      destruct (on_declared_inductive isdecl); pcuic.
      destruct isdecl.
      apply onArity in o0.
      eapply isType_weakening; eauto.
      eapply (isType_subst_instance_decl (Γ:=[])); eauto.

    - (* Constructor type *)
      destruct (on_declared_constructor isdecl) as [[oni oib] [cs [declc onc]]].
      unfold type_of_constructor.
      have ctype := on_ctype onc.
      destruct ctype as [s' Hs].
      exists (subst_instance_univ u s').
      eapply instantiate_minductive in Hs; eauto.
      2:(destruct isdecl as [[] ?]; eauto).
      simpl in Hs.
      eapply (weaken_ctx (Γ:=[]) Γ); eauto.
      eapply (substitution _ [] _ (inds _ _ _) [] _ (tSort _)); eauto.
      eapply subslet_inds; eauto. destruct isdecl; eauto.
      now rewrite app_context_nil_l.

    - (* Case predicate application *)
      eapply (isType_mkApps_Ind wf isdecl) in X6 as [parsubst [argsubst Hind]]; auto.
      destruct (on_declared_inductive isdecl) as [onmind oib]. simpl in Hind.
      destruct Hind as [[sparsubst sargsubst] cu].
      rewrite /ptm. exists ps. red.
      eapply type_mkApps; eauto.
      eapply type_it_mkLambda_or_LetIn; tea.
      eapply wf_arity_spine_typing_spine; auto.
      split; auto.
      todo "case". (* predicate context is a valid "forall" context (not true for any context) *)
      rewrite -(wf_predicate_length_pars H0) in sparsubst sargsubst.
      erewrite (firstn_app_left _ 0), firstn_0, app_nil_r in sparsubst => //.
      erewrite (skipn_all_app_eq) in sargsubst => //.
      rewrite /predctx /=.
      rewrite /case_predicate_context /case_predicate_context_gen.
      todo "case".
      (* rewrite [it_mkProd_or_LetIn (_ :: _)](it_mkProd_or_LetIn_app [_]).
      eapply arity_spine_it_mkProd_or_LetIn; auto.
      rewrite 
      pose proof (context_subst_fun cs sparsubst). subst pars.
      eapply sargsubst.
      simpl. constructor; first last.
      constructor; auto.
      rewrite subst_mkApps.
      simpl.
      rewrite map_app. subst params.
      rewrite map_map_compose. rewrite map_subst_lift_id_eq.
      rewrite (subslet_length sargsubst). now autorewrite with len.
      unfold to_extended_list.
      eapply spine_subst_subst_to_extended_list_k in sargsubst.
      rewrite to_extended_list_k_subst
         PCUICSubstitution.map_subst_instance_to_extended_list_k in sargsubst.
      rewrite sargsubst firstn_skipn. eauto. *)

    - (* Proj *)
      pose proof isdecl as isdecl'.
      eapply declared_projection_type in isdecl'; eauto.
      subst ty.
      destruct isdecl' as [s Hs]. red in Hs.
      unshelve eapply isType_mkApps_Ind in X2 as [parsubst [argsubst [[sppar sparg] cu]]]; eauto.
      2:eapply isdecl.p1.
      eapply (typing_subst_instance_decl _ _ _ _ _ _ _ wf isdecl.p1.p1) in Hs; eauto.
      simpl in Hs.
      exists (subst_instance_univ u s).
      unfold PCUICTypingDef.typing in *.
      eapply (weaken_ctx Γ) in Hs; eauto.
      rewrite -heq_length in sppar. rewrite firstn_all in sppar.
      rewrite subst_instance_cons in Hs.
      rewrite subst_instance_smash in Hs. simpl in Hs.
      eapply spine_subst_smash in sppar => //.
      eapply (substitution _ Γ _ _ [_] _ _ wf sppar) in Hs.
      simpl in Hs.
      eapply (substitution _ Γ [_] [c] [] _ _ wf) in Hs.
      simpl in Hs. rewrite (subst_app_simpl [_]) /= //.
      constructor. constructor.
      simpl. rewrite subst_empty.
      rewrite subst_instance_mkApps subst_mkApps /=.
      rewrite [subst_instance_instance _ _](subst_instance_id_mdecl Σ u _ cu); auto.
      rewrite subst_instance_to_extended_list.
      rewrite subst_instance_smash.
      rewrite (spine_subst_subst_to_extended_list_k sppar).
      assumption.
      
    - (* Fix *)
      eapply nth_error_all in X0 as [s Hs]; eauto.
      pcuic.
    
    - (* CoFix *)
      eapply nth_error_all in X0 as [s Hs]; pcuic.

    - (* Conv *)
      now exists s.
  Qed.

End Validity.

Lemma validity_term {cf:checker_flags} {Σ Γ t T} :
  wf Σ.1 -> Σ ;;; Γ |- t : T -> isType Σ Γ T.
Proof.
  intros. eapply validity; try eassumption.
Defined.

(* This corollary relies strongly on validity.
   It should be used instead of the weaker [invert_type_mkApps],
   which is only used as a stepping stone to validity.
 *)
Lemma inversion_mkApps :
  forall `{checker_flags} {Σ Γ t l T},
    wf Σ.1 ->
    Σ ;;; Γ |- mkApps t l : T ->
    ∑ A, Σ ;;; Γ |- t : A × typing_spine Σ Γ A l T.
Proof.
  intros cf Σ Γ f u T wfΣ; induction u in f, T |- *. simpl. intros.
  { exists T. intuition pcuic. constructor. eapply validity; auto with pcuic.
    eauto. eapply cumul_refl'. }
  intros Hf. simpl in Hf.
  destruct u. simpl in Hf.
  - pose proof (env_prop_typing _ _  validity _ wfΣ _ _ _ Hf). simpl in X.
     eapply inversion_App in Hf as [na' [A' [B' [Hf' [Ha HA''']]]]].
    eexists _; intuition eauto.
    econstructor; eauto with pcuic. eapply validity; eauto with wf pcuic.
    constructor. all:eauto with pcuic.
  - specialize (IHu (tApp f a) T).
    specialize (IHu Hf) as [T' [H' H'']].
    eapply inversion_App in H' as [na' [A' [B' [Hf' [Ha HA''']]]]]. 2:{ eassumption. }
    exists (tProd na' A' B'). intuition; eauto.
    econstructor. eapply validity; eauto with wf.
    eapply cumul_refl'. auto.
    clear -H'' HA''' wfΣ. depind H''.
    econstructor; eauto. eapply cumul_trans; eauto.  
Qed.

(** "Economical" typing rule for applications, not requiring to check the product type *)
Lemma type_App' {cf:checker_flags} {Σ : global_env_ext} {wfΣ : wf Σ} {Γ t na A B u} : 
  Σ;;; Γ |- t : tProd na A B ->
  Σ;;; Γ |- u : A -> Σ;;; Γ |- tApp t u : B {0 := u}.
Proof.
  intros Ht Hu.
  have [s Hs] := validity_term wfΣ Ht.
  eapply type_App; eauto.
Qed.