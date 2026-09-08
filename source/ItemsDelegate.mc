import Toybox.WatchUi;
import Toybox.Lang;

// Up/down (or swipe up/down) scrolls items; back returns to the category list.
class ItemsDelegate extends WatchUi.BehaviorDelegate {

    var view as ItemsView;

    function initialize(v as ItemsView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onNextPage() as Boolean {
        view.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.move(-1);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}
