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

open Format
open Model_parser

let debug = Debug.register_info_flag "call_prover"
  ~desc:"Print@ debugging@ messages@ about@ prover@ calls@ \
         and@ keep@ temporary@ files."

type reason_unknown =
  | Resourceout
  | Other

type prover_answer =
  | Valid
  | Invalid
  | Timeout
  | OutOfMemory
  | StepLimitExceeded
  | Unknown of (string * reason_unknown option)
  | Failure of string
  | HighFailure

type prover_result = {
  pr_answer : prover_answer;
  pr_status : Unix.process_status;
  pr_output : string;
  pr_time   : float;
  pr_steps  : int;		(* -1 if unknown *)
  pr_model  : model;
}

type resource_limit =
  {
    limit_time  : int;
    limit_mem   : int;
    limit_steps : int;
  }

let empty_limit = { limit_time = 0 ; limit_mem = 0; limit_steps = 0 }

let limit_max =
  let single_limit_max a b = if a = 0 || b = 0 then 0 else max a b in
  fun a b ->
    { limit_time = single_limit_max a.limit_time b.limit_time;
      limit_steps = single_limit_max a.limit_steps b.limit_steps;
      limit_mem = single_limit_max a.limit_mem b.limit_mem; }

type timeunit =
  | Hour
  | Min
  | Sec
  | Msec

type timeregexp = {
  re    : Str.regexp;
  group : timeunit array; (* i-th corresponds to the group i+1 *)
}

type stepregexp = {
  steps_re        : Str.regexp;
  steps_group_num : int;
  (* the number of matched group which corresponds to the number of steps *)
}

let timeregexp s =
  let cmd_regexp = Str.regexp "%\\(.\\)" in
  let nb = ref 0 in
  let l = ref [] in
  let add_unit x = l := (!nb,x) :: !l; incr nb; "\\([0-9]+.?[0-9]*\\)" in
  let replace s = match Str.matched_group 1 s with
    | "%" -> "%"
    | "h" -> add_unit Hour
    | "m" -> add_unit Min
    | "s" -> add_unit Sec
    | "i" -> add_unit Msec
    | x -> failwith ("unknown time format specifier: %%" ^
            x ^ " (should be either %%h, %%m, %%s or %%i")
  in
  let s = Str.global_substitute cmd_regexp replace s in
  let group = Array.make !nb Hour in
  List.iter (fun (i,u) -> group.(i) <- u) !l;
  { re = Str.regexp s; group = group}

let rec grep_time out = function
  | [] -> None
  | re :: l ->
    begin try
            ignore (Str.search_forward re.re out 0);
            let t = ref 0. in
            Array.iteri (fun i u ->
              let v = Str.matched_group (succ i) out in
              match u with
                | Hour -> t := !t +. float_of_string v *. 3600.
                | Min  -> t := !t +. float_of_string v *. 60.
                | Sec  -> t := !t +. float_of_string v
                | Msec -> t := !t +. float_of_string v /. 1000. ) re.group;
            Some( !t )
      with _ -> grep_time out l
    end

let stepregexp s_re s_group_num =
  {steps_re = (Str.regexp s_re); steps_group_num = s_group_num}

let rec grep_steps out = function
  | [] -> None
  | re :: l ->
    begin try
	    ignore (Str.search_forward re.steps_re out 0);
	    let v = Str.matched_group (re.steps_group_num) out in
	    Some(int_of_string v)
      with _ -> grep_steps out l
    end

let grep_reason_unknown out =
  try
    let re = Str.regexp "^(:reason-unknown \\([^)]*\\)" in
    ignore (Str.search_forward re out 0);
    match  (Str.matched_group 1 out) with
    | "resourceout" -> Resourceout
    | _ -> Other
  with Not_found ->
    Other

type prover_result_parser = {
  prp_regexps     : (Str.regexp * prover_answer) list;
  prp_timeregexps : timeregexp list;
  prp_stepregexps : stepregexp list;
  prp_exitcodes   : (int * prover_answer) list;
  prp_model_parser : Model_parser.model_parser;
}

let print_unknown_reason fmt r =
  match r with
  | Some Resourceout -> fprintf fmt " because of resource limit reached "
  | _ -> ()

let print_prover_answer fmt = function
  | Valid -> fprintf fmt "Valid"
  | Invalid -> fprintf fmt "Invalid"
  | Timeout -> fprintf fmt "Timeout"
  | OutOfMemory -> fprintf fmt "Ouf Of Memory"
  | StepLimitExceeded -> fprintf fmt "Step limit exceeded"
  | Unknown ("", r) -> fprintf fmt "Unknown%a" print_unknown_reason r
  | Failure "" -> fprintf fmt "Failure"
  | Unknown (s, r) -> fprintf fmt "Unknown %a(%s)" print_unknown_reason r s
  | Failure s -> fprintf fmt "Failure (%s)" s
  | HighFailure -> fprintf fmt "HighFailure"

