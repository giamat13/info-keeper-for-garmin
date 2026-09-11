import Toybox.WatchUi;
import Toybox.Lang;

// InputDelegate (not BehaviorDelegate) for the same touch+button reason as
// CategoriesDelegate. Invokes the chosen callback BEFORE popping this view,
// not after - because a caller's callback can write data that some other
// view's onShow() reads once revealed (see NoDataView.onShow(), which
// reacts to a category CategoryCreateFlow just created). Popping first would
// let that onShow() run against stale state. This order also happens to
// match every existing caller's expectations: delete-category's onYes does
// its own extra popView() (for leaving ItemsView) which simply stacks on
// top of ours, and delete-item's onYes doesn't touch the stack at all.
class ConfirmViewDelegate extends WatchUi.InputDelegate {

    var view as ConfirmView;
    var onYes as Lang.Method;
    var onNo as Lang.Method?;

    function initialize(v as ConfirmView, yesCb as Lang.Method, noCb as Lang.Method?) {
        InputDelegate.initialize();
        view = v;
        onYes = yesCb;
        onNo = noCb;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        if (view.yesButtonContains(x, y)) {
            onYes.invoke();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            return true;
        }
        if (view.noButtonContains(x, y)) {
            answerNo();
            return true;
        }
        return false;
    }

    // Swipe-right/ESC/hardware Back all answer No, same as declining any
    // other prompt in this app (Keyboard, PinPad, Alert).
    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        if (swipeEvent.getDirection() == WatchUi.SWIPE_RIGHT) {
            answerNo();
            return true;
        }
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        if (keyEvent.getKey() == WatchUi.KEY_ESC) {
            answerNo();
            return true;
        }
        return false;
    }

    private function answerNo() as Void {
        if (onNo != null) {
            (onNo as Lang.Method).invoke();
        }
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }

}
