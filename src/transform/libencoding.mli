(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-2011                                               *)
(*    François Bobot                                                     *)
(*    Jean-Christophe Filliâtre                                          *)
(*    Claude Marché                                                      *)
(*    Andrei Paskevich                                                    *)
(*                                                                        *)
(*  This software is free software; you can redistribute it and/or        *)
(*  modify it under the terms of the GNU Library General Public           *)
(*  License version 2.1, with the special exception on linking            *)
(*  described in file LICENSE.                                            *)
(*                                                                        *)
(*  This software is distributed in the hope that it will be useful,      *)
(*  but WITHOUT ANY WARRANTY; without even the implied warranty of        *)
(*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  *)
(*                                                                        *)
(**************************************************************************)

open Ty
open Term
open Decl

(* sort symbol of (polymorphic) types *)
val ts_type : tysymbol

(* sort of (polymorphic) types *)
val ty_type : ty

(* ts_type declaration *)
val d_ts_type : decl

(* function symbol mapping ty_type^n to ty_type *)
val ls_of_ts : tysymbol -> lsymbol

(* function symbol mapping ty_type^n to int *)
val ls_int_of_ty : lsymbol

(* function symbol selecting ty_type from ty_type^n *)
val ls_selects_of_ts : tysymbol -> lsymbol list

(* convert a type to a term of type ty_type *)
val term_of_ty : term Mtv.t -> ty -> term

(* rewrite a closed formula modulo the given free typevars *)
val type_close : Stv.t -> (term Mtv.t -> 'a -> term) -> 'a -> term

(* rewrite a closed formula modulo its free typevars *)
val t_type_close : (term Mtv.t -> term -> term) -> term -> term

(* convert a type declaration to a list of lsymbol declarations *)
val lsdecl_of_tydecl : ty_decl list -> decl list

(* convert a type declaration to a list of lsymbol declarations *)
val lsdecl_of_tydecl_select : ty_decl list -> decl list

(* monomorphise wrt the base type, the set of kept types, and a symbol map *)
val d_monomorph : ty -> Sty.t -> (lsymbol -> lsymbol) -> decl -> decl list

(* close by subtype the set of type tagged by the meta "kept" *)
val close_kept : Task.task Trans.trans

(* reconstruct a definition of an lsymbol or make a defining axiom *)
val defn_or_axiom : lsymbol -> term -> decl list

