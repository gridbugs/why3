(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2015   --   INRIA - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

open Stdlib
open Ident
open Ptree
open Ty
open Term
open Decl
open Theory
open Dterm
open Ity
(*
open Pdecl
open Pmodule
open Dexpr
*)

(** debug flags *)

let debug_parse_only = Debug.register_flag "parse_only"
  ~desc:"Stop@ after@ parsing."

let debug_type_only  = Debug.register_flag "type_only"
  ~desc:"Stop@ after@ type-checking."

(** errors *)

(*
exception UnboundTypeVar of string
exception DuplicateTypeVar of string
*)

(** lazy declaration of tuples *)

(*
let add_ty_decl uc ts      = add_decl_with_tuples uc (create_ty_decl ts)
let add_data_decl uc dl    = add_decl_with_tuples uc (create_data_decl dl)
let add_param_decl uc ls   = add_decl_with_tuples uc (create_param_decl ls)
let add_logic_decl uc dl   = add_decl_with_tuples uc (create_logic_decl dl)
let add_ind_decl uc s dl   = add_decl_with_tuples uc (create_ind_decl s dl)
let add_prop_decl uc k p f = add_decl_with_tuples uc (create_prop_decl k p f)
*)

(** symbol lookup *)

let rec qloc = function
  | Qdot (p, id) -> Loc.join (qloc p) id.id_loc
  | Qident id    -> id.id_loc

let qloc_last = function
  | Qdot (_, id) | Qident id -> id.id_loc

let rec print_qualid fmt = function
  | Qdot (p, id) -> Format.fprintf fmt "%a.%s" print_qualid p id.id_str
  | Qident id    -> Format.fprintf fmt "%s" id.id_str

let string_list_of_qualid q =
  let rec sloq acc = function
    | Qdot (p, id) -> sloq (id.id_str :: acc) p
    | Qident id -> id.id_str :: acc in
  sloq [] q

exception UnboundSymbol of qualid

let find_qualid get_id find ns q =
  let sl = string_list_of_qualid q in
  let r = try find ns sl with Not_found ->
    Loc.error ~loc:(qloc q) (UnboundSymbol q) in
  if Debug.test_flag Glob.flag then Glob.use (qloc_last q) (get_id r);
  r

let find_prop_ns     ns q = find_qualid (fun pr -> pr.pr_name) ns_find_pr ns q
let find_tysymbol_ns ns q = find_qualid (fun ts -> ts.ts_name) ns_find_ts ns q
let find_lsymbol_ns  ns q = find_qualid (fun ls -> ls.ls_name) ns_find_ls ns q

let find_fsymbol_ns ns q =
  let ls = find_lsymbol_ns ns q in
  if ls.ls_value <> None then ls else
    Loc.error ~loc:(qloc q) (FunctionSymbolExpected ls)

let find_psymbol_ns ns q =
  let ls = find_lsymbol_ns ns q in
  if ls.ls_value = None then ls else
    Loc.error ~loc:(qloc q) (PredicateSymbolExpected ls)

let find_prop     uc q = find_prop_ns     (Theory.get_namespace uc) q
let find_tysymbol uc q = find_tysymbol_ns (Theory.get_namespace uc) q
let find_lsymbol  uc q = find_lsymbol_ns  (Theory.get_namespace uc) q
let find_fsymbol  uc q = find_fsymbol_ns  (Theory.get_namespace uc) q
let find_psymbol  uc q = find_psymbol_ns  (Theory.get_namespace uc) q

let find_itysymbol_ns ns q =
  find_qualid (fun s -> s.its_ts.ts_name) Pmodule.ns_find_its ns q

let get_namespace uc = List.hd uc.Pmodule.muc_import

let find_itysymbol uc q = find_itysymbol_ns (get_namespace uc) q

(** Parsing types *)

let ty_of_pty uc pty =
  let rec get_ty = function
    | PTtyvar {id_str = x} ->
        ty_var (tv_of_string x)
    | PTtyapp (q, tyl) ->
        let ts = find_tysymbol uc q in
        let tyl = List.map get_ty tyl in
        Loc.try2 ~loc:(qloc q) ty_app ts tyl
    | PTtuple tyl ->
        let ts = ts_tuple (List.length tyl) in
        ty_app ts (List.map get_ty tyl)
    | PTarrow (ty1, ty2) ->
        ty_func (get_ty ty1) (get_ty ty2)
    | PTparen ty ->
        get_ty ty
  in
  get_ty pty

(** typing using destructive type variables

    parsed trees        intermediate trees       typed trees
      (Ptree)                (Dterm)               (Term)
   -----------------------------------------------------------
     ppure_type  ---dty--->   dty       ---ty--->    ty
      lexpr      --dterm-->   dterm     --term-->    term
*)

(** Typing patterns, terms, and formulas *)

let create_user_id {id_str = n; id_lab = label; id_loc = loc} =
  let get_labels (label, loc) = function
    | Lstr lab -> Slab.add lab label, loc | Lpos loc -> label, loc in
  let label,loc = List.fold_left get_labels (Slab.empty,loc) label in
  id_user ~label n loc

let parse_record ~loc uc get_val fl =
  let fl = List.map (fun (q,e) -> find_lsymbol uc q, e) fl in
  let cs,pjl,flm = Loc.try2 ~loc parse_record (get_known uc) fl in
  let get_val pj = get_val cs pj (Mls.find_opt pj flm) in
  cs, List.map get_val pjl

let rec dpattern uc { pat_desc = desc; pat_loc = loc } =
  Dterm.dpattern ~loc (match desc with
    | Ptree.Pwild -> DPwild
    | Ptree.Pvar x -> DPvar (create_user_id x)
    | Ptree.Papp (q,pl) ->
        let pl = List.map (dpattern uc) pl in
        DPapp (find_lsymbol uc q, pl)
    | Ptree.Ptuple pl ->
        let pl = List.map (dpattern uc) pl in
        DPapp (fs_tuple (List.length pl), pl)
    | Ptree.Prec fl ->
        let get_val _ _ = function
          | Some p -> dpattern uc p
          | None -> Dterm.dpattern DPwild in
        let cs,fl = parse_record ~loc uc get_val fl in
        DPapp (cs,fl)
    | Ptree.Pas (p, x) -> DPas (dpattern uc p, create_user_id x)
    | Ptree.Por (p, q) -> DPor (dpattern uc p, dpattern uc q)
    | Ptree.Pcast (p, ty) -> DPcast (dpattern uc p, ty_of_pty uc ty))

let quant_var uc (loc, id, gh, ty) =
  assert (not gh);
  let ty = match ty with
    | Some ty -> dty_of_ty (ty_of_pty uc ty)
    | None    -> dty_fresh () in
  Opt.map create_user_id id, ty, Some loc

let is_reusable dt = match dt.dt_node with
  | DTvar _ | DTgvar _ | DTconst _ | DTtrue | DTfalse -> true
  | DTapp (_,[]) -> true
  | _ -> false

let mk_var n dt =
  let dty = match dt.dt_dty with
    | None -> dty_of_ty ty_bool
    | Some dty -> dty in
  Dterm.dterm ?loc:dt.dt_loc (DTvar (n, dty))

let mk_let ~loc n dt node =
  DTlet (dt, id_user n loc, Dterm.dterm ~loc node)

let chainable_op uc op =
  (* non-bool -> non-bool -> bool *)
  op.id_str = "infix =" || op.id_str = "infix <>" ||
  match find_lsymbol uc (Qident op) with
  | {ls_args = [ty1;ty2]; ls_value = ty} ->
      Opt.fold (fun _ ty -> ty_equal ty ty_bool) true ty
      && not (ty_equal ty1 ty_bool)
      && not (ty_equal ty2 ty_bool)
  | _ -> false

let mk_closure loc ls =
  let mk dt = Dterm.dterm ~loc dt in
  let mk_v i _ =
    Some (id_user ("y" ^ string_of_int i) loc), dty_fresh (), None in
  let mk_t (id, dty, _) = mk (DTvar ((Opt.get id).pre_name, dty)) in
  let vl = Lists.mapi mk_v ls.ls_args in
  DTquant (DTlambda, vl, [], mk (DTapp (ls, List.map mk_t vl)))

let rec dterm uc gvars denv {term_desc = desc; term_loc = loc} =
  let func_app e el =
    List.fold_left (fun e1 (loc, e2) ->
      DTfapp (Dterm.dterm ~loc e1, e2)) e el
  in
  let rec apply_ls loc ls al l el = match l, el with
    | (_::l), (e::el) -> apply_ls loc ls (e::al) l el
    | [], _ -> func_app (DTapp (ls, List.rev_map snd al)) el
    | _, [] -> func_app (mk_closure loc ls) (List.rev_append al el)
  in
  let qualid_app q el = match gvars q with
    | Some vs -> func_app (DTgvar vs) el
    | None ->
        let ls = find_lsymbol uc q in
        apply_ls (qloc q) ls [] ls.ls_args el
  in
  let qualid_app q el = match q with
    | Qident {id_str = n} ->
        (match denv_get_opt denv n with
        | Some d -> func_app d el
        | None -> qualid_app q el)
    | _ -> qualid_app q el
  in
  let rec unfold_app e1 e2 el = match e1.term_desc with
    | Tapply (e11,e12) ->
        let e12 = dterm uc gvars denv e12 in
        unfold_app e11 e12 ((e1.term_loc, e2)::el)
    | Tident q ->
        qualid_app q ((e1.term_loc, e2)::el)
    | _ ->
        func_app (DTfapp (dterm uc gvars denv e1, e2)) el
  in
  Dterm.dterm ~loc (match desc with
  | Ptree.Tident q ->
      qualid_app q []
  | Ptree.Tidapp (q, tl) ->
      let tl = List.map (dterm uc gvars denv) tl in
      DTapp (find_lsymbol uc q, tl)
  | Ptree.Tapply (e1, e2) ->
      unfold_app e1 (dterm uc gvars denv e2) []
  | Ptree.Ttuple tl ->
      let tl = List.map (dterm uc gvars denv) tl in
      DTapp (fs_tuple (List.length tl), tl)
  | Ptree.Tinfix (e12, op2, e3)
  | Ptree.Tinnfix (e12, op2, e3) ->
      let make_app de1 op de2 = if op.id_str = "infix <>" then
        let op = { op with id_str = "infix =" } in
        let ls = find_lsymbol uc (Qident op) in
        DTnot (Dterm.dterm ~loc (DTapp (ls, [de1;de2])))
      else
        DTapp (find_lsymbol uc (Qident op), [de1;de2])
      in
      let rec make_chain de1 = function
        | [op,de2] ->
            make_app de1 op de2
        | (op,de2) :: ch ->
            let de12 = Dterm.dterm ~loc (make_app de1 op de2) in
            let de23 = Dterm.dterm ~loc (make_chain de2 ch) in
            DTbinop (DTand, de12, de23)
        | [] -> assert false in
      let rec get_chain e12 acc = match e12.term_desc with
        | Tinfix (e1, op1, e2) when chainable_op uc op1 ->
            get_chain e1 ((op1, dterm uc gvars denv e2) :: acc)
        | _ -> e12, acc in
      let ch = [op2, dterm uc gvars denv e3] in
      let e1, ch = if chainable_op uc op2
        then get_chain e12 ch else e12, ch in
      make_chain (dterm uc gvars denv e1) ch
  | Ptree.Tconst c ->
      DTconst c
  | Ptree.Tlet (x, e1, e2) ->
      let id = create_user_id x in
      let e1 = dterm uc gvars denv e1 in
      let denv = denv_add_let denv e1 id in
      let e2 = dterm uc gvars denv e2 in
      DTlet (e1, id, e2)
  | Ptree.Tmatch (e1, bl) ->
      let e1 = dterm uc gvars denv e1 in
      let branch (p, e) =
        let p = dpattern uc p in
        let denv = denv_add_pat denv p in
        p, dterm uc gvars denv e in
      DTcase (e1, List.map branch bl)
  | Ptree.Tif (e1, e2, e3) ->
      let e1 = dterm uc gvars denv e1 in
      let e2 = dterm uc gvars denv e2 in
      let e3 = dterm uc gvars denv e3 in
      DTif (e1, e2, e3)
  | Ptree.Ttrue ->
      DTtrue
  | Ptree.Tfalse ->
      DTfalse
  | Ptree.Tunop (Ptree.Tnot, e1) ->
      DTnot (dterm uc gvars denv e1)
  | Ptree.Tbinop (e1, op, e2) ->
      let e1 = dterm uc gvars denv e1 in
      let e2 = dterm uc gvars denv e2 in
      let op = match op with
        | Ptree.Tand -> DTand
        | Ptree.Tand_asym -> DTand_asym
        | Ptree.Tor -> DTor
        | Ptree.Tor_asym -> DTor_asym
        | Ptree.Timplies -> DTimplies
        | Ptree.Tiff -> DTiff in
      DTbinop (op, e1, e2)
  | Ptree.Tquant (q, uqu, trl, e1) ->
      let qvl = List.map (quant_var uc) uqu in
      let denv = denv_add_quant denv qvl in
      let dterm e = dterm uc gvars denv e in
      let trl = List.map (List.map dterm) trl in
      let e1 = dterm e1 in
      let q = match q with
        | Ptree.Tforall -> DTforall
        | Ptree.Texists -> DTexists
        | Ptree.Tlambda -> DTlambda in
      DTquant (q, qvl, trl, e1)
  | Ptree.Trecord fl ->
      let get_val cs pj = function
        | Some e -> dterm uc gvars denv e
        | None -> Loc.error ~loc (RecordFieldMissing (cs,pj)) in
      let cs, fl = parse_record ~loc uc get_val fl in
      DTapp (cs, fl)
  | Ptree.Tupdate (e1, fl) ->
      let e1 = dterm uc gvars denv e1 in
      let re = is_reusable e1 in
      let v = if re then e1 else mk_var "_q " e1 in
      let get_val _ pj = function
        | Some e -> dterm uc gvars denv e
        | None -> Dterm.dterm ~loc (DTapp (pj,[v])) in
      let cs, fl = parse_record ~loc uc get_val fl in
      let d = DTapp (cs, fl) in
      if re then d else mk_let ~loc "_q " e1 d
  | Ptree.Tnamed (Lpos uloc, e1) ->
      DTuloc (dterm uc gvars denv e1, uloc)
  | Ptree.Tnamed (Lstr lab, e1) ->
      DTlabel (dterm uc gvars denv e1, Slab.singleton lab)
  | Ptree.Tcast (e1, ty) ->
      DTcast (dterm uc gvars denv e1, ty_of_pty uc ty))

(* TODO
(** Export for program parsing *)

let type_term uc gvars t =
  let t = dterm uc gvars denv_empty t in
  Dterm.term ~strict:true ~keep_loc:true t
*)

let type_fmla uc gvars f =
  let f = dterm uc gvars denv_empty f in
  Dterm.fmla ~strict:true ~keep_loc:true f

(** Typing declarations *)

open Pdecl
open Pmodule

let add_pdecl ~wp uc d =
  if Debug.test_flag Glob.flag then Sid.iter Glob.def d.pd_news;
  add_pdecl ~wp uc d

let add_decl uc d = add_pdecl ~wp:false uc (create_pure_decl d)

let add_types uc tdl =
  let add m d =
    let x = d.td_ident.id_str in
    Mstr.add_new (Loc.Located (d.td_loc, ClashSymbol x)) x d m in
  let def = List.fold_left add Mstr.empty tdl in
  let hts = Hstr.create 5 in
  let htd = Hstr.create 5 in
  let rec visit ~alias ~alg x d = if not (Hstr.mem htd x) then
    let id = create_user_id d.td_ident and loc = d.td_loc in
    let args = List.map (fun id -> tv_of_string id.id_str) d.td_params in
    match d.td_def with
    | TDabstract ->
        if d.td_inv <> [] then Loc.errorm ~loc
          "Abstract non-record types cannot have invariants";
        let itd = create_abstract_type_decl id args d.td_mut in
        Hstr.add hts x itd.itd_its; Hstr.add htd x itd
    | TDalias pty ->
        if d.td_vis <> Public || d.td_mut then Loc.errorm ~loc
          "Alias types cannot be abstract, private. or mutable";
        if d.td_inv <> [] then Loc.errorm ~loc
          "Alias types cannot have invariants";
        let alias = Sstr.add x alias in
        let ity = parse ~loc ~alias ~alg pty in
        if not (Hstr.mem htd x) then
        let itd = create_alias_decl id args ity in
        Hstr.add hts x itd.itd_its; Hstr.add htd x itd
    | TDalgebraic csl ->
        if d.td_vis <> Public || d.td_mut then Loc.errorm ~loc
          "Algebraic types cannot be abstract, private. or mutable";
        if d.td_inv <> [] then Loc.errorm ~loc
          "Algebraic types cannot have invariants";
        let hfd = Hstr.create 5 in
        let alias = Sstr.empty in
        let alg = Mstr.add x (id,args) alg in
        let get_pj (_, id, ghost, pty) = match id with
          | Some ({id_str = n} as id) ->
              let ity = parse ~loc ~alias ~alg pty in
              let v = try Hstr.find hfd n with Not_found ->
                let v = create_pvsymbol (create_user_id id) ~ghost ity in
                Hstr.add hfd n v;
                v in
              if not (ity_equal v.pv_ity ity && ghost = v.pv_ghost) then
                Loc.errorm ~loc "Conflicting definitions for field %s" n;
              true, v
          | None ->
              let ity = parse ~loc ~alias ~alg pty in
              false, create_pvsymbol (id_fresh "a") ~ghost ity in
        let get_cs (_, id, pjl) = create_user_id id, List.map get_pj pjl in
        let csl = List.map get_cs csl in
        begin match try Some (Hstr.find hts x) with Not_found -> None with
        | Some s ->
            Hstr.add htd x (create_rec_variant_decl s csl)
        | None ->
            let itd = create_flat_variant_decl id args csl in
            Hstr.add hts x itd.itd_its; Hstr.add htd x itd end
    | TDrecord fl ->
        let alias = Sstr.empty in
        let alg = Mstr.add x (id,args) alg in
        let get_fd fd =
          let id = create_user_id fd.f_ident in
          let ity = parse ~loc ~alias ~alg fd.f_pty in
          let ghost = d.td_vis = Abstract || fd.f_ghost in
          fd.f_mutable, create_pvsymbol id ~ghost ity in
        let fl = List.map get_fd fl in
        begin match try Some (Hstr.find hts x) with Not_found -> None with
        | Some s ->
            if d.td_vis <> Public || d.td_mut then Loc.errorm ~loc
              "Recursive types cannot be abstract, private. or mutable";
            if d.td_inv <> [] then Loc.errorm ~loc
              "Recursive types cannot have invariants";
            let get_fd (mut, fd) = if mut then Loc.errorm ~loc
              "Recursive types cannot have mutable fields" else fd in
            Hstr.add htd x (create_rec_record_decl s (List.map get_fd fl))
        | None ->
            let priv = d.td_vis <> Public and mut = d.td_mut in
            let add_fd m (_, {pv_vs = v}) =
              Mstr.add v.vs_name.id_string v m in
            let gvars = List.fold_left add_fd Mstr.empty fl in
            let gvars q = match q with
              | Qident x -> Mstr.find_opt x.id_str gvars | _ -> None in
            let invl = List.map (type_fmla uc.muc_theory gvars) d.td_inv in
            let itd = create_flat_record_decl id args priv mut fl invl in
            Hstr.add hts x itd.itd_its; Hstr.add htd x itd end

  and parse ~loc ~alias ~alg pty =
    let rec down = function
      | PTtyvar id ->
          ity_var (tv_of_string id.id_str)
      | PTtyapp (q,tyl) ->
          let s = match q with
            | Qident {id_str = x} when Sstr.mem x alias ->
                Loc.errorm ~loc "Cyclic type definition"
            | Qident {id_str = x} when Mstr.mem x alg ->
                let id, args = Mstr.find x alg in
                let s = create_itysymbol_pure id args in
                Hstr.add hts x s; s
            | Qident {id_str = x} when Mstr.mem x def ->
                let d = Mstr.find x def in
                visit ~alias ~alg x d;
                Hstr.find hts x
            | _ ->
                find_itysymbol uc q in
          Loc.try2 ~loc:(qloc q) ity_app_fresh s (List.map down tyl)
      | PTtuple tyl -> ity_tuple (List.map down tyl)
      | PTarrow (ty1,ty2) -> ity_func (down ty1) (down ty2)
      | PTparen ty -> down ty in
    down pty in

  Mstr.iter (visit ~alias:Mstr.empty ~alg:Mstr.empty) def;
  let tdl = List.map (fun d -> Hstr.find htd d.td_ident.id_str) tdl in
  add_pdecl ~wp:true uc (create_type_decl tdl)

(* TODO
    | ClashSymbol s ->
        Loc.error ?loc:(look_for_loc tdl s) (ClashSymbol s)
    | RecordFieldMissing ({ ls_name = { id_string = s }} as cs,ls) ->
        Loc.error ?loc:(look_for_loc tdl s) (RecordFieldMissing (cs,ls))
    | DuplicateRecordField ({ ls_name = { id_string = s }} as cs,ls) ->
        Loc.error ?loc:(look_for_loc tdl s) (DuplicateRecordField (cs,ls))
    | DuplicateVar { vs_name = { id_string = s }} ->
        Loc.errorm ?loc:(look_for_loc tdl s)
          "Field %s is used twice in the same constructor" s
*)

let tyl_of_params uc pl =
  let ty_of_param (loc,_,gh,ty) =
    if gh then Loc.errorm ~loc
      "ghost parameters are not allowed in pure declarations";
    ty_of_pty uc ty in
  List.map ty_of_param pl

let add_logics uc dl =
  let th = uc.muc_theory in
  let lsymbols = Hstr.create 17 in
  (* 1. create all symbols and make an environment with these symbols *)
  let create_symbol uc d =
    let id = d.ld_ident.id_str in
    let v = create_user_id d.ld_ident in
    let pl = tyl_of_params th d.ld_params in
    let ty = Opt.map (ty_of_pty th) d.ld_type in
    let ls = create_lsymbol v pl ty in
    Hstr.add lsymbols id ls;
    Loc.try2 ~loc:d.ld_loc add_decl uc (create_param_decl ls)
  in
  let uc' = List.fold_left create_symbol uc dl in
  let th' = uc'.muc_theory in
  (* 2. then type-check all definitions *)
  let type_decl d (abst,defn) =
    let id = d.ld_ident.id_str in
    let ls = Hstr.find lsymbols id in
    let create_var (loc,x,_,_) ty =
      let id = match x with
        | Some id -> create_user_id id
        | None -> id_user "_" loc in
      create_vsymbol id ty in
    let vl = List.map2 create_var d.ld_params ls.ls_args in
    let add_var mvs (_,x,_,_) vs = match x with
      | Some {id_str = x} -> Mstr.add_new (DuplicateVar x) x (DTgvar vs) mvs
      | None -> mvs in
    let denv = List.fold_left2 add_var denv_empty d.ld_params vl in
    match d.ld_def, d.ld_type with
    | None, _ -> ls :: abst, defn
    | Some e, None -> (* predicate *)
        let f = dterm th' (fun _ -> None) denv e in
        let f = fmla ~strict:true ~keep_loc:true f in
        abst, (make_ls_defn ls vl f) :: defn
    | Some e, Some ty -> (* function *)
        let e = { e with term_desc = Tcast (e, ty) } in
        let t = dterm th' (fun _ -> None) denv e in
        let t = term ~strict:true ~keep_loc:true t in
        abst, (make_ls_defn ls vl t) :: defn
  in
  let abst,defn = List.fold_right type_decl dl ([],[]) in
  let add_param_decl uc s = add_decl uc (create_param_decl s) in
  let add_logic_decl uc l = add_decl uc (create_logic_decl l) in
  let uc = List.fold_left add_param_decl uc abst in
  if defn = [] then uc else add_logic_decl uc defn

let add_inductives uc s dl =
  (* 1. create all symbols and make an environment with these symbols *)
  let th = uc.muc_theory in
  let psymbols = Hstr.create 17 in
  let create_symbol uc d =
    let id = d.in_ident.id_str in
    let v = create_user_id d.in_ident in
    let pl = tyl_of_params th d.in_params in
    let ps = create_psymbol v pl in
    Hstr.add psymbols id ps;
    Loc.try2 ~loc:d.in_loc add_decl uc (create_param_decl ps)
  in
  let uc' = List.fold_left create_symbol uc dl in
  let th' = uc'.muc_theory in
  (* 2. then type-check all definitions *)
  let propsyms = Hstr.create 17 in
  let type_decl d =
    let id = d.in_ident.id_str in
    let ps = Hstr.find psymbols id in
    let clause (loc, id, f) =
      Hstr.replace propsyms id.id_str loc;
      let f = type_fmla th' (fun _ -> None) f in
      create_prsymbol (create_user_id id), f
    in
    ps, List.map clause d.in_def
  in
  let loc_of_id id = Opt.get id.Ident.id_loc in
  try add_decl uc (create_ind_decl s (List.map type_decl dl))
  with
  | ClashSymbol s ->
      Loc.error ~loc:(Hstr.find propsyms s) (ClashSymbol s)
  | InvalidIndDecl (ls,pr) ->
      Loc.error ~loc:(loc_of_id pr.pr_name) (InvalidIndDecl (ls,pr))
  | NonPositiveIndDecl (ls,pr,s) ->
      Loc.error ~loc:(loc_of_id pr.pr_name) (NonPositiveIndDecl (ls,pr,s))

let add_prop uc k s f =
  let th = uc.muc_theory in
  let pr = create_prsymbol (create_user_id s) in
  let f = type_fmla th (fun _ -> None) f in
  add_decl uc (create_prop_decl k pr f)

(* parse declarations *)

let add_decl uc inth = function
  | Ptree.Dtype dl ->
      add_types uc dl
  | Ptree.Dlogic dl ->
      add_logics uc dl
  | Ptree.Dind (s,dl) ->
      add_inductives uc s dl
  | Ptree.Dprop (k,s,f) ->
      add_prop uc k s f
  | Ptree.Dmeta (id,al) ->
      let th = uc.muc_theory in
      let convert = function
        | Ptree.Mty (PTtyapp (q,[]))
                       -> MAts (find_tysymbol th q)
        | Ptree.Mty ty -> MAty (ty_of_pty th ty)
        | Ptree.Mfs q  -> MAls (find_fsymbol th q)
        | Ptree.Mps q  -> MAls (find_psymbol th q)
        | Ptree.Mpr q  -> MApr (find_prop th q)
        | Ptree.Mstr s -> MAstr s
        | Ptree.Mint i -> MAint i in
      add_meta uc (lookup_meta id.id_str) (List.map convert al)
  | _ when inth ->
      Loc.errorm "Program declarations are not allowed in pure theories"
  | Ptree.Dval _
  | Ptree.Dlet _
  | Ptree.Dfun _
  | Ptree.Drec _
  | Ptree.Dexn _ -> assert false (* TODO *)

(* TODO
let rec clone_ns kn sl path ns2 ns1 s =
  let qualid fmt path = Pp.print_list
    (fun fmt () -> Format.pp_print_char fmt '.')
    Format.pp_print_string fmt (List.rev path) in
  let s = Mstr.fold (fun nm ns1 acc ->
    let ns2 = Mstr.find_def empty_ns nm ns2.ns_ns in
    clone_ns kn sl (nm::path) ns2 ns1 acc) ns1.ns_ns s
  in
  let inst_ts = Mstr.fold (fun nm ts1 acc ->
    match Mstr.find_opt nm ns2.ns_ts with
    | Some ts2 when ts_equal ts1 ts2 -> acc
    | Some _ when not (Sid.mem ts1.ts_name sl) ->
        raise (NonLocal ts1.ts_name)
    | Some _ when ts1.ts_def <> None ->
        raise (CannotInstantiate ts1.ts_name)
    | Some ts2 ->
        begin match (Mid.find ts1.ts_name kn).d_node with
          | Decl.Dtype _ -> Mts.add_new (ClashSymbol nm) ts1 ts2 acc
          | _ -> raise (CannotInstantiate ts1.ts_name)
        end
    | None when not (Sid.mem ts1.ts_name sl) -> acc
    | None when ts1.ts_def <> None -> acc
    | None ->
        begin match (Mid.find ts1.ts_name kn).d_node with
          | Decl.Dtype _ -> Loc.errorm
              "type symbol %a not found in the target theory"
              qualid (nm::path)
          | _ -> acc
        end)
    ns1.ns_ts s.inst_ts
  in
  let inst_ls = Mstr.fold (fun nm ls1 acc ->
    match Mstr.find_opt nm ns2.ns_ls with
    | Some ls2 when ls_equal ls1 ls2 -> acc
    | Some _ when not (Sid.mem ls1.ls_name sl) ->
       raise (NonLocal ls1.ls_name)
    | Some ls2 ->
        begin match (Mid.find ls1.ls_name kn).d_node with
          | Decl.Dparam _ -> Mls.add_new (ClashSymbol nm) ls1 ls2 acc
          | _ -> raise (CannotInstantiate ls1.ls_name)
        end
    | None when not (Sid.mem ls1.ls_name sl) -> acc
    | None ->
        begin match (Mid.find ls1.ls_name kn).d_node with
          | Decl.Dparam _ -> Loc.errorm
              "%s symbol %a not found in the target theory"
              (if ls1.ls_value <> None then "function" else "predicate")
              qualid (nm::path)
          | _ -> acc
        end)
    ns1.ns_ls s.inst_ls
  in
  { s with inst_ts = inst_ts; inst_ls = inst_ls }

let find_namespace_ns ns q =
  find_qualid (fun _ -> Glob.dummy_id) ns_find_ns ns q

let type_inst th t s =
  let add_inst s = function
    | CSns (loc,p,q) ->
      let ns1 = Opt.fold find_namespace_ns t.th_export p in
      let ns2 = Opt.fold find_namespace_ns (get_namespace th) q in
      Loc.try6 ~loc clone_ns t.th_known t.th_local [] ns2 ns1 s
    | CStsym (loc,p,[],PTtyapp (q,[])) ->
      let ts1 = find_tysymbol_ns t.th_export p in
      let ts2 = find_tysymbol th q in
      if Mts.mem ts1 s.inst_ts
      then Loc.error ~loc (ClashSymbol ts1.ts_name.id_string);
      { s with inst_ts = Mts.add ts1 ts2 s.inst_ts }
    | CStsym (loc,p,tvl,pty) ->
      let ts1 = find_tysymbol_ns t.th_export p in
      let id = id_user (ts1.ts_name.id_string ^ "_subst") loc in
      let tvl = List.map (fun id -> tv_of_string id.id_str) tvl in
      let def = Some (ty_of_pty th pty) in
      let ts2 = Loc.try3 ~loc create_tysymbol id tvl def in
      if Mts.mem ts1 s.inst_ts
      then Loc.error ~loc (ClashSymbol ts1.ts_name.id_string);
      { s with inst_ts = Mts.add ts1 ts2 s.inst_ts }
    | CSfsym (loc,p,q) ->
      let ls1 = find_fsymbol_ns t.th_export p in
      let ls2 = find_fsymbol th q in
      if Mls.mem ls1 s.inst_ls
      then Loc.error ~loc (ClashSymbol ls1.ls_name.id_string);
      { s with inst_ls = Mls.add ls1 ls2 s.inst_ls }
    | CSpsym (loc,p,q) ->
      let ls1 = find_psymbol_ns t.th_export p in
      let ls2 = find_psymbol th q in
      if Mls.mem ls1 s.inst_ls
      then Loc.error ~loc (ClashSymbol ls1.ls_name.id_string);
      { s with inst_ls = Mls.add ls1 ls2 s.inst_ls }
    | CSvsym (loc,_,_) ->
      Loc.errorm ~loc "program symbol instantiation \
        is not supported in pure theories"
    | CSlemma (loc,p) ->
      let pr = find_prop_ns t.th_export p in
      if Spr.mem pr s.inst_lemma || Spr.mem pr s.inst_goal
      then Loc.error ~loc (ClashSymbol pr.pr_name.id_string);
      { s with inst_lemma = Spr.add pr s.inst_lemma }
    | CSgoal (loc,p) ->
      let pr = find_prop_ns t.th_export p in
      if Spr.mem pr s.inst_lemma || Spr.mem pr s.inst_goal
      then Loc.error ~loc (ClashSymbol pr.pr_name.id_string);
      { s with inst_goal = Spr.add pr s.inst_goal }
  in
  List.fold_left add_inst empty_inst s
*)

let use_clone loc uc env file (use, subst) =
  let find_module env file q = match q with
    | Qident { id_str = id } -> (* local module *)
        begin try Mstr.find id file
        with Not_found -> read_module env [] id end
    | Qdot (p, { id_str = id }) -> (* module in file f *)
        read_module env (string_list_of_qualid p) id in
  let use_or_clone uc =
    let m = find_module env file use.use_module in
    if Debug.test_flag Glob.flag then
      Glob.use (qloc_last use.use_module) m.mod_theory.th_name;
    match subst with
    | None -> use_export uc m
    | Some _ ->
        warn_clone_not_abstract loc m.mod_theory;
        Loc.errorm ~loc "cloning coming soon" (* TODO *)
  in
  match use.use_import with
  | Some (import, use_as) ->
      (* use T = namespace T use_export T end *)
      let uc = open_namespace uc use_as in
      let uc = use_or_clone uc in
      close_namespace uc ~import
  | None ->
      use_or_clone uc

(* incremental parsing *)

type slice = {
  env           : Env.env;
  path          : Env.pathname;
  pure          : bool;
  mutable file  : pmodule Mstr.t;
  mutable muc   : pmodule_uc option;
  mutable inth  : bool;
}

let state = (Stack.create () : slice Stack.t)

let open_file env path ~pure =
  assert (Stack.is_empty state || (Stack.top state).muc <> None);
  Stack.push { env = env; path = path; pure = pure;
               file = Mstr.empty; muc = None; inth = false } state

let close_file () =
  assert (not (Stack.is_empty state) && (Stack.top state).muc = None);
  (Stack.pop state).file

let open_module ({id_str = nm; id_loc = loc} as id) ~theory =
  assert (not (Stack.is_empty state) && (Stack.top state).muc = None);
  let slice = Stack.top state in
  if Mstr.mem nm slice.file then Loc.errorm ~loc
    "module %s is already defined in this file" nm;
  if slice.pure && not theory then Loc.errorm ~loc
    "this file can only contain pure theories";
  let muc = create_module slice.env ~path:slice.path (create_user_id id) in
  slice.muc <- Some muc; slice.inth <- theory

let close_module loc =
  assert (not (Stack.is_empty state) && (Stack.top state).muc <> None);
  let slice = Stack.top state in
  if Debug.test_noflag debug_parse_only then begin
    let m = Loc.try1 ~loc close_module (Opt.get slice.muc) in
    if Debug.test_flag Glob.flag then Glob.def m.mod_theory.th_name;
    slice.file <- Mstr.add m.mod_theory.th_name.id_string m slice.file;
  end;
  slice.muc <- None

let open_namespace nm =
  assert (not (Stack.is_empty state) && (Stack.top state).muc <> None);
  if Debug.test_noflag debug_parse_only then
    let slice = Stack.top state in
    slice.muc <- Some (open_namespace (Opt.get slice.muc) nm.id_str)

let close_namespace loc ~import =
  assert (not (Stack.is_empty state) && (Stack.top state).muc <> None);
  if Debug.test_noflag debug_parse_only then
    let slice = Stack.top state in
    let muc = Loc.try1 ~loc (close_namespace ~import) (Opt.get slice.muc) in
    slice.muc <- Some muc

let add_decl loc d =
  assert (not (Stack.is_empty state) && (Stack.top state).muc <> None);
  if Debug.test_noflag debug_parse_only then
    let slice = Stack.top state in
    let muc = Loc.try3 ~loc add_decl (Opt.get slice.muc) slice.inth d in
    slice.muc <- Some muc

let use_clone loc use =
  assert (not (Stack.is_empty state) && (Stack.top state).muc <> None);
  if Debug.test_noflag debug_parse_only then
    let slice = Stack.top state in
    let muc = Loc.try5 ~loc use_clone loc
      (Opt.get slice.muc) slice.env slice.file use in
    slice.muc <- Some muc

(** Exception printing *)

let () = Exn_printer.register (fun fmt e -> match e with
  | UnboundSymbol q ->
      Format.fprintf fmt "unbound symbol '%a'" print_qualid q
(* TODO
  | UnboundTypeVar s ->
      Format.fprintf fmt "unbound type variable '%s" s
  | DuplicateTypeVar s ->
      Format.fprintf fmt "duplicate type parameter '%s" s
*)
  | _ -> raise e)
