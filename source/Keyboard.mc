import Toybox.WatchUi;
import Toybox.Lang;

// One-line entry point for the on-watch keyboard, so every text-entry call
// site (category name, item label/value, renames) stays a single statement.
class Keyboard {

    static function show(initialText as String, cb as Lang.Method) as Void {
        var kbView = new KeyboardView(initialText);
        WatchUi.pushView(kbView, new KeyboardDelegate(kbView, cb), WatchUi.SLIDE_UP);
    }

}
