import Toybox.WatchUi;
import Toybox.Lang;

// Delegate for DayListView: swipe left/right switches day, swipe up/down (or
// the up/down buttons on non-touch devices) scroll the period list, back pops
// back out to the per-period scroll view.
class DayListDelegate extends WatchUi.BehaviorDelegate {

    var view as DayListView;

    function initialize(v as DayListView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_LEFT) {
            view.moveDay(1);
            return true;
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            view.moveDay(-1);
            return true;
        } else if (dir == WatchUi.SWIPE_UP) {
            view.scroll(1);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.scroll(-1);
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        view.scroll(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.scroll(-1);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

}
