import Toybox.WatchUi;
import Toybox.Lang;

// One search result: either a category name match (itemIdx null) or an item
// label match within a category (itemIdx set).
class SearchResult {
    var catIdx as Number;
    var itemIdx as Number?;
    // Index of the query match within the category name (itemIdx null) or
    // within the item's label (itemIdx set) - lets the menu highlight it.
    var matchStart as Number;
    function initialize(c as Number, i as Number?, m as Number) {
        catIdx = c;
        itemIdx = i;
        matchStart = m;
    }
}

// Search flow: optional global PIN unlock (if any category still needs one),
// then a query via the shared Keyboard, then a Menu2 of matches (category
// name or item label containing the query, case-insensitive) that jumps
// straight into the matched category/item - same push CategoriesView.enter()
// does.
class SearchFlow {

    var categoriesView as CategoriesView;
    private var categories as Array<InfoCategory>;
    private var results as Array<SearchResult> = [] as Array<SearchResult>;

    function initialize(view as CategoriesView) {
        categoriesView = view;
        categories = view.categories;
    }

    function start() as Void {
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
            askQuery();
        }
    }

    function onPinEntered(pin as String) as Void {
        if (!PinManager.verify(pin)) {
            return;
        }
        var key = Crypto.deriveKey(pin);
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.requiresPin && cat.sessionKey == null) {
                WatchStore.unlockItems(cat, key);
            }
        }
        askQuery();
    }

    private function askQuery() as Void {
        Keyboard.show("", method(:onQueryEntered));
    }

    function onQueryEntered(query as String) as Void {
        if (query.equals("")) {
            return;
        }
        var q = query.toLower();
        results = [] as Array<SearchResult>;
        for (var ci = 0; ci < categories.size(); ci++) {
            var cat = categories[ci];
            var namePos = cat.name.toLower().find(q);
            if (namePos != null) {
                results.add(new SearchResult(ci, null, namePos as Number));
            }
            for (var ii = 0; ii < cat.items.size(); ii++) {
                var labelPos = cat.items[ii].label.toLower().find(q);
                if (labelPos != null) {
                    results.add(new SearchResult(ci, ii, labelPos as Number));
                }
            }
        }

        if (results.size() == 0) {
            Alert.show("No results.", method(:noop));
            return;
        }

        var qLen = query.length();
        var menu = new WatchUi.Menu2({ :title => "Results" });
        for (var i = 0; i < results.size(); i++) {
            var r = results[i];
            var cat = categories[r.catIdx];
            if (r.itemIdx == null) {
                menu.addItem(new HighlightMenuItem(i, cat.name, r.matchStart, qLen));
            } else {
                var prefix = cat.name + " › ";
                var label = prefix + cat.items[r.itemIdx as Number].label;
                menu.addItem(new HighlightMenuItem(i, label, prefix.length() + r.matchStart, qLen));
            }
        }
        WatchUi.pushView(menu, new SearchResultsDelegate(method(:onResultSelected)), WatchUi.SLIDE_UP);
    }

    function onResultSelected(idx as Number) as Void {
        var r = results[idx];
        if (r.itemIdx != null) {
            categoriesView.cursor = r.catIdx;
        }
        var view = new ItemsView(categories[r.catIdx]);
        if (r.itemIdx != null) {
            view.cursor = r.itemIdx as Number;
        }
        WatchUi.pushView(view, new ItemsDelegate(view, categoriesView), WatchUi.SLIDE_LEFT);
    }

    function noop() as Void {
    }

}
