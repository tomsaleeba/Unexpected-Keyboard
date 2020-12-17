open Android_api.Preference

module Layouts = Layouts

type config = {
  layout : Layouts.t;
}

let default = {
  layout = Layouts.qwerty;
}

let of_shared_preferences prefs =
  let open Shared_preferences in
  let layout =
    match get_string prefs "keyboard_layout" "" with
    | "" -> default.layout
    | name -> List.assoc name Layouts.layouts
  in
  { layout }
