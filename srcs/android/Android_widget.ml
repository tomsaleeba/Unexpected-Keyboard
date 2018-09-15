open Android_content
open Android_view

class%java text_view "android.widget.TextView" =
object
	initializer (create : context -> _)
	method set_text : char_sequence -> unit = "setText"
end

let linear_layout_HORIZONTAL = 0
let linear_layout_VERTICAL = 1

class%java linear_layout "android.widget.LinearLayout" =
object
	inherit view_group
	initializer (create : context -> _)
	method set_orientation : int -> unit = "setOrientation"
end
