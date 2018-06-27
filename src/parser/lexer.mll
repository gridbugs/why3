(********************************************************************)
(*                                                                  *)
(*  The Why3 Verification Platform   /   The Why3 Development Team  *)
(*  Copyright 2010-2018   --   Inria - CNRS - Paris-Sud University  *)
(*                                                                  *)
(*  This software is distributed under the terms of the GNU Lesser  *)
(*  General Public License version 2.1, with the special exception  *)
(*  on linking described in file LICENSE.                           *)
(*                                                                  *)
(********************************************************************)

{
  open Parser

  let keywords = Hashtbl.create 97
  let () =
    List.iter
      (fun (x,y) -> Hashtbl.add keywords x y)
      [
        "alias", ALIAS;
        "as", AS;
        "axiom", AXIOM;
        "by", BY;
        "clone", CLONE;
        "coinductive", COINDUCTIVE;
        "constant", CONSTANT;
        "else", ELSE;
        "end", END;
        "epsilon", EPSILON;
        "exists", EXISTS;
        "export", EXPORT;
        "false", FALSE;
        "float", FLOAT;
        "forall", FORALL;
        "function", FUNCTION;
        "goal", GOAL;
        "if", IF;
        "import", IMPORT;
        "in", IN;
        "inductive", INDUCTIVE;
        "lemma", LEMMA;
        "let", LET;
        "match", MATCH;
        "meta", META;
        "not", NOT;
        "predicate", PREDICATE;
        "range", RANGE;
        "scope", SCOPE;
        "so", SO;
        "then", THEN;
        "theory", THEORY;
        "true", TRUE;
        "type", TYPE;
        "use", USE;
        "with", WITH;
        (* programs *)
        "abstract", ABSTRACT;
        "absurd", ABSURD;
        "any", ANY;
        "assert", ASSERT;
        "assume", ASSUME;
        "at", AT;
        "begin", BEGIN;
        "break", BREAK;
        "check", CHECK;
        "continue", CONTINUE;
        "diverges", DIVERGES;
        "do", DO;
        "done", DONE;
        "downto", DOWNTO;
        "ensures", ENSURES;
        "exception", EXCEPTION;
        "for", FOR;
        "fun", FUN;
        "ghost", GHOST;
        "invariant", INVARIANT;
        "label", LABEL;
        "module", MODULE;
        "mutable", MUTABLE;
        "old", OLD;
        "private", PRIVATE;
        "pure", PURE;
        "raise", RAISE;
        "raises", RAISES;
        "reads", READS;
        "rec", REC;
        "requires", REQUIRES;
        "return", RETURN;
        "returns", RETURNS;
        "to", TO;
        "try", TRY;
        "val", VAL;
        "variant", VARIANT;
        "while", WHILE;
        "writes", WRITES;
      ]
}

let space = [' ' '\t' '\r']
let quote = '\''

let bin     = ['0' '1']
let oct     = ['0'-'7']
let dec     = ['0'-'9']
let hex     = ['0'-'9' 'a'-'f' 'A'-'F']

let bin_sep = ['0' '1' '_']
let oct_sep = ['0'-'7' '_']
let dec_sep = ['0'-'9' '_']
let hex_sep = ['0'-'9' 'a'-'f' 'A'-'F' '_']

let lalpha = ['a'-'z']
let ualpha = ['A'-'Z']
let alpha  = ['a'-'z' 'A'-'Z']

let suffix = (alpha | quote* dec_sep)* quote*
let lident = ['a'-'z' '_'] suffix
let uident = ['A'-'Z'] suffix

let core_suffix = quote alpha suffix
let core_lident = lident core_suffix+
let core_uident = uident core_suffix+

let op_char_1 = ['=' '<' '>' '~']
let op_char_2 = ['+' '-']
let op_char_3 = ['*' '/' '\\' '%']
let op_char_4 = ['!' '$' '&' '?' '@' '^' '.' ':' '|' '#']
let op_char_34 = op_char_3 | op_char_4
let op_char_234 = op_char_2 | op_char_34
let op_char_1234 = op_char_1 | op_char_234

