import Toybox.WatchUi;
import Toybox.Lang;

// InputDelegate (not BehaviorDelegate) for the same touch+button reason as
// CategoriesDelegate: raw onTap coordinate hit-testing, onHold mirrors onTap.
class KeyboardDelegate extends WatchUi.InputDelegate {

    var view as KeyboardView;
    var onDone as Lang.Method;

    function initialize(v as KeyboardView, cb as Lang.Method) {
        InputDelegate.initialize();
        view = v;
        onDone = cb;
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
        var key = view.keyAt(x, y);
        if (key == null) {
            return false;
        }
        var action = key.action;
        if (action.equals("ok")) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            onDone.invoke(view.text);
        } else if (action.equals("del")) {
            view.backspace();
            WatchUi.requestUpdate();
        } else if (action.equals("space")) {
            view.insertChar(" ");
            WatchUi.requestUpdate();
        } else if (action.equals("page")) {
            view.togglePage();
            WatchUi.requestUpdate();
        } else if (action.find("char:") == 0) {
            view.insertChar(action.substring(5, action.length()) as String);
            WatchUi.requestUpdate();
        }
        return true;
    }

    // Swipe-right/ESC cancels without invoking the callback (nothing typed
    // is kept), same semantics the old TextPicker cancel had.
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
