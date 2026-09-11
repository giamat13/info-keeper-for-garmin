import Toybox.WatchUi;
import Toybox.Lang;

// One-line entry point for a full-screen message the user must dismiss by
// tapping X, mirroring Keyboard.show's single-call convenience.
class Alert {

    static function show(message as String, cb as Lang.Method) as Void {
        var view = new AlertView(message);
        WatchUi.pushView(view, new AlertDelegate(view, cb), WatchUi.SLIDE_UP);
    }

}
