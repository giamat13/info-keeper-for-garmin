import Toybox.WatchUi;
import Toybox.Lang;

// Generic Menu2 delegate: dispatches the selected item's id to a matching
// zero-arg callback, so each on-watch options menu doesn't need its own
// delegate subclass.
class ActionMenuDelegate extends WatchUi.Menu2InputDelegate {

    var actions as Dictionary;

    function initialize(a as Dictionary) {
        Menu2InputDelegate.initialize();
        actions = a;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var id = item.getId();
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        if (actions.hasKey(id)) {
            (actions[id] as Lang.Method).invoke();
        }
    }

}