let op_char_pref = ['!' '?']

rule token = parse
  | "[##" space* ("\"" ([^ '\010' '\013' '"' ]* as file) "\"")?
    space* (dec+ as line) space* (dec+ as char) space* "]"
      { Lexlib.update_loc lexbuf file (int_of_string line) (int_of_string char);
        token lexbuf }
  | "[#" space* "\"" ([^ '\010' '\013' '"' ]* as file) "\""
    space* (dec+ as line) space* (dec+ as bchar) space*
    (dec+ as echar) space* "]"
      { POSITION (Loc.user_position file (int_of_string line)
                 (int_of_string bchar) (int_of_string echar)) }
  | "[@" space* ([^ ' ' '\n' ']']+ (' '+ [^ ' ' '\n' ']']+)* as lbl) space* ']'
      { ATTRIBUTE lbl }
  | '\n'
      { Lexing.new_line lexbuf; token lexbuf }
  | space+
      { token lexbuf }
  | '_'
      { UNDERSCORE }
  | lident as id
      { try Hashtbl.find keywords id with Not_found -> LIDENT id }
  | core_lident as id
      { CORE_LIDENT id }
  | uident as id
      { UIDENT id }
  | core_uident as id
      { CORE_UIDENT id }
  | dec dec_sep* as s
      { INTEGER (Number.int_literal_dec (Lexlib.remove_underscores s)) }
  | '0' ['x' 'X'] (hex hex_sep* as s)
      { INTEGER (Number.int_literal_hex (Lexlib.remove_underscores s)) }
  | '0' ['o' 'O'] (oct oct_sep* as s)
      { INTEGER (Number.int_literal_oct (Lexlib.remove_underscores s)) }
  | '0' ['b' 'B'] (bin bin_sep* as s)
      { INTEGER (Number.int_literal_bin (Lexlib.remove_underscores s)) }
  | (dec+ as i) ".."
      { Lexlib.backjump lexbuf 2; INTEGER (Number.int_literal_dec i) }
  | '0' ['x' 'X'] (hex+ as i) ".."
      { Lexlib.backjump lexbuf 2; INTEGER (Number.int_literal_hex i) }
  | (dec+ as i)     ("" as f)    ['e' 'E'] (['-' '+']? dec+ as e)
  | (dec+ as i) '.' (dec* as f) (['e' 'E'] (['-' '+']? dec+ as e))?
  | (dec* as i) '.' (dec+ as f) (['e' 'E'] (['-' '+']? dec+ as e))?
      { REAL (Number.real_const_dec i f
          (Opt.map Lexlib.remove_leading_plus e)) }
  | '0' ['x' 'X'] (hex+ as i) ("" as f) ['p' 'P'] (['-' '+']? dec+ as e)
  | '0' ['x' 'X'] (hex+ as i) '.' (hex* as f)
        (['p' 'P'] (['-' '+']? dec+ as e))?
  | '0' ['x' 'X'] (hex* as i) '.' (hex+ as f)
        (['p' 'P'] (['-' '+']? dec+ as e))?
      { REAL (Number.real_const_hex i f
          (Opt.map Lexlib.remove_leading_plus e)) }
  | "(*)"
      { Lexlib.backjump lexbuf 2; LEFTPAR }
  | "(*"
      { Lexlib.comment lexbuf; token lexbuf }
  | "'" (lident as id)
      { QUOTE_LIDENT id }
  | ","
      { COMMA }
  | "("
      { LEFTPAR }
  | ")"
      { RIGHTPAR }
  | "{"
      { LEFTBRC }
  | "}"
      { RIGHTBRC }
  | ":"
      { COLON }
  | ";"
      { SEMICOLON }
  | "->"
      { ARROW }
  | "<-"
      { LARROW }
  | "<->"
      { LRARROW }
  | "&&"
      { AMPAMP }
  | "||"
      { BARBAR }
  | "/\\"
      { AND }
  | "\\/"
      { OR }
  | "."
      { DOT }
  | ".."
      { DOTDOT }
  | "|"
      { BAR }
  | "<"
      { LT }
  | ">"
      { GT }
  | "<>"
      { LTGT }
  | "="
      { EQUAL }
  | "-"
      { MINUS }
  | "["
      { LEFTSQ }
  | "]"
      { RIGHTSQ }
  | op_char_pref op_char_4* as s
      { OPPREF s }
  | op_char_1234* op_char_1 op_char_1234* as s
      { OP1 s }
  | op_char_234*  op_char_2 op_char_234*  as s
      { OP2 s }
  | op_char_34*   op_char_3 op_char_34*  as s
      { OP3 s }
  | op_char_4+ as s
      { OP4 s }
  | "\""
      { STRING (Lexlib.string lexbuf) }
  | eof
      { EOF }
  | _ as c
      { Lexlib.illegal_character c lexbuf }

