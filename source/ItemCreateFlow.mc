import Toybox.WatchUi;
import Toybox.Lang;

// Two-step create-item flow (label, then value) for adding a new entry to
// an existing category. Always saved to on-watch storage, even when the
// category itself came from the phone SEED.
class ItemCreateFlow {

    var category as InfoCategory;
    var onCreated as Lang.Method;
    private var pendingLabel as String = "";

    function initialize(cat as InfoCategory, cb as Lang.Method) {
        category = cat;
        onCreated = cb;
    }

    function start() as Void {
        Keyboard.show("", method(:onLabelEntered));
    }

    function onLabelEntered(text as String) as Void {
        if (text.equals("")) {
            return;
        }
        pendingLabel = text;
        Keyboard.show("", method(:onValueEntered));
    }

    function onValueEntered(text as String) as Void {
        var item = WatchStore.addItem(category, pendingLabel, text);
        onCreated.invoke(item);
    }

}
