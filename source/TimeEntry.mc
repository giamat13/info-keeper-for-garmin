import Toybox.WatchUi;
import Toybox.Lang;

// One-line entry point for typing a 24h HH:MM time, reusing PinPadView's
// numeric keypad unmasked (mirrors Keyboard.show/PinEntry.request) - `cb`
// receives the raw digit string typed ("" if none), caller parses/validates.
class TimeEntry {

    static function show(initialDigits as String, cb as Lang.Method) as Void {
        var view = new PinPadView();
        view.masked = false;
        view.maxLen = 4;
        view.entered = initialDigits;
        WatchUi.pushView(view, new PinPadDelegate(view, cb), WatchUi.SLIDE_UP);
    }

}
