import Toybox.WatchUi;
import Toybox.Lang;

// Extends the low-level WatchUi.InputDelegate rather than BehaviorDelegate.
// On several touch+button devices, BehaviorDelegate silently converts any
// screen touch into a generic "select" behavior (activating whatever band is
// currently highlighted, ignoring where you actually tapped) before onTap
// ever runs - that made direct taps on a category open the highlighted one
// instead of the one under your finger. InputDelegate skips that
// translation, so onTap's own coordinate hit-test decides which category
// gets entered. Physical buttons are handled directly via onKey() instead
// of BehaviorDelegate's onSelect/onNextPage/onPreviousPage.
class CategoriesDelegate extends WatchUi.InputDelegate {

    var view as CategoriesView;

    function initialize(v as CategoriesView) {
        InputDelegate.initialize();
        view = v;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    // Some devices report a quick press as a hold rather than a tap; handle
    // both the same way so a tap always registers.
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        var idx = view.categoryAt(x, y);
        if (idx == null) {
            return false;
        }
        view.enter(idx as Number);
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            view.enter(view.cursor);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

}
