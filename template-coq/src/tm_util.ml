open Pp

let contrib_name = "template-coq"

let gen_constant_in_modules s =
  lazy (
    let tm_ref = Coqlib.lib_ref s in
    UnivGen.constr_of_monomorphic_global tm_ref
  )
  (* lazy (Universes.constr_of_global (Coqlib.gen_reference_in_modules locstr dirs s)) *)


let opt_debug = ref false

let debug (m : unit ->Pp.t) =
  if !opt_debug then
    Feedback.(msg_debug (m ()))
  else
    ()


type ('a,'b) sum =
  Left of 'a | Right of 'b

(* todo(gmm): these are helper functions *)
let string_to_list (s : string) : char list =
  let rec aux acc i =
    if i < 0 then acc
    else aux (s.[i] :: acc) (i - 1)
  in aux [] (String.length s - 1)

let list_to_string (l : char list) : string =
  let buf = Bytes.create (List.length l) in
  let rec aux i = function
    | [] -> ()
    | c :: cs ->
      Bytes.set buf i c; aux (succ i) cs
  in
  aux 0 l;
  Bytes.to_string buf


let rec app_full trm acc =
  match Constr.kind trm with
    Constr.App (f, xs) -> app_full f (Array.to_list xs @ acc)
  | _ -> (trm, acc)

let not_supported trm =
  let env = Global.env () in
  CErrors.user_err (str "Not Supported:" ++ spc () ++ Printer.pr_constr_env env (Evd.from_env env) trm)

let not_supported_verb trm rs =
  let env = Global.env () in
  CErrors.user_err (str "Not Supported raised at " ++ str rs ++ str ":" ++ spc () ++
    Printer.pr_constr_env env (Evd.from_env env) trm)

let bad_term trm =
  let env = Global.env () in
  CErrors.user_err (str "Bad term:" ++ spc () ++ Printer.pr_constr_env env (Evd.from_env env) trm)

let bad_term_verb trm rs =
  let env = Global.env () in
  CErrors.user_err (str "Bad term:" ++ spc () ++ Printer.pr_constr_env env (Evd.from_env env) trm
                    ++ spc () ++ str " Error: " ++ str rs)


