import Toybox.WatchUi;
import Toybox.Lang;

// Like ActionMenuDelegate, but for a dynamically-sized result list: each row
// needs to carry back which result it was, which a fixed dictionary of
// zero-arg callbacks (ActionMenuDelegate) can't express without closures.
class SearchResultsDelegate extends WatchUi.Menu2InputDelegate {

    var onPick as Lang.Method; // Lang.Method(idx as Number) -> Void

    function initialize(pick as Lang.Method) {
        Menu2InputDelegate.initialize();
        onPick = pick;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        onPick.invoke(item.getId() as Number);
    }

}
