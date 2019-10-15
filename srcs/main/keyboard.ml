type t = {
	touch_state		: Touch_event.state;
	layout			: Key.t KeyboardLayout.t;
	modifiers		: Modifiers.t;
	key_repeat		: (Key.t * bool ref) list
}

let create = {
	touch_state = Touch_event.empty_state;
	layout = Layouts.qwerty;
	modifiers = Modifiers.empty;
	key_repeat = []
}

let start_repeat ?(timeout=1000L) key action t =
	let task t = Keyboard_service.Task t in
	let enabled = ref true in
	let rec repeat_loop ~timeout () =
		let do_repeat () t =
			if !enabled
			then t, [ task (repeat_loop ~timeout:200L); action ]
			else t, []
		in
		Lwt.map do_repeat (Keyboard_service.timeout timeout)
	in
	(key, enabled) :: t.key_repeat, task (repeat_loop ~timeout)

let rec stop_repeat key = function
	| (k', enabled) :: tl when k' == key ->
		enabled := false;
		stop_repeat key tl
	| hd :: tl	-> hd :: stop_repeat key tl
	| []		-> []

let stop_repeat key =
	let do_remove t =
		{ t with key_repeat = stop_repeat key t.key_repeat }, []
	in
	Keyboard_service.Task (fun () -> Lwt.return do_remove)

let handle_down t touch_state key = function
	| Key.Modifier m	->
		let modifiers = Modifiers.on_down m t.modifiers in
		{ t with touch_state; modifiers }, []
	| Typing tv			->
		let key_repeat, task = start_repeat key (send tv) t in
		{ t with touch_state; key_repeat }, [ task ]
	| Change_pad pad	->
		let layout = match pad with
			| Default	-> Layouts.qwerty
			| Numeric	-> Layouts.numeric
		in
		{ t with layout;
			modifiers = Modifiers.empty;
			touch_state = Touch_event.empty_state }, []
	| _					-> { t with touch_state }, []

let handle_cancel t touch_state key = function
	| Key.Modifier m	->
		let modifiers = Modifiers.on_cancel m t.modifiers in
		{ t with touch_state; modifiers }, []
	| Typing tv			-> { t with touch_state }, [ stop_repeat key ]
	| _					-> { t with touch_state }, []

let handle_up t touch_state key = function
	| Key.Typing tv			->
		let tv = Modifiers.apply tv t.modifiers
		and modifiers = Modifiers.on_key_press t.modifiers in
		{ t with touch_state; modifiers }, [ stop_repeat key; send tv ]
	| Modifier m			->
		let modifiers = Modifiers.on_up m t.modifiers in
		{ t with touch_state; modifiers }, []
	| _						-> { t with touch_state }, []
