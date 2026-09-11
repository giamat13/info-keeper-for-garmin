import Toybox.WatchUi;
import Toybox.Lang;

// One-line entry point for prompting a PIN: numeric pad when the currently
// set PIN is digits-only, full keyboard otherwise (mirrors Keyboard.show -
// invokes `cb` with whatever was typed on "OK", regardless of whether it
// turns out to be correct; callers check that themselves via
// PinManager.verify()).
class PinEntry {

    static function request(cb as Lang.Method) as Void {
        if (PinManager.isNumeric()) {
            var padView = new PinPadView();
            WatchUi.pushView(padView, new PinPadDelegate(padView, cb), WatchUi.SLIDE_UP);
        } else {
            Keyboard.show("", cb);
        }
    }

}
