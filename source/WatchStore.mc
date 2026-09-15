import Toybox.Lang;
import Toybox.Application;
import Toybox.Application.Storage;

// Persists categories/items created directly on the watch, kept separate
// from the phone-provided SEED so a later SEED re-sync never clobbers them.
// Two kinds of watch data are stored:
//  - whole categories created on the watch ("wsCategories")
//  - items added on the watch into a category that came from the SEED
//    ("wsSeedItems", keyed by that category's index within the SEED)
(:background)
class WatchStore {

    static function nextId() as Number {
        var n = Storage.getValue("wsNextId");
        if (n == null) {
            n = 0;
        }
        Storage.setValue("wsNextId", (n as Number) + 1);
        return n as Number;
    }

    // True once at least one category has been created directly on the
    // watch - used by NoDataView to notice (from onShow, once it's actually
    // visible again) that the very first category was just created.
    static function hasWatchCategories() as Boolean {
        var arr = Storage.getValue("wsCategories");
        return arr != null && (arr as Array).size() > 0;
    }

    // Rebuilds the full category list exactly like the app does at launch
    // (phone SEED merged with on-watch data) - shared by
    // info_keeper_for_garminApp.getInitialView() and the DEBUGRESET keyboard
    // shortcut (KeyboardDelegate) so both compute the same thing.
    static function loadAll() as Array<InfoCategory> {
        var seed = Application.Properties.getValue("dataSeed") as String?;
        var seedCategories = [] as Array<InfoCategory>;
        if (seed != null && !seed.equals("")) {
            var parsed = InfoSeed.parse(seed);
            if (parsed != null) {
                seedCategories = parsed;
            }
        }
        return loadMerged(seedCategories);
    }

    // Wipes every bit of on-watch state: watch-created categories/items,
    // the id counter, and the PIN. Does not touch the phone-provided SEED
    // (Application.Properties.dataSeed) - that's the phone's data, not the
    // watch's. Triggered by typing "DEBUGRESET" into any (alphanumeric)
    // keyboard - see KeyboardDelegate.
    static function resetAll() as Void {
        Storage.deleteValue("wsCategories");
        Storage.deleteValue("wsSeedItems");
        Storage.deleteValue("wsNextId");
        Storage.deleteValue("wsFavCategories");
        PinManager.reset();
    }

    // Tags `seedCategories` with their SEED index, attaches any watch-added
    // items to them, and appends any whole categories created on the watch.
    static function loadMerged(seedCategories as Array<InfoCategory>) as Array<InfoCategory> {
        for (var i = 0; i < seedCategories.size(); i++) {
            seedCategories[i].seedIndex = i;
        }

        var seedItems = Storage.getValue("wsSeedItems");
        if (seedItems != null) {
            var dict = seedItems as Dictionary;
            var keys = dict.keys();
            for (var k = 0; k < keys.size(); k++) {
                var idx = keys[k] as Number;
                if (idx >= 0 && idx < seedCategories.size()) {
                    var list = dict[idx] as Array;
                    for (var j = 0; j < list.size(); j++) {
                        seedCategories[idx].items.add(itemFromDict(list[j] as Dictionary));
                    }
                }
            }
        }

        var result = [] as Array<InfoCategory>;
        result.addAll(seedCategories);

        var watchCats = Storage.getValue("wsCategories");
        if (watchCats != null) {
            var arr = watchCats as Array;
            for (var i = 0; i < arr.size(); i++) {
                result.add(categoryFromDict(arr[i] as Dictionary));
            }
        }

        for (var i = 0; i < result.size(); i++) {
            result[i].favorite = isFavorite(result[i]);
        }

        return sortFavoritesFirst(result);
    }

    // Stable partition: favorites first, everyone else after, each group
    // keeping its original relative order. Shared by loadMerged() (initial
    // load) and CategoriesView.resortFavorites() (after a toggle).
    static function sortFavoritesFirst(cats as Array<InfoCategory>) as Array<InfoCategory> {
        var favs = [] as Array<InfoCategory>;
        var rest = [] as Array<InfoCategory>;
        for (var i = 0; i < cats.size(); i++) {
            if (cats[i].favorite) { favs.add(cats[i]); } else { rest.add(cats[i]); }
        }
        var result = [] as Array<InfoCategory>;
        result.addAll(favs);
        result.addAll(rest);
        return result;
    }

