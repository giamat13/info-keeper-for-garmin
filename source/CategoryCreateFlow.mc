import Toybox.WatchUi;
import Toybox.Lang;

// Two-step create-category flow (name, then color), shared by CategoriesView
// (adding to an existing list) and NoDataView (creating the very first
// category with no SEED at all).
class CategoryCreateFlow {

    var onCreated as Lang.Method;
    private var pendingName as String = "";

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
        var cat = WatchStore.addCategory(pendingName, color);
        onCreated.invoke(cat);
    }

}
