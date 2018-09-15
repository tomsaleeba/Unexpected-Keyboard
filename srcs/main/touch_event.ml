(** Handle touch events *)
open Android_view

(** Pointers store its initial position, id and key *)
type pointer = {
	ptrid	: int;
	down_x	: float;
	down_y	: float;
	key		: Key.t;
	value	: Key.value
}

let pointer ptrid down_x down_y key =
	{ ptrid; down_x; down_y; key; value = key.v }

type state = pointer list

(** Event returned by [on_touch]
	The [Key.t] values can be compared physically to track pointers *)
type event =
	| Key_down of Key.t * state
	| Key_up of Key.t * Key.value * state
	| Pointer_changed of Key.t * Key.value * Key.value * state
	| Cancelled of Key.t * Key.value * state
	| Ignore

let empty_state = []

let get_pointer ptrid state = List.find (fun p -> p.ptrid = ptrid) state
let remove_pointer pointers ptrid = List.filter (fun p -> p.ptrid <> ptrid) pointers

let corner_dist = 0.1

(** Returns the value of the key when the pointer moved (dx, dy)
	Corner values are only considered if (dx, dy)
		has a size of `corner_dist` or more *)
let pointed_value dx dy key =
	let open Key in
	if dx *. dx +. dy *. dy < corner_dist *. corner_dist
	then key.v
	else match dx > 0., dy > 0., key with
		| true, true, { a = Some v }
		| false, true, { b = Some v }
		| false, false, { c = Some v }
		| true, false, { d = Some v }
		| _, _, { v }		-> v

(** Returns the activated value of a key,
	Raises [Not_found] if the key is not activated at all *)
let key_activated state key =
	let p = List.find (fun p -> p.key == key) state in
	p.value

let on_touch layout state ev =
	match ev.Component_Android.event with
	| Move		->
		begin match get_pointer ev.id state with
		| exception Not_found	-> Ignore
		| p						->
			let dx, dy = p.down_x -. ev.x, p.down_y -. ev.y in
			let value = pointed_value dx dy p.key in
			if value = p.value
			then Ignore
			else
				let state = { p with value } :: remove_pointer state ev.id in
				Pointer_changed (p.key, p.value, value, state)
		end

	| Up		->
		begin match get_pointer ev.id state with
		| exception Not_found	-> Ignore
		| p						->
			let dx, dy = p.down_x -. ev.x, p.down_y -. ev.y in
			let v = pointed_value dx dy p.key in
			Key_up (p.key, v, remove_pointer state ev.id)
		end

	| Down		->
		begin match KeyboardLayout.pick layout ev.x ev.y with
		| Some (_, key)	-> Key_down (key, pointer ev.id ev.x ev.y key :: state)
		| None			-> Ignore
		end

	| Cancel	->
		begin match get_pointer ev.id state with
		| exception Not_found -> Ignore
		| p -> Cancelled (p.key, p.value, remove_pointer state ev.id)
		end
