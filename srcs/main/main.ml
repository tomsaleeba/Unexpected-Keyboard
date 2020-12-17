open Android_utils
open Android_api.Preference

external _hack : unit -> unit = "Java_juloo_javacaml_Caml_startup"

let keyboard_service ims =
  let prefs = Preference_manager.get_default_shared_preferences ims in
  let config = Keyboard_view.Config.of_shared_preferences prefs in
  let view = lazy (CustomView.create ims (Keyboard_view.create ~ims ~config)) in
	object
		method onInitializeInterface = ()
		method onBindInput = ()
		method onCreateInputView = Lazy.force view
		method onCreateCandidatesView = Java.null
		method onStartInput _ _ = ()
	end

let () =
	Printexc.record_backtrace true;
	Android_enable_logging.enable "UNEXPECTED KEYBOARD";
	UnexpectedKeyboardService.register keyboard_service