let print_prover_status fmt = function
  | Unix.WSTOPPED n -> fprintf fmt "stopped by signal %d" n
  | Unix.WSIGNALED n -> fprintf fmt "killed by signal %d" n
  | Unix.WEXITED n -> fprintf fmt "exited with status %d" n

let print_steps fmt s =
  if s >= 0 then fprintf fmt ", %d steps)" s

let print_prover_result fmt
  {pr_answer=ans; pr_status=status; pr_output=out; pr_time=t; pr_steps=s; pr_model=m} =
  fprintf fmt "%a (%.2fs%a)" print_prover_answer ans t print_steps s;
  if not (Model_parser.is_model_empty m) then begin
    fprintf fmt "\nCounter-example model:";
    Model_parser.print_model fmt m
  end;
  if ans == HighFailure then
    fprintf fmt "@\nProver exit status: %a@\nProver output:@\n%s@."
      print_prover_status status out

let rec grep out l = match l with
  | [] ->
      HighFailure
  | (re,pa) :: l ->
      begin try
        ignore (Str.search_forward re out 0);
        match pa with
        | Valid | Invalid | Timeout | OutOfMemory | StepLimitExceeded -> pa
        | Unknown (s, ru) -> Unknown ((Str.replace_matched s out), ru)
        | Failure s -> Failure (Str.replace_matched s out)
        | HighFailure -> assert false
      with Not_found -> grep out l end

let backup_file f = f ^ ".save"

let debug_print_model model =
  let model_str = Model_parser.model_to_string model in
  Debug.dprintf debug "Call_provers: %s@." model_str

let parse_prover_run res_parser time out ret limit ~printer_mapping =
  let ans = match ret with
    | Unix.WSTOPPED n ->
        Debug.dprintf debug "Call_provers: stopped by signal %d@." n;
        grep out res_parser.prp_regexps
    | Unix.WSIGNALED n ->
        Debug.dprintf debug "Call_provers: killed by signal %d@." n;
        grep out res_parser.prp_regexps
    | Unix.WEXITED n ->
        Debug.dprintf debug "Call_provers: exited with status %d@." n;
        (try List.assoc n res_parser.prp_exitcodes
         with Not_found -> grep out res_parser.prp_regexps)
  in
  Debug.dprintf debug "Call_provers: prover output:@\n%s@." out;
  let time = Opt.get_def (time) (grep_time out res_parser.prp_timeregexps) in
  let steps = Opt.get_def (-1) (grep_steps out res_parser.prp_stepregexps) in
  let reason_unknown = grep_reason_unknown out in
  let ans = match ans with
    | Unknown (s, _) -> Unknown (s, Some reason_unknown)
    | _ -> ans in
  let ans = match ans, limit with
    | (Unknown _ | HighFailure), { limit_time = tlimit }
      when tlimit > 0 && time >= (0.9 *. float tlimit) -> Timeout
    | _ -> ans in
  let model = res_parser.prp_model_parser out printer_mapping in
  Debug.dprintf debug "Call_provers: model:@.";
  debug_print_model model;
  { pr_answer = ans;
    pr_status = ret;
    pr_output = out;
    pr_time   = time;
    pr_steps  = steps;
    pr_model  = model;
  }

let actualcommand command limit file =
  let stime = string_of_int limit.limit_time in
  let smem = string_of_int limit.limit_mem in
  let arglist = Cmdline.cmdline_split command in
  let use_stdin = ref true in
  let on_timelimit = ref false in
  let cmd_regexp = Str.regexp "%\\(.\\)" in
  let replace s = match Str.matched_group 1 s with
    | "%" -> "%"
    | "f" -> use_stdin := false; file
    | "t" -> on_timelimit := true; stime
    | "m" -> smem
    (* FIXME: libdir and datadir can be changed in the configuration file
       Should we pass them as additional arguments? Or would it be better
       to prepare the command line in a separate function? *)
    | "l" -> Config.libdir
    | "d" -> Config.datadir
    | "S" -> string_of_int limit.limit_steps
    | _ -> failwith "unknown specifier, use %%, %f, %t, %m, %l, %d or %S"
  in
  let args =
    List.map (Str.global_substitute cmd_regexp replace) arglist
  in
  args, !use_stdin, !on_timelimit

let actualcommand ~cleanup ~inplace command limit file =
  try actualcommand command limit file
  with e ->
    if cleanup then Sys.remove file;
    if inplace then Sys.rename (backup_file file) file;
    raise e

let adapt_limits limit on_timelimit =
  { limit with limit_time =
    (* for steps limit use 2 * t + 1 time *)
    if limit.limit_steps <> empty_limit.limit_steps
    then (2 * limit.limit_time + 1)
    (* if prover implements time limit, use t + 1 *)
    else if on_timelimit then succ limit.limit_time
    (* otherwise use t *)
    else limit.limit_time }

