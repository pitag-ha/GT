(** Html module: converts a value to its html represenation (based on module TODO).

    Work in progress.
*)

(*
    For type declaration [type ('a,'b,...) typ = ...] it will create a transformation
    function with type

    [(Format.formatter -> 'a -> unit) -> (Format.formatter -> 'b -> unit) -> ... ->
     Format.formatter -> ('a,'b,...) typ -> unit ]

    Inherited attributes' type (both default and for type parameters) is
    [Format.formatter].
    Synthesized attributes' type (both default and for type parameters) is [unit].
*)

(*
 * OCanren: syntax extension.
 * Copyright (C) 2016-2017
 *   Dmitrii Kosarev aka Kakadu
 * St.Petersburg State University, JetBrains Research
 *)

(* NOT IMPELEMENTED YET *)
open Base
open Ppxlib
open HelpersBase
open Printf

let trait_name = "html"

module Make(AstHelpers : GTHELPERS_sig.S) = struct

let plugin_name = trait_name

module P = Plugin.Make(AstHelpers)
open AstHelpers

let app_format_sprintf ~loc arg =
  Exp.app ~loc
    (Exp.of_longident ~loc (Ldot(Lident "Format", "sprintf")))
    arg

module H = struct
  type elt = Exp.t
  let wrap ~loc s = Exp.of_longident ~loc (Ldot (Lident "Tyxml_html", s))
  let pcdata ~loc s = Exp.(app ~loc (wrap ~loc "pcdata") (string_const ~loc s))
  let div ~loc xs =
    Exp.app ~loc (wrap ~loc "div") @@
    Exp.list ~loc xs
end

let html_param_name = "html"

class g args = object(self)
  inherit [loc, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t] Plugin_intf.typ_g
  inherit P.generator args
  inherit P.no_inherit_arg

  method plugin_name = trait_name
  method default_inh ~loc _tdecl = Typ.ident ~loc "unit"
  method default_syn ~loc ?extra_path _tdecl = self#syn_of_param ~loc "dummy"

  method syn_of_param ~loc _     =
    Typ.constr ~loc (Ldot (Lident "Tyxml_html", "elt")) [ Typ.var ~loc "html" ]

  method inh_of_param tdecl _name = self#default_inh ~loc:noloc tdecl

  method plugin_class_params tdecl =
    (* TODO: reuse prepare_inherit_typ_params_for_alias here *)
    let ps =
      List.map tdecl.ptype_params ~f:(fun (t,_) -> typ_arg_of_core_type t)
    in
    ps @
    [ named_type_arg ~loc:(loc_from_caml tdecl.ptype_loc) html_param_name
    ; named_type_arg ~loc:(loc_from_caml tdecl.ptype_loc) Plugin.extra_param_name
    ]

  method prepare_inherit_typ_params_for_alias ~loc tdecl rhs_args =
    List.map rhs_args ~f:Typ.from_caml @
    [ Typ.var ~loc html_param_name
    ]

  method on_tuple_constr ~loc ~is_self_rec ~mutal_names ~inhe constr_info ts =
    let constr_name = match constr_info with
      | `Poly s -> sprintf "`%s" s
      | `Normal s -> s
    in

    let names = List.map ts ~f:fst in
    Exp.fun_list ~loc
      (List.map names ~f:(Pat.sprintf ~loc "%s"))
      (if List.length ts = 0
       then Exp.string_const ~loc constr_name
       else
         let ds = List.map ts
           ~f:(fun (name, typ) ->
                 self#app_transformation_expr ~loc
                   (self#do_typ_gen ~loc ~is_self_rec ~mutal_names typ)
                   (Exp.assert_false ~loc)
                   (Exp.ident ~loc name)
              )
         in
         H.div ~loc
           ([H.pcdata ~loc constr_name; H.pcdata ~loc "("] @ ds @ [ H.pcdata ~loc ")" ])

      )


  method on_record_declaration ~loc ~is_self_rec ~mutal_names tdecl labs =
    let pat = Pat.record ~loc @@
      List.map labs ~f:(fun l ->
          (Lident l.pld_name.txt, Pat.var ~loc l.pld_name.txt)
        )
    in
    let methname = sprintf "do_%s" tdecl.ptype_name.txt in
    let fmt = List.fold_left labs ~init:""
        ~f:(fun acc x ->
            sprintf "%s %s=%%s;" acc x.pld_name.txt
          )
    in
    [ Cf.method_concrete ~loc methname @@
      Exp.fun_ ~loc (Pat.unit ~loc) @@
      Exp.fun_ ~loc pat @@

      let ds = List.map labs
            ~f:(fun {pld_name; pld_type} ->
              self#app_transformation_expr ~loc
                (self#do_typ_gen ~loc ~is_self_rec ~mutal_names pld_type)
                (Exp.assert_false ~loc)
                (Exp.ident ~loc pld_name.txt)
            )
      in
      H.div ~loc ds
    ]

end

let g = (new g :> (Plugin_intf.plugin_args ->
                   (loc, Typ.t, type_arg, Ctf.t, Cf.t, Str.t, Sig.t) Plugin_intf.typ_g) )
end

let register () =
  Expander.register_plugin trait_name (module Make: Plugin_intf.PluginRes)

let () = register ()