    // Identifies `cat` for the favorites set: fromWatch categories by their
    // stable id, seed categories by their index within the SEED (seed
    // categories have no id of their own).
    private static function favKeyFor(cat as InfoCategory) as String {
        return cat.fromWatch ? ("w" + (cat.id as Number).toString()) : ("s" + (cat.seedIndex as Number).toString());
    }

    private static function favContains(favs as Array, key as String) as Boolean {
        for (var i = 0; i < favs.size(); i++) {
            if ((favs[i] as String).equals(key)) { return true; }
        }
        return false;
    }

    static function isFavorite(cat as InfoCategory) as Boolean {
        var favs = Storage.getValue("wsFavCategories");
        return favs != null && favContains(favs as Array, favKeyFor(cat));
    }

    static function toggleFavorite(cat as InfoCategory) as Void {
        var favs = Storage.getValue("wsFavCategories");
        var arr = (favs == null) ? ([] as Array) : (favs as Array);
        var key = favKeyFor(cat);
        if (favContains(arr, key)) {
            for (var i = 0; i < arr.size(); i++) {
                if ((arr[i] as String).equals(key)) { arr.remove(arr[i]); break; }
            }
            cat.favorite = false;
        } else {
            arr.add(key);
            cat.favorite = true;
        }
        Storage.setValue("wsFavCategories", arr);
    }

    private static function itemFromDict(d as Dictionary) as InfoItem {
        var item = new InfoItem(d["label"] as String, d["value"] as String);
        item.fromWatch = true;
        item.id = d["id"] as Number;
        if (d.hasKey("rHour")) {
            item.reminderHour = d["rHour"] as Number;
            item.reminderMinute = d["rMinute"] as Number;
            item.reminderDays = d.hasKey("rDays") ? (d["rDays"] as Array<Number>) : null;
            item.reminderRepeat = d.hasKey("rRepeat") ? (d["rRepeat"] as Boolean) : false;
            item.reminderVibe = d.hasKey("rVibe") ? (d["rVibe"] as Number) : 2;
            item.reminderSound = d.hasKey("rSound") ? (d["rSound"] as Boolean) : true;
        }
        return item;
    }

    // Categories with requiresPin leave `items` empty here - their items
    // stay encrypted at rest until PinEntry.unlockItems() decrypts them
    // (see CategoriesDelegate.onUnlockPinEntered).
    private static function categoryFromDict(d as Dictionary) as InfoCategory {
        var requiresPin = d.hasKey("requiresPin") ? (d["requiresPin"] as Boolean) : false;
        var items = [] as Array<InfoItem>;
        if (!requiresPin) {
            var itemDicts = d["items"] as Array;
            for (var i = 0; i < itemDicts.size(); i++) {
                items.add(itemFromDict(itemDicts[i] as Dictionary));
            }
        }
        var cat = new InfoCategory(d["name"] as String, d["color"] as Number, items);
        cat.fromWatch = true;
        cat.id = d["id"] as Number;
        cat.requiresPin = requiresPin;
        return cat;
    }

    static function addCategory(name as String, color as Number, requiresPin as Boolean) as InfoCategory {
        var id = nextId();
        var list = Storage.getValue("wsCategories");
        var arr = (list == null) ? ([] as Array) : (list as Array);
        arr.add({ "id" => id, "name" => name, "color" => color, "items" => [] as Array, "requiresPin" => requiresPin });
        Storage.setValue("wsCategories", arr);

        var cat = new InfoCategory(name, color, [] as Array<InfoItem>);
        cat.fromWatch = true;
        cat.id = id;
        cat.requiresPin = requiresPin;
        return cat;
    }

    // Combines label+value into one string (packItem) so a PIN-protected
    // item only needs one IV/ciphertext blob instead of two.
    private static function packItem(label as String, value as String) as String {
        return label + "" + value;
    }

    private static function unpackItem(s as String) as Array<String> {
        var sep = s.find("");
        if (sep == null) {
            return [ s, "" ] as Array<String>;
        }
        return [ s.substring(0, sep) as String, s.substring(sep + 1, s.length()) as String ] as Array<String>;
    }

