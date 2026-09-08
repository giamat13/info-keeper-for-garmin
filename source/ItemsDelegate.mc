import Toybox.WatchUi;
import Toybox.Lang;

// InputDelegate rather than BehaviorDelegate for the same reason as
// CategoriesDelegate: BehaviorDelegate's touch translation can misfire on
// touch+button devices, so raw onSwipe/onKey are used directly instead of
// its onNextPage/onPreviousPage/onBack.
class ItemsDelegate extends WatchUi.InputDelegate {

    var view as ItemsView;

    function initialize(v as ItemsView) {
        InputDelegate.initialize();
        view = v;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

}
