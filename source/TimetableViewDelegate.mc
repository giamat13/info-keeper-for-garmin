import Toybox.WatchUi;
import Toybox.Lang;

// Delegate for TimetableView, pushed from CategoriesView.enter() when the
// category is a timetable (InfoCategory.isTimetable). Ported/merged from
// School-timetable's TimetableDelegate + TimetableScrollDelegate, which used
// to be split across a widget's glance/entered views - here there's only one
// view, reached by an explicit tap from CategoriesView, so the two collapse
// into one BehaviorDelegate.
class TimetableViewDelegate extends WatchUi.BehaviorDelegate {

    var view as TimetableView;

    function initialize(v as TimetableView) {
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
            view.move(1);
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.move(-1);
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        view.move(1);
        return true;
    }

    function onPreviousPage() as Boolean {
        view.move(-1);
        return true;
    }

    // Drill further in: show every period of the currently viewed day at once.
    function onSelect() as Boolean {
        var dayIdx = view.cursor / 1000;
        var dayView = new DayListView(view.timetable, dayIdx);
        WatchUi.pushView(dayView, new DayListDelegate(dayView), WatchUi.SLIDE_UP);
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

}
