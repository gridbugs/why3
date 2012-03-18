(**************************************************************************)
(*                                                                        *)
(*  Copyright (C) 2010-2011                                               *)
(*    François Bobot                                                      *)
(*    Jean-Christophe Filliâtre                                           *)
(*    Claude Marché                                                       *)
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
open Ident
open Whyconf
open Rc

let debug = Debug.register_flag "autodetect"

(* auto-detection of provers *)

type prover_kind = ATP | ITP
type prover_autodetection_data =
    { kind : prover_kind;
      prover_id : string;
      prover_name : string;
      execs : string list;
      version_switch : string;
      version_regexp : string;
      versions_ok : string list;
      versions_old : string list;
      versions_bad : string list;
      prover_command : string;
      prover_driver : string;
      prover_editor : string;
    }

let prover_keys =
  let add acc k = Sstr.add k acc in
  List.fold_left add Sstr.empty
    ["name";"exec";"version_switch";"version_regexp";
     "version_ok";"version_old";"version_bad";"command";
     "editor";"driver"]

let load_prover kind (id,section) =
  check_exhaustive section prover_keys;
  { kind = kind;
    prover_id = id;
    prover_name = get_string section "name";
    execs = get_stringl section "exec";
    version_switch = get_string section ~default:"" "version_switch";
    version_regexp = get_string section ~default:"" "version_regexp";
    versions_ok = get_stringl section ~default:[] "version_ok";
    versions_old = get_stringl section ~default:[] "version_old";
    versions_bad = get_stringl section ~default:[] "version_bad";
    prover_command = get_string section "command";
    prover_driver = get_string section "driver";
    prover_editor = get_string section ~default:"" "editor";
  }

(** returned in reverse order *)
let load rc =
  let atps = get_family rc "ATP" in
  let atps = List.rev_map (load_prover ATP) atps in
  let itps = get_family rc "ITP" in
  let tps = List.fold_left (cons (load_prover ITP)) atps itps in
  tps

let read_auto_detection_data main =
  let filename = Filename.concat (Whyconf.datadir main)
    "provers-detection-data.conf" in
  try
    let rc = Rc.from_file filename in
    load rc
  with
    | Failure "lexing" ->
        Loc.errorm "Syntax error in provers-detection-data.conf@."
    | Not_found ->
        Loc.errorm "provers-detection-data.conf not found at %s@." filename

let provers_found = ref 0

let prover_tips_info = ref false


let make_command exec com =
  let cmd_regexp = Str.regexp "%\\(.\\)" in
  let replace s = match Str.matched_group 1 s with
    | "e" -> exec
    | c -> "%"^c
  in
  Str.global_substitute cmd_regexp replace com

let sanitize_exec =
  let first c = match c with
    | '_' | ' ' -> "_"
    | _ -> char_to_alpha c
  in
  let rest c = match c with
    | '+' | '-' | '.' -> String.make 1 c
    | _ -> char_to_alnumus c
  in
  sanitizer first rest

let detect_exec main data com =
  let out = Filename.temp_file "out" "" in
  let cmd = sprintf "%s %s" com data.version_switch in
  let c = sprintf "(%s) > %s 2>&1" cmd out in
  Debug.dprintf debug "Run : %s@." c;
  let ret = Sys.command c in
  if ret <> 0 then
    begin
      Debug.dprintf debug "command '%s' failed@." cmd;
      None
    end
  else
    let s =
      try
        let ch = open_in out in
        let c = Sysutil.channel_contents ch in
        close_in ch;
        Sys.remove out;
        c
      with Not_found | End_of_file  -> ""
    in
    let re = Str.regexp data.version_regexp in
    try
      ignore (Str.search_forward re s 0);
      let nam = data.prover_name in
      let ver = Str.matched_group 1 s in
      if List.mem ver data.versions_bad then
        None
      else begin
        if List.mem ver data.versions_ok then
          eprintf "Found prover %s version %s, OK.@." nam ver
        else
          begin
            prover_tips_info := true;
            if List.mem ver data.versions_old then
              eprintf "Warning: prover %s version %s is quite old, please \
                     consider upgrading to a newer version.@."
                nam ver
            else
              eprintf "Warning: prover %s version %s is not known to be \
                     supported, use it at your own risk!@." nam ver
          end;
        let c = make_command com data.prover_command in
        let prover = {Whyconf.prover_name = data.prover_name;
                      prover_version = ver;
                      prover_altern = ""} in
        Some {prover = prover;
              id = data.prover_id;
              command = c;
              driver  = Filename.concat (datadir main) data.prover_driver;
              editor = data.prover_editor;
              interactive = (match data.kind with ITP -> true | ATP -> false);
              extra_options = [];
              extra_drivers = [] }
      end
    with Not_found ->
      begin
        prover_tips_info := true;
        eprintf "Warning: found prover %s but name/version not \
                       recognized by regexp `%s'@."
          data.prover_name data.version_regexp;
        eprintf "Answer was `%s'@." s;
        None
      end

let detect_prover main acc l =
  try
    let detect_execs data =
      try Some (Util.list_first (detect_exec main data) data.execs)
      with Not_found -> None
    in
    let prover = Util.list_first detect_execs l in
    Mprover.add prover.prover prover acc
  with Not_found ->
    eprintf "Prover %s not found.@." (List.hd l).prover_id;
    acc
(* does not work
  List.fold_left
    (fun acc data ->
      List.fold_left
        (fun acc e ->
          eprintf "Trying executable %s@." e;
          match detect_exec main data e with
            | None -> acc
            | Some prover -> Mstr.add prover_id prover acc)
        acc data.execs)
    acc l
*)

let run_auto_detection config =
  let main = get_main config in
  let l = read_auto_detection_data main in
  let cmp p q = String.compare p.prover_id q.prover_id in
  let l = Util.list_part cmp l in
  let detect = List.fold_left (detect_prover main) Mprover.empty l in
  let length = Mprover.cardinal detect in
  eprintf "%d provers detected.@." length;
  set_provers config detect

let list_prover_ids () =
  let config = default_config "/dev/null" in
  let main = get_main config in
  let l = read_auto_detection_data main in
  let s = List.fold_left (fun s p -> Sstr.add p.prover_id s) Sstr.empty l in
  Sstr.elements s

let get_altern id path =
  let alt = Filename.basename path in
  let ilen = String.length id in
  let alen = String.length alt in
  let rec get_suffix i =
    if i = alen then "alt" else
    if i = ilen then String.sub alt i (alen-i) else
    if id.[i] = alt.[i] then get_suffix (i+1) else
    String.sub alt i (alen-i)
  in
  get_suffix 0

let add_prover_binary config id path =
  let main = get_main config in
  let l = read_auto_detection_data main in
  let l = List.filter (fun p -> p.prover_id = id) l in
  if l = [] then Loc.errorm "Unknown prover id: %s" id;
  let p = try
    Util.list_first (fun d -> detect_exec main d path) (List.rev l)
  with Not_found ->
    Loc.errorm "File %s does not correspond to the prover id %s" path id
  in
  (* alternative name *)
  let alt = get_altern id path in
  let provers = get_provers config in
  (* is a prover with this name and version already in config? *)
  let p = if not (Mprover.mem p.prover provers) then p else
    { p with prover = { p.prover with prover_altern = alt } } in
  let alt = sanitizer char_to_alnumus char_to_alnumus alt in
  let p = { p with id = p.id ^ "-" ^ alt } in
  set_provers config (Mprover.add p.prover p (get_provers config))
