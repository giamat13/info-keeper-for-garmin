import Toybox.WatchUi;
import Toybox.Lang;

// Generic WatchUi.Confirmation delegate: invokes `onYes` only when the user
// confirms, so delete flows don't each need a bespoke delegate.
class ConfirmDelegate extends WatchUi.ConfirmationDelegate {

    var onYes as Lang.Method;

    function initialize(cb as Lang.Method) {
        ConfirmationDelegate.initialize();
        onYes = cb;
    }

    function onResponse(response as WatchUi.Confirm) as Boolean {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        if (response == WatchUi.CONFIRM_YES) {
            onYes.invoke();
        }
        return true;
    }

}
