(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-                                                   *)
(*    Francois Bobot                                                      *)
(*    Jean-Christophe Filliatre                                           *)
(*    Johannes Kanig                                                      *)
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

open Format
open Util

(* Error handling *)

type error =
  | SyntaxError
  | UnknownSection of string
  | UnknownField of string
  | MissingSection of string
  | MissingField of string
  | DuplicateSection of string
  | DuplicateField of string * Rc.rc_value * Rc.rc_value
  | StringExpected of string * Rc.rc_value
  | IdentExpected of string * Rc.rc_value
  | IntExpected of string * Rc.rc_value
  | DuplicateProver of string

exception Error of error

let error ?loc e = match loc with
  | None -> raise (Error e)
  | Some loc -> raise (Loc.Located (loc, Error e))

let print_rc_value fmt = function
  | Rc.RCint i -> fprintf fmt "%d" i
  | Rc.RCbool b -> fprintf fmt "%B" b
  | Rc.RCfloat f -> fprintf fmt "%f" f
  | Rc.RCstring s -> fprintf fmt "\"%s\"" s
  | Rc.RCident s -> fprintf fmt "%s" s

let report fmt = function
  | SyntaxError ->
      fprintf fmt "syntax error"
  | UnknownSection s ->
      fprintf fmt "unknown section '%s'" s
  | UnknownField s ->
      fprintf fmt "unknown field '%s'" s
  | MissingSection s ->
      fprintf fmt "section '%s' is missing" s
  | MissingField s ->
      fprintf fmt "field '%s' is missing" s
  | DuplicateSection s ->
      fprintf fmt "section '%s' is already given" s
  | DuplicateField (s,u,v) ->
      fprintf fmt "cannot set field '%s' to %a, as it is already set to %a"
        s print_rc_value v print_rc_value u
  | StringExpected (s,v) ->
      fprintf fmt "cannot set field '%s' to %a: a string is expected"
        s print_rc_value v
  | IdentExpected (s,v) ->
      fprintf fmt "cannot set field '%s' to %a: an identifier is expected"
        s print_rc_value v
  | IntExpected (s,v) ->
      fprintf fmt "cannot set field '%s' to %a: an integer is expected"
        s print_rc_value v
  | DuplicateProver s ->
      fprintf fmt "prover %s is already listed" s

(* Configuration file *)

type config_prover = {
  description : string;     (* "Alt-Ergo v2.95 (special)" *)
  command     : string;     (* "exec why-limit %t %m alt-ergo %f" *)
  driver_file : string;     (* "/usr/local/share/why/drivers/ergo-spec.drv" *)
}

type config = {
  conf_file : string;       (* "/home/innocent_user/.why.conf" *)
  loadpath  : string list;  (* "/usr/local/share/why/theories" *)
  timelimit : int option;   (* default prover time limit in seconds *)
  memlimit  : int option;   (* default prover memory limit in megabytes *)
  provers   : config_prover Mstr.t;   (* indexed by short identifiers *)
}

let to_string key = function
  | Rc.RCstring s -> s
  | v -> error (StringExpected (key,v))

let to_ident key = function
  | Rc.RCident s -> s
  | v -> error (IdentExpected (key,v))

let to_int key = function
  | Rc.RCint i -> i
  | v -> error (IntExpected (key,v))

let set_string key r v = match !r with
  | Some u -> error (DuplicateField (key,Rc.RCstring u,v))
  | None -> r := Some (to_string key v)

let set_ident key r v = match !r with
  | Some u -> error (DuplicateField (key,Rc.RCident u,v))
  | None -> r := Some (to_ident key v)

let set_int key r v = match !r with
  | Some u -> error (DuplicateField (key,Rc.RCint u,v))
  | None -> r := Some (to_int key v)

let get_field f = function
  | None -> error (MissingField f)
  | Some v -> v

let load_prover provers al =
  let nam = ref None in
  let dsc = ref None in
  let cmd = ref None in
  let drv = ref None in
  let load (key, value) = match key with
    | "name"        -> set_ident key nam value
    | "description" -> set_string key dsc value
    | "command"     -> set_string key cmd value
    | "driver"      -> set_string key drv value
    | _             -> error (UnknownField key)
  in
  List.iter load al;
  let prover = {
    description = get_field "description" !dsc;
    command     = get_field "command"     !cmd;
    driver_file = get_field "driver"      !drv }
  in
  let n = get_field "name" !nam in
  if Mstr.mem n provers then error (DuplicateProver n);
  Mstr.add n prover provers

let load_main main al =
  let lp = ref [] in
  let tl = ref None in
  let ml = ref None in
  let load (key, value) = match key with
    | "loadpath"  -> lp := (to_string key value) :: !lp
    | "timelimit" -> set_int key tl value
    | "memlimit"  -> set_int key ml value
    | _           -> error (UnknownField key)
  in
  List.iter load al;
  { main with
    loadpath  = List.rev !lp;
    timelimit = !tl;
    memlimit  = !ml;
    provers   = Mstr.empty }

let read_config ?conf_file () =
  let filename = match conf_file with
    | Some filename -> filename
    | None -> begin try Sys.getenv "WHY_CONFIG" with Not_found ->
          if Sys.file_exists "why.conf" then "why.conf" else
          if Sys.file_exists ".why.conf" then ".why.conf" else
          Filename.concat (Rc.get_home_dir ()) ".why.conf"
        end
  in
  let rc = try Rc.from_file filename with
    | Failure "lexing" -> error SyntaxError
  in
  let main = ref {
    conf_file = filename;
    loadpath  = [];
    timelimit = None;
    memlimit  = None;
    provers   = Mstr.empty }
  in
  let provers = ref Mstr.empty in
  let have_main = ref false in
  let load (key, al) = match key with
    | "main" when !have_main -> error (DuplicateSection key)
    | "main" -> main := load_main !main al
    | "prover" -> provers := load_prover !provers al
    | _ -> error (UnknownSection key)
  in
  List.iter load rc;
  { !main with provers = !provers }

let save_config config =
  let ch = open_out config.conf_file in
  let fmt = Format.formatter_of_out_channel ch in
  fprintf fmt "[main]@\n";
  List.iter (fprintf fmt "loadpath = \"%s\"@\n") config.loadpath;
  Util.option_iter (fprintf fmt "timelimit = %d@\n") config.timelimit;
  Util.option_iter (fprintf fmt "memlimit = %d@\n") config.memlimit;
  fprintf fmt "@.";
  let print_prover name prover =
    fprintf fmt "[prover]@\n";
    fprintf fmt "name = %s@\n" name;
    fprintf fmt "description = \"%s\"@\n" prover.description;
    fprintf fmt "command = \"%s\"@\n" prover.command;
    fprintf fmt "driver = \"%s\"@\n@." prover.driver_file;
  in
  Mstr.iter print_prover config.provers;
  close_out ch

