(** Key value to string *)
let render_key =
	let open Key in
	let render_event =
		function
		| Escape		-> "Esc"
		| Tab			-> "\xE2\x87\xA5"
		| Backspace		-> "\xE2\x8C\xAB"
		| Delete		-> "\xE2\x8C\xA6"
		| Enter			-> "\xE2\x8F\x8E"
		| Left			-> "\xE2\x86\x90"
		| Right			-> "\xE2\x86\x92"
		| Up			-> "\xE2\x86\x91"
		| Down			-> "\xE2\x86\x93"
		| Page_up		-> "\xE2\x87\x9E"
		| Page_down		-> "\xE2\x87\x9F"
		| Home			-> "\xE2\x86\x96"
		| End			-> "\xE2\x86\x98"
	and render_modifier =
		function
		| Shift				-> "\xE2\x87\xA7"
		| Ctrl				-> "ctrl"
		| Alt				-> "alt"
		| Accent Acute		-> "\xCC\x81"
		| Accent Grave		-> "\xCC\x80"
		| Accent Circumflex	-> "\xCC\x82"
		| Accent Tilde		-> "\xCC\x83"
		| Accent Cedilla	-> "\xCC\xA7"
		| Accent Trema		-> "\xCC\x88"
	in
	function
	| Typing (Char (c, _))		->
		(* TODO: OCaml and Java are useless at unicode *)
		Java.to_string (Utils.java_string_of_code_point c)
	| Typing (Event (ev, _))	-> render_event ev
	| Modifier m				-> render_modifier m
	| Nothing					-> ""
	| Change_pad Default		-> "ABC"
	| Change_pad Numeric		-> "123"

open Component.Task

type ims = <
	send	: 'a 'e. Key.typing_value -> ('a, 'e) task
>

type t = {
	touch_state		: Touch_event.state;
	layout			: Key.t KeyboardLayout.t;
	modifiers		: Modifiers.t;
	key_repeat		: (Key.t * bool ref) list;
	ims				: ims
}

let create ims = {
	touch_state = Touch_event.empty_state;
	layout = Layouts.qwerty;
	modifiers = Modifiers.empty;
	key_repeat = [];
	ims
}

let set_timeout =
	let open Android_os in
	let handler = lazy (Handler.create ()) in
	fun msec ->
		let t, u = Lwt.task () in
		let callback = Jrunnable.create (Lwt.wakeup u) in
		ignore (Handler.post_delayed (Lazy.force handler) callback msec);
		t

let start_repeat ?(timeout=1000L) key tv t =
	let enabled = ref true in
	let rec repeat_loop ~timeout () =
		let do_repeat () t =
			if !enabled
			then t, [ Task (repeat_loop ~timeout:200L); t.ims#send tv ]
			else t, []
		in
		Lwt.map do_repeat (set_timeout timeout)
	in
	let key_repeat = (key, enabled) :: t.key_repeat in
	{ t with key_repeat }, [ Task (repeat_loop ~timeout); t.ims#send tv ]

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
	Task (fun () -> Lwt.return do_remove)

let handle_down t key = function
	| Key.Modifier m	->
		{ t with modifiers = Modifiers.on_down m t.modifiers }, []
	| Typing tv			-> start_repeat key tv t
	| Change_pad pad	->
		let layout = match pad with
			| Default	-> Layouts.qwerty
			| Numeric	-> Layouts.numeric
		in
		{ t with layout;
			modifiers = Modifiers.empty;
			touch_state = Touch_event.empty_state }, []
	| _					-> t, []

let handle_cancel t key = function
	| Key.Modifier m	->
		{ t with modifiers = Modifiers.on_cancel m t.modifiers }, []
	| Typing tv			-> t, [ stop_repeat key ]
	| _					-> t, []

let handle_up t key = function
	| Key.Typing tv			->
		let tv = Modifiers.apply tv t.modifiers
		and modifiers = Modifiers.on_key_press t.modifiers in
		{ t with modifiers }, [ stop_repeat key; t.ims#send tv ]
	| Modifier m			->
		{ t with modifiers = Modifiers.on_up m t.modifiers }, []
	| _						-> t, []

let on_touch ev t =
	match Touch_event.on_touch t.layout t.touch_state ev with
	| Key_down (key, ts)				->
		let t, tasks = handle_down t key key.v in
		{ t with touch_state = ts }, tasks
	| Key_up (key, v, ts)				->
		let t, tasks = handle_up t key v in
		{ t with touch_state = ts }, tasks
	| Pointer_changed (key, v', v, ts)	->
		let t, tasks = handle_cancel t key v' in
		let t', tasks' = handle_down t key v in
		{ t with touch_state = ts }, (tasks @ tasks')
	| Cancelled (key, v, ts)			->
		let t, tasks = handle_cancel t key v in
		{ t with touch_state = ts }, tasks
	| Ignore							-> t, []

let measure ~dp t w_spec _ =
	w_spec, int_of_float (dp 200.)

let draw ~dp t canvas =
	let is_activated key =
		match Touch_event.key_activated t.touch_state key with
		| exception Not_found	-> false
		| _						-> true
	and render_key k =
		let k = match k with
			| Key.Typing tv	-> Key.Typing (Modifiers.apply tv t.modifiers)
			| k				-> k
		in
		render_key k
	in
	Drawing.keyboard is_activated dp render_key t.layout canvas

let view = Component_Android.view ~on_touch ~measure ~draw