{

  let debug = Debug.register_info_flag "print_modules"
    ~desc:"Print@ program@ modules@ after@ typechecking."

  exception Error of string

  let () = Exn_printer.register (fun fmt exn -> match exn with
  (* This ad hoc switch allows to not edit the automatically generated
     handcrafted.messages in ad hoc ways. *)
  | Error s when s = "<YOUR SYNTAX ERROR MESSAGE HERE>\n" ->
      Format.fprintf fmt "syntax error"
  | Error s -> Format.fprintf fmt "syntax error:\n %s" s
  | _ -> raise exn)

  (* Associate each token to a text representing it *)
  let match_tokens t =
    (* TODO generate this automatically *)
    match t with
    | None -> assert false
    | Some _t -> "NOT IMPLEMENTED"

  let build_parsing_function (parser_entry: Lexing.position -> 'a) lb =
    (* This records the last token which was read (for error messages) *)
    let last = ref None in
    let module I = Parser.MenhirInterpreter in
    let checkpoint = parser_entry lb.Lexing.lex_curr_p
    and supplier =
      I.lexer_lexbuf_to_supplier (fun x -> let t = token x in last := Some t; t) lb
    and succeed t = t
    and fail checkpoint =
      let t = Lexing.lexeme lb in
      let token = match_tokens !last in
      let fname = lb.Lexing.lex_curr_p.Lexing.pos_fname in
      (* TODO/FIXME: ad-hoc fix for TryWhy3/Str incompatibility *)
      let s = if Filename.remove_extension fname = "/trywhy3_input"
        then "<YOUR SYNTAX ERROR MESSAGE HERE>\n"
        else Report.report (t, token) checkpoint in
      (* Typing.close_file is supposedly done at the end of the file in
         parsing.mly. If there is a syntax error, we still need to close it (to
         be able to reload). *)
      Loc.with_location (fun _x ->
        (try ignore(Typing.close_file ()) with
        | _e -> ());
        raise (Error s)) lb
    in
    I.loop_handle succeed fail supplier checkpoint

  open Wstdlib
  open Ident
  open Theory
  open Pmodule

  let parse_term lb =
    build_parsing_function Parser.Incremental.term_eof lb

  let parse_term_list lb = build_parsing_function Parser.Incremental.term_comma_list_eof lb

  let parse_qualid lb = build_parsing_function Parser.Incremental.qualid_eof lb

  let parse_list_ident lb = build_parsing_function Parser.Incremental.ident_comma_list_eof lb

  let parse_list_qualid lb = build_parsing_function Parser.Incremental.qualid_comma_list_eof lb

  let read_channel env path file c =
    let lb = Lexing.from_channel c in
    Loc.set_file file lb;
    Typing.open_file env path;
    let mm = build_parsing_function Parser.Incremental.mlw_file lb in
    if path = [] && Debug.test_flag debug then begin
      let print_m _ m = Format.eprintf "%a@\n@." print_module m in
      let add_m _ m mm = Mid.add m.mod_theory.th_name m mm in
      Mid.iter print_m (Mstr.fold add_m mm Mid.empty)
    end;
    mm

  let () = Env.register_format mlw_language "whyml" ["mlw";"why"] read_channel
    ~desc:"WhyML@ programming@ and@ specification@ language"

}
