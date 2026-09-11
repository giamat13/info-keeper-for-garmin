import Toybox.Lang;
import Toybox.Application.Storage;

// Persists categories/items created directly on the watch, kept separate
// from the phone-provided SEED so a later SEED re-sync never clobbers them.
// Two kinds of watch data are stored:
//  - whole categories created on the watch ("wsCategories")
//  - items added on the watch into a category that came from the SEED
//    ("wsSeedItems", keyed by that category's index within the SEED)
class WatchStore {

    static function nextId() as Number {
        var n = Storage.getValue("wsNextId");
        if (n == null) {
            n = 0;
        }
        Storage.setValue("wsNextId", (n as Number) + 1);
        return n as Number;
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

        return result;
    }

    private static function itemFromDict(d as Dictionary) as InfoItem {
        var item = new InfoItem(d["label"] as String, d["value"] as String);
        item.fromWatch = true;
        item.id = d["id"] as Number;
        return item;
    }

    private static function categoryFromDict(d as Dictionary) as InfoCategory {
        var items = [] as Array<InfoItem>;
        var itemDicts = d["items"] as Array;
        for (var i = 0; i < itemDicts.size(); i++) {
            items.add(itemFromDict(itemDicts[i] as Dictionary));
        }
        var cat = new InfoCategory(d["name"] as String, d["color"] as Number, items);
        cat.fromWatch = true;
        cat.id = d["id"] as Number;
        return cat;
    }

    static function addCategory(name as String, color as Number) as InfoCategory {
        var id = nextId();
        var list = Storage.getValue("wsCategories");
        var arr = (list == null) ? ([] as Array) : (list as Array);
        arr.add({ "id" => id, "name" => name, "color" => color, "items" => [] as Array });
        Storage.setValue("wsCategories", arr);

        var cat = new InfoCategory(name, color, [] as Array<InfoItem>);
        cat.fromWatch = true;
        cat.id = id;
        return cat;
    }

    static function addItem(cat as InfoCategory, label as String, value as String) as InfoItem {
        var id = nextId();
        var itemDict = { "id" => id, "label" => label, "value" => value };

        if (cat.fromWatch) {
            var arr = Storage.getValue("wsCategories") as Array;
            var catDict = findById(arr, cat.id as Number);
            if (catDict != null) {
                (catDict["items"] as Array).add(itemDict);
                Storage.setValue("wsCategories", arr);
            }
        } else {
            var dict = Storage.getValue("wsSeedItems");
            var seedItems = (dict == null) ? ({} as Dictionary) : (dict as Dictionary);
            var idx = cat.seedIndex as Number;
            var list = seedItems.hasKey(idx) ? (seedItems[idx] as Array) : ([] as Array);
            list.add(itemDict);
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
            if (label != null) { itemDict["label"] = label; }
            if (value != null) { itemDict["value"] = value; }
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
