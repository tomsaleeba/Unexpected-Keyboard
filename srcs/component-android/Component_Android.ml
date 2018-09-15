open Android_content
open Android_util
open Android_view
open Android_widget

let view_of p = View.of_obj p

module T = Component_Dom.Make (struct
	type element = View.t
	type element' = View_group.t
	let coerce = view_of
	let insert parent i node = View_group.add_view parent node i
	let delete parent i = View_group.remove_view_at parent i
	let replace parent i node = delete parent i; insert parent i node
end)

include ComponentTmpl
include T.T

open Component
open ComponentTmpl_T
open T

(* Some global variables *)
let context : Context.t ref = ref Java.null
let dp : (float -> float) ref = ref (fun _ -> failwith "not initialized")

(** Set the Context object
	Must be called before any tmpl is initialized *)
let init ctx =
	let density = Context.get_resources ctx
		|> Resources.get_display_metrics
		|> Display_metrics.get'scaled_density
	in
	context := ctx;
	dp := ( *. ) density

(** TextView *)
let text f : ('a, 'e) tmpl =
	fun data event_push ->
		let text = ref (f data) in
		let element = Text_view.create !context in
		Text_view.set_text element !text;
		let mount parent =
			parent (Insert (0, view_of element));
			let update data =
				let text' = f data in
				if text' <> !text then (
					text := text';
					Text_view.set_text element text'
				)
			and unmount () =
				parent (Delete 0)
			in
			update, unmount
		and deinit () = () in
		mount, deinit

(** LinearLayout *)
let linear_layout orientation childs : ('a, 'e) tmpl =
	let create () =
		let l = Linear_layout.create !context in
		Linear_layout.set_orientation l orientation;
		(* (l :> View_group.t) *)
		View_group.of_obj l
	in
	e create [] childs

let horizontal childs = linear_layout linear_layout_HORIZONTAL childs
let vertical childs = linear_layout linear_layout_VERTICAL childs

type motion_event' = Move | Up | Down | Cancel

type motion_event = {
	event	: motion_event';
	id		: int;
	x		: float;
	y		: float
}

(** Convert a MotionEvent into a more digestible representation *)
let on_motion_event ~push_motion_event ~width ~height ev =
	let open Motion_event in
	let push event index =
		let x = get_x ev index /. width
		and y = get_y ev index /. height
		and id = get_pointer_id ev index in
		push_motion_event { event; id; x; y }
	in
	let action = get_action_masked ev in
	if action = motion_event_ACTION_MOVE
	then for i = 0 to get_pointer_count ev - 1 do
			push Move i
		done
	else if action = motion_event_ACTION_UP
		|| action = motion_event_ACTION_POINTER_UP
	then push Up (get_action_index ev)
	else if action = motion_event_ACTION_DOWN
		|| action = motion_event_ACTION_POINTER_DOWN
	then push Down (get_action_index ev)
	else if action = motion_event_ACTION_CANCEL
	then push Cancel (get_action_index ev)
	else ()

(** CustomView *)
let view ?(eq=(=)) ~on_touch ~measure ~draw =
	fun data event_push ->
		let data = ref data in
		let push_motion_event me = event_push (on_touch me) in
		let view = CustomView.create !context (fun view ->
			object
				method onTouchEvent ev =
					let width = float (View.get_width view)
					and height = float (View.get_height view) in
					on_motion_event ~push_motion_event ~width ~height ev;
					true
				method onMeasure w_spec h_spec =
					let w = Measure_spec.get_size w_spec
					and h = Measure_spec.get_size h_spec in
					let w, h = measure ~dp:!dp !data w h in
					View.set_measured_dimension view w h
				method onDraw canvas = draw ~dp:!dp !data canvas
				method onDetachedFromWindow = ()
			end)
		in
		let mount parent =
			parent (Insert (0, view_of view));
			let update data' =
				if not (eq !data data') then (
					View.invalidate view;
					data := data'
				)
			and unmount () = parent (Delete 0) in
			update, unmount
		and deinit () = () in
		mount, deinit
