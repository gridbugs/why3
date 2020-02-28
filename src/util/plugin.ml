(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2020   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

type plugin = string

let debug = Debug.register_info_flag "load_plugin"
  ~desc:"Print@ debugging@ messages@ about@ plugin@ loading."

exception Plugin_Not_Found of plugin * string list

let load p =
  try Sites_info.Plugins.Plugins.load p
  with Not_found ->
    raise (Plugin_Not_Found(p,Sites_info.Plugins.Plugins.paths))

let () =
  Exn_printer.register (fun fmt exn ->
    match exn with
      | Plugin_Not_Found (pl,sl) ->
        Format.fprintf fmt "The plugin %s can't be found in the directories %a"
          pl (Pp.print_list Pp.space Pp.string) sl
      | Dynlink.Error (error) ->
        Format.fprintf fmt "Dynlink error: %s" (Dynlink.error_message error)
      | _ -> raise exn)



let autoload_plugins () =
  Sites_info.Plugins.Plugins.load_all ()
