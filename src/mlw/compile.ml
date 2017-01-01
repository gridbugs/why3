(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2016   --   INRIA - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

(*
  - option to extract into a single file

  - no more why3extract.cma
    use driver preludes instead

  - 2 drivers for nums and zarith

  - no delcaration at all for a module -> no file produced
    (e.g. ref.Ref)

  - suggest a command line to compile the extracted code
    (for instance in a comment)

  - drivers for val now may use %1, %2, etc. (though not mandatory)
    Capp f x y
      "..." -> "..." x y
      "...%1..." -> "...x..." y
      "..(*%1*)..." -> "...(*x*)..." y
      "..%1..%3.." -> (fun z -> "..x..z..")  (y ignored)

  - extract file f.mlw into OCaml file f.ml, with sub-modules

  - "use (im|ex)port" -> "open"
    but OCaml's open is not transitive, so requires some extra work
    to figure out all the opens

  - if a WhyML module M is extracted to something that is a signature,
    then extract "module type B_sig = ..." (as well as "module B = ...")

  - use a black list in printer to avoid clash with Pervasives symbols
    (e.g. ref, (!), etc.)

*)

(*
  Questions pour Jean-Christophe et Andreï :
    - est-ce qu'il y a des utilisations particulières du champ
      [itd_fields], vis-à-vis du champ [itd_constructors] ?

    - comme l'AST [expr] est déjà en forme normale-A, est-ce que ça
      fait du sense pour vous d'utiliser des applications de la forme
      [Eapp of ident * ident list] ?
 *)

(*
  TODO: réfléchir sur l'affectation parallèle
*)


(** Abstract syntax of ML *)

open Ident
open Ity
open Ty
open Term

module ML = struct

  type ty =
    | Tvar    of ident
    | Tapp    of ident * ty list
    | Ttuple  of ty list

  type var = ident * ty

  type pat =
    | Pwild
    | Pident  of ident
    | Papp    of ident * pat list
    | Ptuple  of pat list
    | Precord of (ident * pat) list
    | Por     of pat * pat
    | Pas     of pat * ident

  type is_rec = bool

  type binop = Band | Bor | Beq

  type for_direction = To | DownTo

  type exn =
    | Xident  of ident
    | Xsyntax of string
    | Xexit             (* Pervasives.Exit *)

  type ity = I of Ity.ity | C of Ity.cty (* TODO: keep it like this? *)

  type expr = {
    e_node   : expr_node;
    e_ity    : ity;
    e_effect : effect;
  }

  and expr_node =
    | Econst  of Number.integer_constant
    | Ebool   of bool
    | Eident  of ident
    | Eapp    of ident * ident list
    | Efun    of var list * expr
    | Elet    of ident * expr * expr
    | Eletrec of is_rec * (ident * var list * expr) list * expr
    | Eif     of expr * expr * expr
    | Ecast   of expr * ty
    | Etuple  of expr list (* at least 2 expressions *)
    | Econstr of ident * expr list
    | Ematch  of expr * (pat * expr) list
    | Ebinop  of expr * binop * expr
    | Enot    of expr
    | Eblock  of expr list
    | Ewhile  of expr * expr
    | Efor    of ident * ident * for_direction * ident * expr
    | Eraise  of exn * expr option
    | Etry    of expr * (exn * ident option * expr) list
    | Eabsurd

  type is_mutable = bool

  type typedef =
    | Dabstract
    | Ddata     of (ident * ty list) list
    | Drecord   of (is_mutable * ident * ty) list
    | Dalias    of ty

  type decl = (* TODO add support for the extraction of ocaml modules *)
    | Dtype of (ident * ident list * typedef) list
    | Dlet  of is_rec * (ident * var list * expr) list
        (* TODO add return type? *)
    | Dexn  of ident * ty option

  let mk_expr e_node e_ity e_effect =
    { e_node = e_node; e_ity = e_ity; e_effect = e_effect }

  (* smart constructors *)
  let ml_let id e1 e2 =
    Elet (id, e1, e2)

  let tunit = Ttuple []

  let enope = Eblock []

  let mk_unit =
    mk_expr enope (I Ity.ity_unit) Ity.eff_empty

end

(** Translation from Mlw to ML *)

module Translate = struct

  open Expr    (* Mlw expressions *)

  open Pmodule (* for the type of modules *)
  open Pdecl   (* for the type of program declarations *)

  (* types *)
  let rec type_ ty =
    match ty.ty_node with
    | Tyvar tvs ->
       ML.Tvar tvs.tv_name
    | Tyapp (ts, tyl) when is_ts_tuple ts ->
       ML.Ttuple (List.map type_ tyl)
    | Tyapp (ts, tyl) ->
       ML.Tapp (ts.ts_name, List.map type_ tyl)

  let vsty vs =
    vs.vs_name, type_ vs.vs_ty

  let type_args = (* point-free *)
    List.map (fun x -> x.tv_name)

  let rec pat p =
    match p.pat_node with
    | Pwild ->
       ML.Pwild
    | Pvar vs ->
       ML.Pident vs.vs_name
    | Por (p1, p2) ->
       ML.Por (pat p1, pat p2)
    | Pas (p, vs) ->
       ML.Pas (pat p, vs.vs_name)
    | Papp (ls, pl) when is_fs_tuple ls ->
       ML.Ptuple (List.map pat pl)
    | Papp (ls, pl) ->
       ML.Papp (ls.ls_name, List.map pat pl)

  (** programs *)

  (* individual types *)
  let rec ity t =
    match t.ity_node with
    | Ityvar ({tv_name = tv}, _) ->
       ML.Tvar tv
    | Ityapp ({its_ts = ts}, itl, _) when is_ts_tuple ts ->
       ML.Ttuple (List.map ity itl)
    | Ityapp ({its_ts = ts}, itl, _) ->
       ML.Tapp (ts.ts_name, List.map ity itl)
    | _ -> (* TODO *) assert false

  let pv_name pv = pv.pv_vs.vs_name

  let pvty pv =
    if pv.pv_ghost then (pv_name pv, ML.tunit)
    else vsty pv.pv_vs

  let for_direction = function
    | To -> ML.To
    | DownTo -> ML.DownTo

  (* function arguments *)
  let args = (* point-free *)
    List.map pvty

  (* expressions *)
  let rec expr ({e_effect = eff } as e) =
    assert (not eff.eff_ghost);
    match e.e_node with
    | Econst c ->
       let c = match c with Number.ConstInt c -> c | _ -> assert false in
       ML.mk_expr (ML.Econst c) (ML.I e.e_ity) eff
    | Evar pvs ->
       let pv_id = pv_name pvs in
       ML.mk_expr (ML.Eident pv_id) (ML.I e.e_ity) eff
    | Elet (LDvar (pvs, e1), e2) ->
       let ml_let = ML.ml_let (pv_name pvs) (expr e1) (expr e2) in
       ML.mk_expr ml_let (ML.I e.e_ity) eff
    | Eexec ({c_node = Capp (rs, pvl)}, _) ->
       let rs_id = rs.rs_name in
       let pv_id = List.map pv_name pvl in
       ML.mk_expr (ML.Eapp (rs_id, pv_id)) (ML.I e.e_ity) eff
    | Eabsurd ->
       ML.mk_expr ML.Eabsurd (ML.I e.e_ity) eff
    | Ecase (e1, pl) ->
       let e1 = expr e1 in
       let pl = List.map ebranch pl in
       ML.mk_expr (ML.Ematch (e1, pl)) (ML.I e.e_ity) eff
    | Eassert _ ->
       ML.mk_unit
    | _ -> (* TODO *) assert false

  and ebranch ({pp_pat = p}, e) =
    pat p, expr e

  let its_args ts = ts.its_ts.ts_args
  let itd_name td = td.itd_its.its_ts.ts_name

  let drecord_fields {itd_its = its; itd_fields = fl} =
    List.map (fun ({rs_cty = rsc} as rs) ->
      (List.exists (pv_equal (Opt.get rs.rs_field)) its.its_mfields),
      rs.rs_name,
      if rs_ghost rs then ML.tunit else ity rsc.cty_result) fl

  let ddata_constructs = (* point-free *)
    List.map (fun ({rs_cty = rsc} as rs) ->
      rs.rs_name, List.map (fun {pv_vs = pv} -> type_ pv.vs_ty) rsc.cty_args)

  (* type declarations/definitions *)
  let tdef itd =
    let s = itd.itd_its in
    let id = itd_name itd in
    let args = its_args s in
    begin match s.its_def, itd.itd_constructors, itd.itd_fields with
      | None, [], [] ->
         ML.Dtype [id, type_args args, ML.Dabstract]
      | None, cl, [] ->
         ML.Dtype [id, type_args args, ML.Ddata (ddata_constructs cl)]
      | None, _, _ ->
         ML.Dtype [id, type_args args, ML.Drecord (drecord_fields itd)]
      | Some t, _, _ ->
         ML.Dtype [id, type_args args, ML.Dalias (ity t)]
    end

  (* program declarations *)
  let pdecl pd =
    match pd.pd_node with
    | PDlet (LDvar (_, _)) ->
       []
    | PDlet (LDsym ({rs_name = rsn; rs_cty = cty}, {c_node = Cfun e})) ->
       [ML.Dlet (false, [rsn, args cty.cty_args, expr e])]
    | PDlet (LDsym ({rs_name = rsn}, {c_node = Capp _})) ->
       Format.printf "LDsym Capp--> %s@." rsn.id_string;
       []
    | PDlet (LDsym ({rs_name = rsn}, {c_node = Cpur _})) ->
       Format.printf "LDsym Cpur--> %s@." rsn.id_string;
       []
    | PDlet (LDsym ({rs_name = rsn}, {c_node = Cany})) ->
       Format.printf "LDsym Cany--> %s@." rsn.id_string;
       []
    | PDlet (LDrec rl) ->
       let rec_def =
         List.map (fun {rec_fun = e; rec_rsym = rs} ->
           let e = match e.c_node with Cfun e -> e | _ -> assert false in
           rs.rs_name, args rs.rs_cty.cty_args, expr e) rl in
       [ML.Dlet (true, rec_def)]
    | PDpure ->
       []
    | PDtype itl ->
       List.map tdef itl
    | PDexn ({xs_name = xsn} as xs) ->
       if ity_equal xs.xs_ity ity_unit then
         [ML.Dexn (xsn, None)]
       else
         [ML.Dexn (xsn, Some (ity xs.xs_ity))]

  (* unit module declarations *)
  let mdecl = function
    | Udecl pd ->
       pdecl pd
    |  _ -> (* TODO *) []

  (* modules *)
  let module_ m =
    List.concat (List.map mdecl m.mod_units)

end

(*
 * Local Variables:
 * compile-command: "make -C ../.. -j3"
 * End:
 *)