    static function addItem(cat as InfoCategory, label as String, value as String) as InfoItem {
        var id = nextId();

        if (cat.fromWatch) {
            var arr = Storage.getValue("wsCategories") as Array;
            var catDict = findById(arr, cat.id as Number);
            if (catDict != null) {
                var itemDict = {} as Dictionary;
                itemDict["id"] = id;
                if (cat.requiresPin) {
                    itemDict["blob"] = Crypto.encrypt(packItem(label, value), cat.sessionKey as ByteArray);
                } else {
                    itemDict["label"] = label;
                    itemDict["value"] = value;
                }
                (catDict["items"] as Array).add(itemDict);
                Storage.setValue("wsCategories", arr);
            }
        } else {
            var dict = Storage.getValue("wsSeedItems");
            var seedItems = (dict == null) ? ({} as Dictionary) : (dict as Dictionary);
            var idx = cat.seedIndex as Number;
            var list = seedItems.hasKey(idx) ? (seedItems[idx] as Array) : ([] as Array);
            list.add({ "id" => id, "label" => label, "value" => value });
            seedItems[idx] = list;
            Storage.setValue("wsSeedItems", seedItems);
        }

        var item = new InfoItem(label, value);
        item.fromWatch = true;
        item.id = id;
        return item;
    }

    static function updateCategoryName(cat as InfoCategory, name as String) as Void {
        updateCategoryField(cat, "name", name);
    }

    static function updateCategoryColor(cat as InfoCategory, color as Number) as Void {
        updateCategoryField(cat, "color", color);
    }

    private static function updateCategoryField(cat as InfoCategory, key as String, value) as Void {
        if (!cat.fromWatch) {
            return;
        }
        var arr = Storage.getValue("wsCategories") as Array;
        var catDict = findById(arr, cat.id as Number);
        if (catDict != null) {
            catDict[key] = value;
            Storage.setValue("wsCategories", arr);
        }
    }

    static function deleteCategory(cat as InfoCategory) as Void {
        if (!cat.fromWatch) {
            return;
        }
        var arr = Storage.getValue("wsCategories") as Array;
        var target = findById(arr, cat.id as Number);
        if (target != null) {
            arr.remove(target);
            Storage.setValue("wsCategories", arr);
        }
    }

    static function updateItem(cat as InfoCategory, item as InfoItem, label as String?, value as String?) as Void {
        if (!item.fromWatch) {
            return;
        }
        if (cat.fromWatch) {
            var arr = Storage.getValue("wsCategories") as Array;
            var catDict = findById(arr, cat.id as Number);
            if (catDict == null) { return; }
            var list = catDict["items"] as Array;
            var itemDict = findById(list, item.id as Number);
            if (itemDict == null) { return; }
            if (cat.requiresPin) {
                var newLabel = (label != null) ? label : item.label;
                var newValue = (value != null) ? value : item.value;
                itemDict["blob"] = Crypto.encrypt(packItem(newLabel, newValue), cat.sessionKey as ByteArray);
            } else {
                if (label != null) { itemDict["label"] = label; }
                if (value != null) { itemDict["value"] = value; }
            }
            Storage.setValue("wsCategories", arr);
        } else {
            var seedItems = Storage.getValue("wsSeedItems") as Dictionary?;
            if (seedItems == null) { return; }
            var idx = cat.seedIndex as Number;
            if (!seedItems.hasKey(idx)) { return; }
            var list = seedItems[idx] as Array;
            var itemDict = findById(list, item.id as Number);
            if (itemDict == null) { return; }
            if (label != null) { itemDict["label"] = label; }
            if (value != null) { itemDict["value"] = value; }
            Storage.setValue("wsSeedItems", seedItems);
        }
    }

    // Persists item's reminder fields (already updated on the in-memory
    // `item`) back to the item's dict. Only supported for non-requiresPin
    // categories - a PIN-protected item's label/value live encrypted in
    // "blob", which a background wake has no key to read (see
    // ItemsDelegate.openItemMenu, which hides the reminder option there).
    static function updateItemReminder(cat as InfoCategory, item as InfoItem) as Void {
        if (!item.fromWatch || cat.requiresPin) {
            return;
        }
        var itemDict = null;
        var arr = null;
        var seedItems = null;
        if (cat.fromWatch) {
            arr = Storage.getValue("wsCategories") as Array;
            var catDict = findById(arr, cat.id as Number);
            if (catDict == null) { return; }
            itemDict = findById(catDict["items"] as Array, item.id as Number);
        } else {
            seedItems = Storage.getValue("wsSeedItems") as Dictionary?;
            if (seedItems == null) { return; }
            var idx = cat.seedIndex as Number;
            if (!seedItems.hasKey(idx)) { return; }
            itemDict = findById(seedItems[idx] as Array, item.id as Number);
        }
        if (itemDict == null) { return; }

        if (item.reminderHour == null) {
            itemDict.remove("rHour");
            itemDict.remove("rMinute");
            itemDict.remove("rDays");
            itemDict.remove("rRepeat");
            itemDict.remove("rVibe");
            itemDict.remove("rSound");
        } else {
            itemDict["rHour"] = item.reminderHour;
            itemDict["rMinute"] = item.reminderMinute;
            itemDict["rDays"] = item.reminderDays;
            itemDict["rRepeat"] = item.reminderRepeat;
            itemDict["rVibe"] = item.reminderVibe;
            itemDict["rSound"] = item.reminderSound;
        }

        if (cat.fromWatch) {
            Storage.setValue("wsCategories", arr as Array);
        } else {
            Storage.setValue("wsSeedItems", seedItems as Dictionary);
        }
    }

