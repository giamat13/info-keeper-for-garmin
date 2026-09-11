import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;

// Exports the current categories/items as a SEED string and opens the web
// editor (SETUP_URL, see NoDataView.mc) with it pre-filled via a query
// param, so the user can review/copy it from there - the only transport
// available, since there's no phone<->watch messaging channel.
class ExportFlow {

    private var categories as Array<InfoCategory>;

    function initialize(cats as Array<InfoCategory>) {
        categories = cats;
    }

    function start() as Void {
        Confirm.show("Export data to the web editor?", method(:onConfirmed), method(:noop));
    }

    function onConfirmed() as Void {
        var locked = [] as Array<InfoCategory>;
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.requiresPin && cat.sessionKey == null) {
                locked.add(cat);
            }
        }
        if (locked.size() > 0 && PinManager.isSet()) {
            PinEntry.request(method(:onPinEntered));
        } else {
            export();
        }
    }

    function onPinEntered(pin as String) as Void {
        if (!PinManager.verify(pin)) {
            Alert.show("Wrong PIN.", method(:noop));
            return;
        }
        var key = Crypto.deriveKey(pin);
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.requiresPin && cat.sessionKey == null) {
                WatchStore.unlockItems(cat, key);
            }
        }
        export();
    }

    private function export() as Void {
        var seed = InfoSeed.serialize(categories);
        var url = SETUP_URL + "?seed=" + InfoSeed.percentEncode(seed);
        if (Communications has :openWebPage) {
            Communications.openWebPage(url, {}, null);
        }
    }

    function noop() as Void {
    }

}
