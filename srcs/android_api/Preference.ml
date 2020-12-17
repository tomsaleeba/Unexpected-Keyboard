class%java shared_preferences "android.preference.SharedPreferences" =
object
  method get_boolean : string -> bool -> bool = "getBoolean"
  method get_float : string -> float -> float = "getFloat"
  method get_int : string -> int -> int = "getInt"
  method get_string : string -> string -> string = "getInt"
end

class%java preference_manager "android.preference.PreferenceManager" =
object
	method [@static] get_default_shared_preferences : Content.context -> shared_preferences = "getDefaultSharedPreferences"
end
