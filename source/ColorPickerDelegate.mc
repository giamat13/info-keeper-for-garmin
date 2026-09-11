import Toybox.WatchUi;
import Toybox.Lang;

// Mirrors CategoriesDelegate: InputDelegate (not BehaviorDelegate) so a tap's
// own coordinate hit-test picks the swatch, and onHold is treated the same as
// onTap for touch+button devices that report a quick press as a hold.
class ColorPickerDelegate extends WatchUi.InputDelegate {

    var view as ColorPickerView;
    var onChosen as Lang.Method;

    function initialize(v as ColorPickerView, cb as Lang.Method) {
        InputDelegate.initialize();
        view = v;
        onChosen = cb;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        var color = view.colorAt(x, y);
        if (color == null) {
            return false;
        }
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        onChosen.invoke(color as Number);
        return true;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

}
