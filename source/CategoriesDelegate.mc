import Toybox.WatchUi;
import Toybox.Lang;

// Extends the low-level WatchUi.InputDelegate rather than BehaviorDelegate.
// On several touch+button devices, BehaviorDelegate silently converts any
// screen touch into a generic "select" behavior (activating whatever band is
// currently highlighted, ignoring where you actually tapped) before onTap
// ever runs - that made direct taps on a category open the highlighted one
// instead of the one under your finger. InputDelegate skips that
// translation, so onTap's own coordinate hit-test decides which category
// gets entered. Physical buttons are handled directly via onKey() instead
// of BehaviorDelegate's onSelect/onNextPage/onPreviousPage.
class CategoriesDelegate extends WatchUi.InputDelegate {

    var view as CategoriesView;
    // Index of the category currently being unlocked/entered, and (for the
    // change-PIN flow) the old PIN already verified while waiting for the
    // new one - both are short-lived state for a single in-flight prompt.
    private var pendingIdx as Number = 0;
    private var pendingOldPin as String = "";

    function initialize(v as CategoriesView) {
        InputDelegate.initialize();
        view = v;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    // Some devices report a quick press as a hold rather than a tap; handle
    // both the same way so a tap always registers.
    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        if (view.plusButtonContains(x, y)) {
            new CategoryCreateFlow(method(:onCategoryCreated)).start();
            return true;
        }
        if (view.pinButtonContains(x, y)) {
            openPinMenu();
            return true;
        }
        var idx = view.categoryAt(x, y);
        if (idx == null) {
            return false;
        }
        enterCategory(idx as Number);
        return true;
    }

    function onCategoryCreated(cat as InfoCategory) as Void {
        view.addCategory(cat);
    }

    // -- Entering a category: PIN-gated when it requires one --

    private function enterCategory(idx as Number) as Void {
        var cat = view.categories[idx];
        if (!cat.requiresPin) {
            view.enter(idx);
            return;
        }
        pendingIdx = idx;
        if (!PinManager.isSet()) {
            Alert.show("This category requires a PIN, but none is set. Use the PIN button to set one.", method(:onNoPinAlertDismissed));
            return;
        }
        PinEntry.request(method(:onUnlockPinEntered));
    }

    function onNoPinAlertDismissed() as Void {
        view.enter(pendingIdx);
    }

    function onUnlockPinEntered(pin as String) as Void {
        if (!PinManager.verify(pin)) {
            return;
        }
        var cat = view.categories[pendingIdx];
        WatchStore.unlockItems(cat, Crypto.deriveKey(pin));
        view.enter(pendingIdx);
    }

    // -- PIN settings menu (set the first PIN, or change/remove it) --

    private function openPinMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Options" });
        menu.addItem(new WatchUi.MenuItem("Search", null, :search, null));
        menu.addItem(new WatchUi.MenuItem("Export data", null, :export, null));
        if (PinManager.isSet()) {
            menu.addItem(new WatchUi.MenuItem("Change PIN", null, :change, null));
            menu.addItem(new WatchUi.MenuItem("Remove PIN", null, :remove, null));
        } else {
            menu.addItem(new WatchUi.MenuItem("Set PIN", null, :set, null));
        }
        var actions = {
            :search => method(:startSearch),
            :export => method(:startExport),
            :set => method(:startSetPin),
            :change => method(:startChangePin),
            :remove => method(:startRemovePin),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    function startSearch() as Void {
        new SearchFlow(view).start();
    }

    function startExport() as Void {
        new ExportFlow(view.categories).start();
    }

    function startSetPin() as Void {
        Keyboard.show("", method(:onSetPinEntered));
    }

    function onSetPinEntered(pin as String) as Void {
        if (pin.equals("")) {
            return;
        }
        PinManager.setPin(pin);
    }

    function startChangePin() as Void {
        PinEntry.request(method(:onChangeOldPinEntered));
    }

    function onChangeOldPinEntered(oldPin as String) as Void {
        if (!PinManager.verify(oldPin)) {
            Alert.show("Wrong PIN.", method(:noop));
            return;
        }
        pendingOldPin = oldPin;
        Keyboard.show("", method(:onChangeNewPinEntered));
    }

    function onChangeNewPinEntered(newPin as String) as Void {
        if (newPin.equals("")) {
            return;
        }
        PinManager.changePin(pendingOldPin, newPin, view.categories);
    }

    function startRemovePin() as Void {
        PinEntry.request(method(:onRemovePinEntered));
    }

    function onRemovePinEntered(pin as String) as Void {
        if (!PinManager.verify(pin)) {
            Alert.show("Wrong PIN.", method(:noop));
            return;
        }
        PinManager.removePin(pin, view.categories);
    }

    function noop() as Void {
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            view.enter(view.cursor);
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        }
        return false;
    }

}
