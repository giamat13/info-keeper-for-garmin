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

    // Label may be left blank (e.g. a category that's really just a bag of
    // values) - only a totally empty item (blank label AND blank value) is
    // rejected, in onValueEntered.
    function onLabelEntered(text as String) as Void {
        pendingLabel = text;
        Keyboard.show("", method(:onValueEntered));
    }

    function onValueEntered(text as String) as Void {
        if (pendingLabel.equals("") && text.equals("")) {
            return;
        }
        var item = WatchStore.addItem(category, pendingLabel, text);
        onCreated.invoke(item);
    }

}
