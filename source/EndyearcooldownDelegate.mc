import Toybox.Lang;
import Toybox.WatchUi;

// Delegate for the pushed, "entered" view: scrolling (NEXT/PREV, or a swipe
// once swipe input actually reaches this non-initial view) switches which
// date is showing; a press toggles that date between regular and net. Back
// pops back to the categories list.
class EndyearcooldownActiveDelegate extends WatchUi.BehaviorDelegate {

    var _view as EndyearcooldownView;

    function initialize(view as EndyearcooldownView) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onNextPage() as Boolean {
        _view.nextDate();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.previousDate();
        return true;
    }

    function onSelect() as Boolean {
        _view.toggleMode();
        return true;
    }

    function onTap(evt as WatchUi.ClickEvent) as Boolean {
        _view.toggleMode();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        return true;
    }
}
