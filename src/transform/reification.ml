open Term
open Ty
open Decl
open Ident
open Task
open Args_wrapper

let rec fold_left3 f accu l1 l2 l3 =
  match (l1, l2, l3) with
  | a1::l1, a2::l2, a3::l3 -> fold_left3 f (f accu a1 a2 a3) l1 l2 l3
  | [], [], [] -> accu
  | _ -> raise (Invalid_argument "fold_left3")

exception NoReification
exception Exit

let debug = true

let expl_reification_check = Ident.create_label "expl:reification check"

type reify_env = { kn: known_map;
                   store: int Mterm.t;
                   fr: int;
                   subst: term Mvs.t;
                   lv: Svs.t;
                   vy: vsymbol option;
                   ty_val: ty option;
                 }

let init_renv kn lv = { kn=kn;
                        store = Mterm.empty;
                        fr = 0;
                        subst = Mvs.empty;
                        lv = lv;
                        vy = None;
                        ty_val = None;
                      }

let rec reify_term renv t rt =
  let rec invert_pat vl (env, fr) interp (p,f) t =
    if debug
    then Format.printf
           "invert_pat p %a f %a t %a@."
           Pretty.print_pat p Pretty.print_term f Pretty.print_term t;
    match p.pat_node, f.t_node, t.t_node with
    | Pwild, _, _ -> raise NoReification
    | Papp (cs, [{pat_node = Pvar v1}]),
      Tapp (ffa,[{t_node = Tvar vy}; {t_node = Tvar v2}]),
      Tvar _
      | Papp (cs, [{pat_node = Pvar v1}]),
        Tapp (ffa,[{t_node = Tvar vy}; {t_node = Tvar v2}]),
        Tapp(_, [])
         when ty_equal v1.vs_ty ty_int
              && Svs.mem v1 p.pat_vars
              && vs_equal v1 v2
              && ls_equal ffa fs_func_app
              && List.exists (fun vs -> vs_equal vs vy) vl (*FIXME*)
      ->
       if debug then Format.printf "case var@.";
       let rty = cs.ls_value in
       if Mterm.mem t env
       then
         begin
           if debug then Format.printf "%a exists@." Pretty.print_term t;
           (env, fr, t_app cs [t_nat_const (Mterm.find t env)] rty)
         end
       else
         begin
           if debug then Format.printf "%a is new@." Pretty.print_term t;
           let env = Mterm.add t fr env in
           (env, fr+1, t_app cs [t_nat_const fr] rty)
         end
    | Papp (cs, pl), Tapp(ls1, la1), Tapp(ls2, la2) when ls_equal ls1 ls2
      ->
       if debug then Format.printf "case app@.";
       (* same head symbol, match parameters *)
       let env, fr, rl =
         fold_left3
           (fun (env, fr, acc) p f t ->
             let env, fr, nt = invert_pat vl (env, fr) interp (p, f) t in
             if debug
             then Format.printf "param %a matched@." Pretty.print_term t;
             (env, fr, nt::acc))
           (env, fr, []) pl la1 la2 in
       if debug then Format.printf "building app %a of type %a with args %a@."
                                   Pretty.print_ls cs
                                   Pretty.print_ty (Opt.get cs.ls_value)
                                   (Pp.print_list Pp.comma Pretty.print_term)
                                   (List.rev rl);
       let t = t_app cs (List.rev rl) cs.ls_value in
       if debug then Format.printf "app ok@.";
       env, fr, t
    | Papp _, Tapp (ls1, _), Tapp(ls2, _) ->
       if debug then Format.printf "head symbol mismatch %a %a@."
                                   Pretty.print_ls ls1 Pretty.print_ls ls2;
       raise NoReification
    | Por (p1, p2), _, _ ->
       if debug then Format.printf "case or@.";
       begin try invert_pat vl (env, fr) interp (p1, f) t
             with NoReification -> invert_pat vl (env, fr) interp (p2, f) t
       end
    | Pvar _, Tvar _, Tvar _ | Pvar _, Tvar _, Tapp (_, [])
      | Pvar _, Tvar _, Tconst _
      -> if debug then Format.printf "case vars@.";
         (env, fr, t)
    | Pvar _, Tapp (ls, _la), _ when ls_equal ls interp
      -> if debug then Format.printf "case interp@.";
         invert_interp (env, fr) ls t
    (*| Papp (cs, pl), Tapp (ls1, la1), _ when Sls.mem ls1 !reify_invert
    -> (* Cst c -> morph c <- 42 ? *) *)
    | _ -> raise NoReification
  and invert_interp (env, fr) ls (t:term) = (*la ?*)
    let ld = Opt.get (find_logic_definition renv.kn ls) in
    let vl, f = open_ls_defn ld in
    (*assert (oty_equal f.t_ty t.t_ty);*)
    if debug then Format.printf "invert_interp ls %a t %a@."
                                Pretty.print_ls ls Pretty.print_term t;
    match f.t_node, t.t_node with
    | Tcase (x, bl), _ ->
       (*FIXME*)
       assert (List.length vl = 2);
       (match x.t_node with
        | Tvar v when vs_equal v (List.hd vl) -> ()
        | _ -> assert false);
       if debug then Format.printf "case match@.";
       let rec aux = function
         | [] -> raise NoReification
         | tb::l ->
            try invert_pat vl (env, fr) ls (t_open_branch tb) t
            with NoReification ->
                 if debug then Format.printf "match failed@."; aux l in
       aux bl
    | _ -> raise NoReification in
  if debug then Format.printf "reify_term t %a rt %a@."
                              Pretty.print_term t Pretty.print_term rt;
  if not (oty_equal t.t_ty rt.t_ty)
  then (if debug
        then Format.printf "reification type mismatch %a %a@."
                           Pretty.print_ty (Opt.get t.t_ty) Pretty.print_ty (Opt.get rt.t_ty);
        raise NoReification);
  match t.t_node, rt.t_node with
  | _, Tapp(interp, [{t_node = Tvar vx}; {t_node = Tvar vy'} ])
       when Svs.mem vx renv.lv && Svs.mem vy' renv.lv  ->
     if debug then Format.printf "case interp@.";
     if renv.vy <> None && not (vs_equal (Opt.get renv.vy) vy')
     then (if debug then Format.printf "y map conflict@.";
           raise NoReification);
     let store, fr, x = invert_interp (renv.store, renv.fr) interp t in
     let renv =  { renv with store = store; fr = fr; subst = Mvs.add vx x renv.subst } in
     if renv.vy = None
     then begin
       assert (renv.ty_val = None);
       let ty_val = match interp.ls_args, interp.ls_value with
         | [ _ty_target; ty_vars ], Some ty_val
              when ty_equal ty_vars (ty_func ty_int ty_val)
           -> ty_val
         | _ -> raise NoReification in
       {renv with vy = Some vy'; ty_val = Some ty_val } end
     else renv
  | Tapp(eq, [t1; t2]), Tapp (eq', [rt1; rt2])
       when ls_equal eq ps_equ && ls_equal eq' ps_equ ->
     if debug then Format.printf "case eq@.";
     reify_term (reify_term renv t1 rt1) t2 rt2
  | _ -> if debug then Format.printf "no reify_term match@."; raise NoReification

let build_vars_map renv prev =
    if debug then Format.printf "building vars map@.";
    let ty_val = Opt.get renv.ty_val in
    let ty_vars = ty_func ty_int ty_val in
    let ly = create_fsymbol (Ident.id_fresh "y") [] ty_vars in
    let y = t_app ly [] (Some ty_vars) in
    let vy = Opt.get renv.vy in
    let subst = Mvs.add vy y renv.subst in
    if not (Svs.for_all (fun v -> Mvs.mem v subst) renv.lv)
    then (if debug
          then Format.printf "some vars not matched, todo use context";
          raise Exit);
    let d = create_param_decl ly in
    let prev = Task.add_decl prev d in
    let prev = Mterm.fold
                 (fun t i prev ->
                   let et = t_equ
                              (t_app fs_func_app [y; t_nat_const i]
                                     (Some ty_val))
                              t in
                   if debug then Format.printf "eq_term ok@.";
                   let pr = create_prsymbol (Ident.id_fresh "y_val") in
                   let d = create_prop_decl Paxiom pr et in
                   Task.add_decl prev d)
                 renv.store prev in
    subst, prev

let build_goals prev subst lp g rt =
  if debug then Format.printf "building goals@.";
  let inst_rt = t_subst subst rt in
  if debug then Format.printf "reified goal instantiated@.";
  let inst_lp = List.map (t_subst subst) lp in
  if debug then Format.printf "premises instantiated@.";
  let d_r = create_prop_decl Paxiom
                             (create_prsymbol (id_fresh "HR")) inst_rt in
  let pr = create_prsymbol
             (id_fresh "GR"
                       ~label:(Slab.singleton expl_reification_check)) in
  let d = create_prop_decl Pgoal pr g in
  let task_r = Task.add_decl (Task.add_decl prev d_r) d in
  if debug then Format.printf "building cut indication@.";
  let ci =
    match (rt.t_node, g.t_node) with
    | (Tapp(eq, rh::rl),
       Tapp(eq', h::l))
         when ls_equal eq eq' ->
       List.fold_left2 (fun ci st rst -> t_and ci (t_equ (t_subst subst rst) st))
                       (t_equ (t_subst subst rh) h)
                       l rl
    | _,_ when g.t_ty <> None -> t_equ (t_subst subst rt) g
    | _ -> raise Exit in
  if debug then Format.printf "building tasks@.";
  let ltask_r = Trans.apply (Cut.cut ci (Some "interp")) task_r in
  if debug then Format.printf "cut ok@.";
  let lt = List.map (fun ng -> Task.add_decl prev
                       (create_prop_decl Pgoal (create_prsymbol (id_fresh "G")) ng))
                    inst_lp in
  if debug then Format.printf "done@.";
  ltask_r@lt

let reflection_by_lemma pr : Task.task Trans.tlist = Trans.store (fun task ->
  let kn = task_known task in
  let g, prev = Task.task_separate_goal task in
  let g = Apply.term_decl g in
  try
    if debug then Format.printf "start@.";
    let d = Apply.find_hypothesis pr.pr_name prev in
    if d = None then raise Exit;
    let d = Opt.get d in
    let l = Apply.term_decl d in
    let (lp, lv, rt) = Apply.intros l in
    let renv = reify_term (init_renv kn lv) g rt in
    let subst, prev = build_vars_map renv prev in
    build_goals prev subst lp g rt
  with NoReification | Exit -> [task])


open Mltree
open Expr
open Ity

exception CannotReduce

type value =
  | Vconstr of rsymbol * field list
  | Vint of BigInt.t
  | Vbool of bool
  | Vvoid
 (*  | Varray of value array *)

and field = Fimmutable of value | Fmutable of value ref

open Format

let rec print_value fmt = function
  | Vvoid -> fprintf fmt "Vvoid"
  | Vbool b -> fprintf fmt "Vbool %b" b
  | Vint i -> fprintf fmt "Vint %a" Number.print_constant (Number.const_of_big_int i)
  | Vconstr (rs, lf) -> fprintf fmt "Vconstr(%a, %a)"
                                Expr.print_rs rs
                                (Pp.print_list Pp.space print_field) lf

and print_field fmt = function
  | Fimmutable v -> fprintf fmt "Fimmutable %a" print_value v
  | Fmutable vr -> fprintf fmt "Fmutable %a" print_value !vr

let field_get f = match f with
  | Fimmutable v -> v
  | Fmutable v -> !v

open Stdlib

let find_module_path env mm path m = match path with
  | [] -> Mstr.find m mm
  | path -> let mm = Env.read_library Pmodule.mlw_language env path in
            Mstr.find m mm

let find_module_id env mm id =
  let (path, m, _) = Pmodule.restore_path id in find_module_path env mm path m

let translate_module =
  let memo = Ident.Hid.create 16 in
  fun m ->
    let name = m.Pmodule.mod_theory.Theory.th_name in
    try Ident.Hid.find memo name with Not_found ->
      let pm = Compile.Translate.module_ m in
      let pm = Compile.Transform.module_ pm in
      Ident.Hid.add memo name pm;
      pm

exception Constructor

let get_decl env mm rs =
  let open Pdecl in
  let id = rs.rs_name in
  let pm = find_module_id env mm id in
  let tm = translate_module pm in
  if Mid.mem id tm.mod_known
  then Mid.find id tm.mod_known
  else
    let pd = Mid.find id tm.mod_from.from_km in
    match pd.pd_node with
    | PDtype l ->
       let rec aux = function
         | [] -> false
         | d::t -> List.mem rs d.itd_constructors || aux t
       in
       if aux l then raise Constructor else raise Not_found
    | _ -> raise Not_found

let builtin_progs = Hrs.create 17

let eval_true _ _ = Vbool true
let eval_false _ _ = Vbool false

let eval_int_op op _ l =
  match l with
  | [Vint i1; Vint i2] ->
     (try Vint (op i1 i2) with Division_by_zero -> raise CannotReduce)
  | _ -> raise CannotReduce

let eval_int_uop uop _ l =
  match l with
  | [Vint i] -> Vint (uop i)
  | _ -> raise CannotReduce

let eval_int_rel r _ l =
  match l with
  | [Vint i1; Vint i2] ->
     Vbool (r i1 i2)
  | _ -> raise CannotReduce

let built_in_modules =
  [
    ["bool"],"Bool", [],
    [ "True", eval_true ;
      "False", eval_false ;
    ] ;
    ["int"],"Int", [],
    [ "infix +", eval_int_op BigInt.add;
      (* defined as x+(-y)
         "infix -", eval_int_op BigInt.sub; *)
      "infix *", eval_int_op BigInt.mul;
      "prefix -", eval_int_uop BigInt.minus;
      "infix =", eval_int_rel BigInt.eq;
      "infix <", eval_int_rel BigInt.lt;
      "infix <=", eval_int_rel BigInt.le;
      "infix >", eval_int_rel BigInt.gt;
      "infix >=", eval_int_rel BigInt.ge;
    ] ;
    ["int"],"MinMax", [],
    [ "min", eval_int_op BigInt.min;
      "max", eval_int_op BigInt.max;
    ] ;
    ["int"],"ComputerDivision", [],
    [ "div", eval_int_op BigInt.computer_div;
      "mod", eval_int_op BigInt.computer_mod;
    ] ;
    ["int"],"EuclideanDivision", [],
    [ "div", eval_int_op BigInt.euclidean_div;
      "mod", eval_int_op BigInt.euclidean_mod;
    ] ;
    (*
   ["array"],"Array",
    ["array", builtin_array_type],
    ["make", exec_array_make ;
     "mixfix []", exec_array_get ;
     "length", exec_array_length ;
     "mixfix []<-", exec_array_set ;
     "copy", exec_array_copy ;
    ] ;*) (* TODO array support*)
  ]

let add_builtin_mo env (l,n,t,d) =
  let mo = Pmodule.read_module env l n in
  let exp = mo.Pmodule.mod_export in
  let kn = mo.Pmodule.mod_known in
  List.iter
    (fun (id,r) ->
      let its = Pmodule.ns_find_its exp [id] in
      r kn its)
    t;
  List.iter
    (fun (id,f) ->
      let ps = Pmodule.ns_find_rs exp [id] in
      Hrs.add builtin_progs ps f)
    d

let get_builtin_progs lib =
  List.iter (add_builtin_mo lib) built_in_modules

type info = {
    env : Env.env;
    mm  : Pmodule.pmodule Mstr.t;
    vars: value Mid.t;
    recs: rsymbol Mrs.t;
  }

let print_id fmt id = fprintf fmt "%s" id.id_string

let get pv info : value =  Mid.find pv.pv_vs.vs_name info.vars

let add_id id v info = {info with vars = Mid.add id v info.vars}
let add_vs vs = add_id vs.vs_name
let add_pv pv = add_vs pv.pv_vs

exception NoMatch

let rec matching info v pat =
  match pat with
  | Pwild -> info
  | Pvar vs -> add_vs vs v info
  | Ptuple pl ->
     begin match v with
     | Vconstr (rs, l) ->
        assert (is_rs_tuple rs);
        List.fold_left2 matching info (List.map field_get l) pl
     | _ -> assert false
     end
  | Por (p1, p2) ->
     begin try matching info v p1 with NoMatch -> matching info v p2 end
  | Pas (p, vs) -> add_vs vs v (matching info v p)
  | Papp (ls, pl) ->
     match v with
     | Vconstr ({rs_logic = RLls ls2}, l) ->
        if ls_equal ls ls2 then
          List.fold_left2 matching info (List.map field_get l) pl
        else if ls2.ls_constr > 0 then raise NoMatch
        else assert false
     | Vbool b ->
        let ls2 = if b then fs_bool_true else fs_bool_false in
        if ls_equal ls ls2 then info else raise NoMatch
     | _ -> raise CannotReduce

let rec interp_expr info (e:Mltree.expr) : value =
  if debug then Format.printf "interp_expr@.";
  Mltree.(match e.e_node with
  | Econst nc -> Vint (Number.compute_int_constant nc)
  | Evar pv ->
     if debug then Format.printf "Evar %a@." print_pv pv;
     (try get pv info
      with Not_found ->
           if debug
           then Format.printf "var %a not found@." print_pv pv;
           raise CannotReduce)
  | Eapp (rs, le) -> begin
      if debug then Format.printf "Eapp %a@." Expr.print_rs rs;
      let eval_call info vl e =
        if debug then Format.printf "eval params@.";
        let info' =
          List.fold_left2
            (fun info e (id, _ty, ig) ->
              assert (not ig);
              let v = interp_expr info e in
              if debug
              then Format.printf "arg %a : %a@." print_id id print_value v;
              add_id id v info)
            info le vl in
        interp_expr info' e in
      if debug then Format.printf "eval call@.";
      try begin
        let rs = if Mrs.mem rs info.recs then Mrs.find rs info.recs else rs in
        if Hrs.mem builtin_progs rs
        then
          let f = Hrs.find builtin_progs rs in
          f rs (List.map (interp_expr info) le)
        else begin
        let decl = get_decl info.env info.mm rs in
        if debug then Format.printf "decl found@.";
        match decl with
        | Dlet (Lsym (_rs, _ty, vl, e)) ->
           eval_call info vl e
        | Dlet(Lrec([{rec_args = vl; rec_exp = e;
                      rec_sym = rs; rec_rsym = rrs; rec_res=_ty}])) ->
           eval_call { info with recs = Mrs.add rrs rs info.recs } vl e
        | Dlet (Lrec _) ->
           if debug then Format.printf "Lrec@."; raise CannotReduce
        | Dlet (Lvar _) ->
           if debug then Format.printf "Lvar@."; raise CannotReduce
        | Dlet (Lany _) ->
           if debug then Format.printf "Lany@."; raise CannotReduce
        | _ -> if debug then Format.printf "not a let decl@.";
               raise CannotReduce
          end
        end
      with
      | Constructor ->
         if debug then Format.printf "constructor@.";
         let field_of_expr pv e =
           let is_mutable = match pv.pv_ity.ity_node with
             | Ityreg _ -> true
             | _ -> false
           in
           let v = interp_expr info e in
           if is_mutable then Fmutable (ref v) else Fimmutable v
         in
         Vconstr(rs, List.map2 field_of_expr rs.rs_cty.cty_args le)
      | Not_found ->
         if debug
         then Format.printf "decl not found@.";
         raise CannotReduce end
  | Efun _ -> raise CannotReduce
  | Elet (Lvar(pv, e), ein) ->
     let v = interp_expr info e in
     interp_expr (add_pv pv v info) ein
  (* FIXME other let decls *)
  | Eif (c, th, el) ->
     begin match interp_expr info c with
     | Vbool true -> interp_expr info th
     | Vbool false -> interp_expr info el
     | _ -> raise CannotReduce
     end
  | Eassign l ->
     List.iter
       (fun (pvs, rs, v) ->
         let fld = fd_of_rs rs in
         let value = get v info in
         match get pvs info with
         | Vconstr(c, args) ->
            let rec aux cargs args =
              match cargs, args with
              | pv :: pvl, v :: vl ->
                 if pv_equal pv fld then
                   match v with
                   | Fmutable r -> r := value
                   | Fimmutable _ -> assert false
                 else
                   aux pvl vl
              | _ -> raise CannotReduce
            in
            aux c.rs_cty.cty_args args
         | _ -> assert false)
       l;
     Vvoid
  | Ematch (e, l) ->
     if debug then Format.printf "Ematch@.";
     let v = interp_expr info e in
     if debug then Format.printf "value %a@." print_value v;
     let rec aux = function
       | [] -> assert false
       | (p,e)::tl ->
          try
            let info' = matching info v p in
            interp_expr info' e
          with NoMatch -> aux tl
     in
     aux l
  | Eblock l ->
     List.fold_left
       (fun _ e -> interp_expr info e) (*ignore all but last result*)
       Vvoid l
  | Eignore e -> ignore (interp_expr info e); Vvoid
  | Ewhile (c, b) ->
     begin match interp_expr info c with
     | Vbool true ->
        ignore (interp_expr info b);
        interp_expr info e
     | Vbool false -> Vvoid
     | _ -> raise CannotReduce end
  | _ -> raise CannotReduce)

let eval_fun decl info = match decl with
  | Dlet (Lsym (_rs, _, _vl, expr)) ->
     interp_expr info expr
  | _ -> raise CannotReduce

let rec value_of_term t =
  match t.t_node with
  | Ttrue -> Vbool true
  | Tfalse -> Vbool false
  | Term.Tapp (ls, lp) when ls.ls_constr > 0 ->
     Vconstr ((restore_rs ls),
              (List.map (fun t -> Fimmutable (value_of_term t)) lp))
  | Tnot t -> begin match value_of_term t with
              | Vbool b -> Vbool (not b)
              | _ -> raise CannotReduce end
  (* TODO Tbinop maybe *)
  | Tconst (Number.ConstInt ic) -> Vint (Number.compute_int_constant ic)
  | _ -> raise CannotReduce

let rec term_of_value = function
  | Vbool true -> t_bool_true
  | Vbool false -> t_bool_false
  | Vint i -> t_bigint_const i
  | Vconstr (rs, lf) ->
     t_app (ls_of_rs rs) (List.map (fun f -> term_of_value (field_get f)) lf)
           (ls_of_rs rs).ls_value
  | Vvoid -> t_void

(*exception FunctionNotFound*)

let reflection_by_function ls env = Trans.store (fun task  ->
  if debug then Format.printf "reflection_f start@.";
  let kn = task_known task in
  let g, prev = Task.task_separate_goal task in
  let g = Apply.term_decl g in
  (*if debug then Format.printf "reading theory@.";
  let th = Env.read_theory env ["compute"] ths in
  let pmod = Pmodule.restore_module th in
  let rs = try Pmodule.ns_find_rs pmod.Pmodule.mod_export [f]
           with Not_found -> raise FunctionNotFound in*)
  let rs = Expr.restore_rs ls in
  let mith = Task.(used_symbols (used_theories task)) in
  let th = Mid.find rs.rs_name mith in
  let pmod = Pmodule.restore_module th in
  let (_, ms, _) = Pmodule.restore_path rs.rs_name in
  let lpost = List.map open_post rs.rs_cty.cty_post in
  if List.exists (fun pv -> pv.pv_ghost) rs.rs_cty.cty_args
  then (if debug then Format.printf "ghost parameter@.";
        raise Exit);
  if debug then Format.printf "building module map@.";
  let mm = Mstr.singleton ms pmod in
  if debug then Format.printf "module map built@.";
  get_builtin_progs env;
  let decl = get_decl env mm rs in
  if debug then Format.printf "initial decl found@.";
  let args = List.map (fun pv -> pv.pv_vs) rs.rs_cty.cty_args in
  let rec reify_post = function
    | [] -> raise NoReification
    | (vres, p)::t -> begin
        try
          if debug then Format.printf "new post@.";
          if debug
          then Format.printf "post: %a, %a@."
                             Pretty.print_vs vres Pretty.print_term p;
          let (lp, lv, rt) = Apply.intros p in
          let lv = List.fold_left Svs.add_left lv args in
          let renv = reify_term (init_renv kn lv) g rt in
          let info = { env = env;
                       mm = mm;
                       recs = Mrs.empty;
                       vars =
                         List.fold_left
                           (fun vars (vs, t) ->
                             if List.mem vs args
                             then Mid.add vs.vs_name (value_of_term t) vars
                             else vars)
                           Mid.empty
                           (Mvs.bindings renv.subst) } in
          if debug then Format.printf "eval_fun@.";
          let res = term_of_value (eval_fun decl info) in
          if debug then Format.printf "res %a@." Pretty.print_term res;
          let rinfo = {renv with subst = Mvs.add vres res renv.subst} in
          rinfo, lp, lv, rt
        with NoReification -> reify_post t
      end
  in
  let rinfo, lp, _lv, rt = reify_post lpost in
  let lp = (rs.rs_cty.cty_pre)@lp in
  let subst, prev = build_vars_map rinfo prev in
  build_goals prev subst lp g rt)

let () = wrap_and_register
           ~desc:"reflection_l <prop> attempts to prove the goal by reflection using the lemma prop"
           "reflection_l"
           (Tprsymbol Ttrans_l) reflection_by_lemma

let () = wrap_and_register
           ~desc:"reflection_f <f> attempts to prove the goal by reflection using the contract of the function f"
           "reflection_f"
           (Tlsymbol Tenvtrans_l) reflection_by_function

(*
Local Variables:
compile-command: "unset LANG; make -C ../.."
End:
*)