module CaseCompat =
  struct

  open Constr
  open Context.Rel.Declaration
  open Vars
  open Util
  open Univ
  open Declarations
  open Inductive

  (** {6 Changes of representation of Case nodes} *)

  (** Provided:
      - a universe instance [u]
      - a term substitution [subst]
      - name replacements [nas]
      [instantiate_context u subst nas ctx] applies both [u] and [subst] to [ctx]
      while replacing names using [nas] (order reversed)
  *)
  let instantiate_context u subst nas ctx =
    let rec instantiate i ctx = match ctx with
    | [] -> assert (Int.equal i (-1)); []
    | LocalAssum (_, ty) :: ctx ->
      let ctx = instantiate (pred i) ctx in
      let ty = substnl subst i (subst_instance_constr u ty) in
      LocalAssum (nas.(i), ty) :: ctx
    | LocalDef (_, ty, bdy) :: ctx ->
      let ctx = instantiate (pred i) ctx in
      let ty = substnl subst i (subst_instance_constr u ty) in
      let bdy = substnl subst i (subst_instance_constr u bdy) in
      LocalDef (nas.(i), ty, bdy) :: ctx
    in
    instantiate (Array.length nas - 1) ctx

  let case_predicate_context_gen mip ci u paramsubst nas =
    let realdecls, _ = List.chop mip.mind_nrealdecls mip.mind_arity_ctxt in
    let self =
      let args = Context.Rel.to_extended_vect mkRel 0 mip.mind_arity_ctxt in
      let inst = Instance.of_array (Array.init (Instance.length u) Level.var) in
      mkApp (mkIndU (ci.ci_ind, inst), args)
    in
    let realdecls = LocalAssum (Context.anonR, self) :: realdecls in
    instantiate_context u paramsubst nas realdecls

  let case_predicate_context env ci u params nas =
    let mib = Environ.lookup_mind (fst ci.ci_ind) env in
    let mip = mib.mind_packets.(snd ci.ci_ind) in
    let paramdecl = Vars.subst_instance_context u mib.mind_params_ctxt in
    let paramsubst = Vars.subst_of_rel_context_instance paramdecl (Array.to_list params) in
    case_predicate_context_gen mip ci u paramsubst nas
      
  let case_branches_contexts_gen mib ci u params brs =
    (* Γ ⊢ c : I@{u} params args *)
    (* Γ, indices, self : I@{u} params indices ⊢ p : Type *)
    let mip = mib.mind_packets.(snd ci.ci_ind) in
    let paramdecl = Vars.subst_instance_context u mib.mind_params_ctxt in
    let paramsubst = Vars.subst_of_rel_context_instance paramdecl (Array.to_list params) in
    (* Expand the branches *)
    let subst = paramsubst @ ind_subst (fst ci.ci_ind) mib u in
    let ebr =
      let build_one_branch i (nas, br) (ctx, _) =
        let ctx, _ = List.chop mip.mind_consnrealdecls.(i) ctx in
        let ctx = instantiate_context u subst nas ctx in
        (nas, ctx, br)
      in
      Array.map2_i build_one_branch brs mip.mind_nf_lc
    in 
    ebr

  let case_branches_contexts env ci u pars brs =
    let mib = Environ.lookup_mind (fst ci.ci_ind) env in
    case_branches_contexts_gen mib ci u pars brs

  let expand_case_specif mib (ci, u, params, p, iv, c, br) =
    (* Γ ⊢ c : I@{u} params args *)
    (* Γ, indices, self : I@{u} params indices ⊢ p : Type *)
    let mip = mib.mind_packets.(snd ci.ci_ind) in
    let paramdecl = Vars.subst_instance_context u mib.mind_params_ctxt in
    let paramsubst = Vars.subst_of_rel_context_instance paramdecl (Array.to_list params) in
    (* Expand the return clause *)
    let ep =
      let (nas, p) = p in
      let realdecls = case_predicate_context_gen mip ci u paramsubst nas in
      Term.it_mkLambda_or_LetIn p realdecls
    in
    (* Expand the branches *)
    let subst = paramsubst @ ind_subst (fst ci.ci_ind) mib u in
    let ebr =
      let build_one_branch i (nas, br) (ctx, _) =
        let ctx, _ = List.chop mip.mind_consnrealdecls.(i) ctx in
        let ctx = instantiate_context u subst nas ctx in
        Term.it_mkLambda_or_LetIn br ctx
      in
      Array.map2_i build_one_branch br mip.mind_nf_lc
    in
    (ci, ep, iv, c, ebr)

  let expand_case env (ci, _, _, _, _, _, _ as case) =
    let specif = Environ.lookup_mind (fst ci.ci_ind) env in
    expand_case_specif specif case

  let contract_case env (ci, p, iv, c, br) =
    let (mib, mip) = lookup_mind_specif env ci.ci_ind in
    let (arity, p) = Term.decompose_lam_n_decls (mip.mind_nrealdecls + 1) p in
    let (u, pms) = match arity with
    | LocalAssum (_, ty) :: _ ->
      (* Last binder is the self binder for the term being eliminated *)
      let (ind, args) = decompose_appvect ty in
      let (ind, u) = destInd ind in
      let () = assert (Names.eq_ind ind ci.ci_ind) in
      let pms = Array.sub args 0 mib.mind_nparams in
      (* Unlift the parameters from under the index binders *)
      let dummy = List.make mip.mind_nrealdecls mkProp in
      let pms = Array.map (fun c -> Vars.substl dummy c) pms in
      (u, pms)
    | _ -> assert false
    in
    let p = (arity, p)
    in
    let map i br =
      let (ctx, br) = Term.decompose_lam_n_decls mip.mind_consnrealdecls.(i) br in
      (ctx, br)
    in
    (ci, u, pms, p, iv, c, Array.mapi map br)
      
  let make_annots ctx = Array.of_list (List.rev_map get_annot ctx)
end

type ('term, 'name, 'nat) adef = { adname : 'name; adtype : 'term; adbody : 'term; rarg : 'nat }

type ('term, 'name, 'nat) amfixpoint = ('term, 'name, 'nat) adef list

type ('term, 'name, 'universe_instance) apredicate = 
  { auinst : 'universe_instance; 
    apars : 'term list;
    apcontext : 'name list;
    apreturn : 'term }

type ('term, 'name) abranch =
  { abcontext : 'name list;
    abbody : 'term }

type ('nat, 'inductive, 'relevance) acase_info =
  { aci_ind : 'inductive;
    aci_npar : 'nat;
    aci_relevance : 'relevance }
    
type ('term, 'nat, 'ident, 'name, 'quoted_sort, 'cast_kind, 'kername, 'inductive, 'relevance, 'universe_instance, 'projection, 'int63, 'float64) structure_of_term =
  | ACoq_tRel of 'nat
  | ACoq_tVar of 'ident
  | ACoq_tEvar of 'nat * 'term list
  | ACoq_tSort of 'quoted_sort
  | ACoq_tCast of 'term * 'cast_kind * 'term
  | ACoq_tProd of 'name * 'term * 'term
  | ACoq_tLambda of 'name * 'term * 'term
  | ACoq_tLetIn of 'name * 'term * 'term * 'term
  | ACoq_tApp of 'term * 'term list
  | ACoq_tConst of 'kername * 'universe_instance
  | ACoq_tInd of 'inductive * 'universe_instance
  | ACoq_tConstruct of 'inductive * 'nat * 'universe_instance
  | ACoq_tCase of ('nat, 'inductive, 'relevance) acase_info * 
    ('term, 'name, 'universe_instance) apredicate *
    'term * ('term, 'name) abranch list
  | ACoq_tProj of 'projection * 'term
  | ACoq_tFix of ('term, 'name, 'nat) amfixpoint * 'nat
  | ACoq_tCoFix of ('term, 'name, 'nat) amfixpoint * 'nat
  | ACoq_tInt of 'int63
  | ACoq_tFloat of 'float64