    // Decrypts `cat`'s persisted items under `key` into cat.items, and
    // keeps `key` on the category for the rest of this unlocked session so
    // addItem/updateItem above stay encrypted going back to Storage.
    static function unlockItems(cat as InfoCategory, key as ByteArray) as Void {
        cat.sessionKey = key;
        var arr = Storage.getValue("wsCategories") as Array;
        var catDict = findById(arr, cat.id as Number);
        if (catDict == null) { return; }
        var itemDicts = catDict["items"] as Array;
        var items = [] as Array<InfoItem>;
        for (var i = 0; i < itemDicts.size(); i++) {
            var d = itemDicts[i] as Dictionary;
            var parts = unpackItem(Crypto.decrypt(d["blob"] as ByteArray, key));
            var item = new InfoItem(parts[0] as String, parts[1] as String);
            item.fromWatch = true;
            item.id = d["id"] as Number;
            items.add(item);
        }
        cat.items = items;
    }

    // Re-encrypts every item in `cat` from `oldKey` to `newKey`, operating
    // on Storage directly since the category may not be unlocked in memory
    // right now (used by PinManager.changePin).
    static function reencryptCategory(cat as InfoCategory, oldKey as ByteArray, newKey as ByteArray) as Void {
        var arr = Storage.getValue("wsCategories") as Array;
        var catDict = findById(arr, cat.id as Number);
        if (catDict == null) { return; }
        var itemDicts = catDict["items"] as Array;
        for (var i = 0; i < itemDicts.size(); i++) {
            var d = itemDicts[i] as Dictionary;
            var plain = Crypto.decrypt(d["blob"] as ByteArray, oldKey);
            d["blob"] = Crypto.encrypt(plain, newKey);
        }
        Storage.setValue("wsCategories", arr);
    }

    // Decrypts every item in `cat` back to plaintext storage and clears its
    // PIN requirement (used by PinManager.removePin).
    static function decryptCategoryToPlain(cat as InfoCategory, key as ByteArray) as Void {
        var arr = Storage.getValue("wsCategories") as Array;
        var catDict = findById(arr, cat.id as Number);
        if (catDict == null) { return; }
        catDict["requiresPin"] = false;
        var itemDicts = catDict["items"] as Array;
        for (var i = 0; i < itemDicts.size(); i++) {
            var d = itemDicts[i] as Dictionary;
            var parts = unpackItem(Crypto.decrypt(d["blob"] as ByteArray, key));
            d.remove("blob");
            d["label"] = parts[0];
            d["value"] = parts[1];
        }
        Storage.setValue("wsCategories", arr);
        cat.requiresPin = false;
        cat.sessionKey = null;
    }

    static function deleteItem(cat as InfoCategory, item as InfoItem) as Void {
        if (!item.fromWatch) {
            return;
        }
        if (cat.fromWatch) {
            var arr = Storage.getValue("wsCategories") as Array;
            var catDict = findById(arr, cat.id as Number);
            if (catDict == null) { return; }
            var list = catDict["items"] as Array;
            removeById(list, item.id as Number);
            Storage.setValue("wsCategories", arr);
        } else {
            var seedItems = Storage.getValue("wsSeedItems") as Dictionary?;
            if (seedItems == null) { return; }
            var idx = cat.seedIndex as Number;
            if (!seedItems.hasKey(idx)) { return; }
            var list = seedItems[idx] as Array;
            removeById(list, item.id as Number);
            Storage.setValue("wsSeedItems", seedItems);
        }
    }

    private static function findById(arr as Array, id as Number) as Dictionary? {
        for (var i = 0; i < arr.size(); i++) {
            var d = arr[i] as Dictionary;
            if (d["id"] == id) {
                return d;
            }
        }
        return null;
    }

    private static function removeById(list as Array, id as Number) as Void {
        for (var i = 0; i < list.size(); i++) {
            if ((list[i] as Dictionary)["id"] == id) {
                list.remove(list[i]);
                return;
            }
        }
    }

}
