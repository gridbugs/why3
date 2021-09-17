(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2021 --  Inria - CNRS - Paris-Saclay University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

type plugin = string

exception Plugin_Not_Found of plugin * string list

val debug : Debug.flag
(** debug flag for the plugin mechanism (option "--debug
    load_plugin")
    If set [load_plugin] prints on stderr exactly which plugin are loaded.
*)

val load : plugin -> unit
(* [load_plugin ~dir plugin] looks in the directories [dir] for the
   plugin named [plugin]. It add the extension .cmo or .cmxs to the
   filename according to the compilation used for the main program *)

val autoload_plugins: unit -> unit