let set_socket_name =
  Prove_client.set_socket_name

type server_id = int
let gen_id =
  let x = ref 0 in
  fun () ->
    incr x;
    !x

type save_data =
  { vc_file      : string;
    inplace      : bool;
    limit        : resource_limit;
    res_parser   : prover_result_parser;
    printer_mapping : Printer.printer_mapping;
  }

let saved_data : (int, save_data) Hashtbl.t = Hashtbl.create 17

let read_and_delete_file fn =
  let cin = open_in fn in
  let out = Sysutil.channel_contents cin in
  close_in cin;
  if Debug.test_noflag debug then Sys.remove fn;
  out

let handle_answer answer =
  let id = answer.Prove_client.id in
  let save = Hashtbl.find saved_data id in
  Hashtbl.remove saved_data id;
  if Debug.test_noflag debug then begin
    Sys.remove save.vc_file;
    if save.inplace then Sys.rename (backup_file save.vc_file) save.vc_file
  end;
  let out = read_and_delete_file answer.Prove_client.out_file in
  let ret = Unix.WEXITED answer.Prove_client.exit_code in
  let printer_mapping = save.printer_mapping in
  let ans =
    parse_prover_run save.res_parser
                     answer.Prove_client.time
                     out ret save.limit
                     ~printer_mapping
  in
  id, ans

let wait_for_server_result ~blocking =
  List.map handle_answer (Prove_client.read_answers ~blocking)

type post_prover_call = unit -> prover_result

type prover_call =
  | ServerCall of server_id
  | EditorCall of (Unix.process_status -> post_prover_call) * int

type pre_prover_call = unit -> prover_call

let result_buffer : (server_id, prover_result) Hashtbl.t = Hashtbl.create 17

let call_on_file ~command ~limit ~res_parser ~printer_mapping
                 ?(inplace=false) fin () =
  let id = gen_id () in
  let cmd, use_stdin, on_timelimit =
    actualcommand ~cleanup:true ~inplace command limit fin in
  let limit = adapt_limits limit on_timelimit in
  let save =
    { vc_file      = fin;
      inplace      = inplace;
      limit        = limit;
      res_parser   = res_parser;
      printer_mapping = printer_mapping } in
  Hashtbl.add saved_data id save;
  let use_stdin = if use_stdin then Some fin else None in
  Prove_client.send_request ~use_stdin ~id
                            ~timelimit:limit.limit_time
                            ~memlimit:limit.limit_mem
                            ~cmd;
  ServerCall id

let get_new_results ~blocking =
  List.iter (fun (id, r) -> Hashtbl.add result_buffer id r)
    (wait_for_server_result ~blocking)

let query_call = function
  | ServerCall id ->
      begin try
        get_new_results ~blocking:false;
        Some (let r = Hashtbl.find result_buffer id in (fun () -> r))
      with Not_found -> None end
  | EditorCall (call, pid) ->
      let pid, ret = Unix.waitpid [Unix.WNOHANG] pid in
      if pid = 0 then None else Some (call ret)


let rec wait_on_call = function
  | ServerCall id as pc ->
      begin try
        let r = Hashtbl.find result_buffer id in (fun () -> r)
      with Not_found ->
        get_new_results ~blocking:true;
        wait_on_call pc
      end
  | EditorCall (call, pid) ->
      let _, ret = Unix.waitpid [] pid in call ret

let call_on_buffer ~command ~limit ~res_parser ~filename ~printer_mapping
                   ?(inplace=false) buffer =
  let fin,cin =
    if inplace then begin
      Sys.rename filename (backup_file filename);
      filename, open_out filename
    end else
      Filename.open_temp_file "why_" ("_" ^ filename) in
  Buffer.output_buffer cin buffer; close_out cin;
  call_on_file ~command ~limit ~res_parser ~printer_mapping ~inplace fin

let call_editor ~command fin =
  let command, use_stdin, _ =
    actualcommand ~cleanup:false ~inplace:false command empty_limit fin in
  let exec = List.hd command in
  Debug.dprintf debug "@[<hov 2>Call_provers: editor command is: %a@]@."
    (Pp.print_list Pp.space pp_print_string) command;
  let argarray = Array.of_list command in
  fun () ->
    let fd_in =
      if use_stdin then Unix.openfile fin [Unix.O_RDONLY] 0 else Unix.stdin in
    let pid = Unix.create_process exec argarray fd_in Unix.stdout Unix.stderr in
    if use_stdin then Unix.close fd_in;
    let call = fun ret ->
      let r =
        { pr_answer = Unknown ("", None);
          pr_status = ret;
          pr_output = "";
          pr_time   = 0.0;
          pr_steps  = 0;
          pr_model  = Model_parser.default_model;
        } in
      (fun () -> r)
    in
    EditorCall (call, pid)
