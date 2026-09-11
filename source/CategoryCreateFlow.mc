import Toybox.WatchUi;
import Toybox.Lang;

// Three-step create-category flow (name, then color, then whether it
// requires a PIN), shared by CategoriesView (adding to an existing list)
// and NoDataView (creating the very first category with no SEED at all).
class CategoryCreateFlow {

    var onCreated as Lang.Method;
    private var pendingName as String = "";
    private var pendingColor as Number = 0;

    function initialize(cb as Lang.Method) {
        onCreated = cb;
    }

    function start() as Void {
        Keyboard.show("", method(:onNameEntered));
    }

    function onNameEntered(text as String) as Void {
        if (text.equals("")) {
            return;
        }
        pendingName = text;
        var cpView = new ColorPickerView();
        WatchUi.pushView(cpView, new ColorPickerDelegate(cpView, method(:onColorChosen)), WatchUi.SLIDE_UP);
    }

    function onColorChosen(color as Number) as Void {
        pendingColor = color;
        Confirm.show("Require PIN to view?", method(:onPinRequired), method(:onPinNotRequired));
    }

    function onPinRequired() as Void {
        finish(true);
    }

    function onPinNotRequired() as Void {
        finish(false);
    }

    private function finish(requiresPin as Boolean) as Void {
        var cat = WatchStore.addCategory(pendingName, pendingColor, requiresPin);
        onCreated.invoke(cat);
    }

}
