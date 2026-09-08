import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

// Button watches: up/down (or swipe up/down) moves the highlighted category,
// select opens it. Touch watches additionally get direct tap-to-open on
// whichever third of the screen was tapped.
class CategoriesDelegate extends WatchUi.BehaviorDelegate {

    var view as CategoriesView;

    function initialize(v as CategoriesView) {
        BehaviorDelegate.initialize();
        view = v;
    }

    function onSelect() as Boolean {
        view.enter(view.cursor);
        return true;
    }

    function onNextPage() as Boolean {
        view.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.move(-1);
        return true;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        var idx = view.slotAt(coords[1], System.getDeviceSettings().screenHeight);
        if (idx != null) {
            view.enter(idx as Number);
            return true;
        }
        return false;
    }

}
