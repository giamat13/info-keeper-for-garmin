import Toybox.WatchUi;
import Toybox.Lang;

// InputDelegate (not BehaviorDelegate) for the same touch+button reason as
// CategoriesDelegate. Tapping X (or pressing ESC/ENTER) dismisses and
// always invokes `onDismiss` - an Alert is informational, not a choice.
class AlertDelegate extends WatchUi.InputDelegate {

    var view as AlertView;
    var onDismiss as Lang.Method;

    function initialize(v as AlertView, cb as Lang.Method) {
        InputDelegate.initialize();
        view = v;
        onDismiss = cb;
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
        if (!view.xButtonContains(x, y)) {
            return false;
        }
        dismiss();
        return true;
    }

    private function dismiss() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        onDismiss.invoke();
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ESC || key == WatchUi.KEY_ENTER) {
            dismiss();
            return true;
        }
        return false;
    }

}
