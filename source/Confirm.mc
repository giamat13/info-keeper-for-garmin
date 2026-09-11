import Toybox.WatchUi;
import Toybox.Lang;

// One-line entry point for a full-screen Yes/No question, mirroring
// Keyboard.show/Alert.show. Replaces WatchUi.Confirmation: that native
// widget's pop timing relative to onResponse turned out to be undocumented
// and inconsistent (see ConfirmViewDelegate for the full story) - this is a
// plain View+InputDelegate like ColorPickerView, so exactly when the pop
// happens is entirely under our own control.
class Confirm {

    static function show(message as String, onYes as Lang.Method, onNo as Lang.Method?) as Void {
        var view = new ConfirmView(message);
        WatchUi.pushView(view, new ConfirmViewDelegate(view, onYes, onNo), WatchUi.SLIDE_UP);
    }

}
