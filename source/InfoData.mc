import Toybox.Lang;

// One key/value entry inside a category (e.g. "WiFi password" / "hunter2").
class InfoItem {
    var label as String;
    var value as String;
    // True for items created on the watch (editable/deletable there); false
    // for items that came from the phone SEED (read-only on the watch).
    var fromWatch as Boolean;
    var id as Number?; // set when fromWatch; identifies the row in WatchStore

    function initialize(l as String, v as String) {
        label = l;
        value = v;
        fromWatch = false;
        id = null;
    }
}

// A colored group of items (e.g. "Passwords", colored blue).
class InfoCategory {
    var name as String;
    var color as Number; // 0xRRGGBB
    var items as Array<InfoItem>;
    // True for categories created on the watch (editable/deletable there);
    // false for categories that came from the phone SEED.
    var fromWatch as Boolean;
    var id as Number?;        // set when fromWatch; identifies the row in WatchStore
    var seedIndex as Number?; // set when !fromWatch; this category's index within the SEED
    // True for watch-created categories whose items are encrypted at rest
    // and require a correct PIN to view (see PinManager/Crypto). Seed
    // categories never support this - only categories created on the watch.
    var requiresPin as Boolean;
    // AES key for this unlock session, derived from the PIN once verified.
    // Never persisted - cleared again when the items view is left (see
    // ItemsDelegate) so a later visit always needs the PIN again.
    var sessionKey as ByteArray?;
    // Pinned to the top of CategoriesView. Persisted in WatchStore's
    // "wsFavCategories" set (keyed by fromWatch id or seed index) rather than
    // on the category itself, since seed categories can't be written back
    // into the phone-provided SEED - see WatchStore.isFavorite/toggleFavorite.
    var favorite as Boolean;
    // True for a category that holds a school/weekly timetable (ported from
    // the standalone School-timetable app) instead of plain label/value
    // items. When true, `timetableSeed` holds that sub-feature's own SEED
    // string (see Timetable.parseSchedule) and `items` is always empty -
    // CategoriesView.enter() routes to TimetableItemsView instead of
    // ItemsView for these.
    var isTimetable as Boolean;
    var timetableSeed as String?;

    function initialize(n as String, c as Number, i as Array<InfoItem>) {
        name = n;
        color = c;
        items = i;
        fromWatch = false;
        id = null;
        seedIndex = null;
        requiresPin = false;
        sessionKey = null;
        favorite = false;
        isTimetable = false;
        timetableSeed = null;
    }
}

// Parses the SEED string produced by the web editor into categories + items.
//
// Format: 1|C=<hex6>:<encName>,...|I=<catIdx>:<encLabel>~<encValue>,...;<catIdx>:...
// Every free-text field (name/label/value) is percent-encoded so it can safely
// contain any of the format's own delimiter characters (see web/index.html).
//
// A category can instead be a timetable category: <hex6>:<encName>^<encTTSeed>,
// where <encTTSeed> is a whole percent-encoded Timetable seed (Timetable.mc's
// own "2|"/"3|"-prefixed format, ported from the standalone School-timetable
// app). Such categories never appear in the I= section - see CategoriesView.enter().
class InfoSeed {

    // Splits `s` on single-character delimiter `delim` (Monkey C's String has no split()).
    static function splitStr(s as String, delim as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var idx = s.find(delim);
        while (idx != null) {
            result.add(s.substring(start, idx) as String);
            start = idx + delim.length();
            idx = s.substring(start, s.length()).find(delim);
            if (idx != null) { idx += start; }
        }
        result.add(s.substring(start, s.length()) as String);
        return result;
    }

    static function fromBase16(s as String) as Number {
        var digits = "0123456789ABCDEF";
        var value = 0;
        var upper = s.toUpper();
        for (var i = 0; i < upper.length(); i++) {
            var c = upper.substring(i, i + 1);
            var d = digits.find(c);
            if (d == null) { return 0; }
            value = value * 16 + d;
        }
        return value;
    }

    static function toBase16(n as Number) as String {
        var digits = "0123456789ABCDEF";
        var result = "";
        for (var i = 0; i < 6; i++) {
            result = digits.substring(n & 0xF, (n & 0xF) + 1) + result;
            n = n >> 4;
        }
        return result;
    }

    // Percent-encodes every character outside [A-Za-z0-9-_.], the inverse of
    // percentDecode - mirrors web/index.html's encField() exactly (same
    // unreserved set as encodeURIComponent, minus ~ ! * ' ( ), which that JS
    // helper escapes on top of the default) so both sides agree on the format.
    static function percentEncode(s as String) as String {
        var safe = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.";
        var digits = "0123456789ABCDEF";
        var result = "";
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1);
            if (safe.find(c) != null) {
                result += c;
            } else {
                var code = c.toCharArray()[0].toNumber();
                var hi = (code >> 4) & 0xF;
                var lo = code & 0xF;
                result += "%" + digits.substring(hi, hi + 1) + digits.substring(lo, lo + 1);
            }
        }
        return result;
    }

    // Serializes categories back into the SEED format parse() reads - the
    // inverse of parse(), mirroring web/index.html's generateSeed().
    static function serialize(categories as Array<InfoCategory>) as String {
        var cParts = [] as Array<String>;
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            var cPart = InfoSeed.toBase16(cat.color) + ":" + InfoSeed.percentEncode(cat.name);
            if (cat.isTimetable && cat.timetableSeed != null) {
                cPart += "^" + InfoSeed.percentEncode(cat.timetableSeed as String);
            }
            cParts.add(cPart);
        }
        var cStr = "C=" + InfoSeed.joinStr(cParts, ",");

        var iGroups = [] as Array<String>;
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.isTimetable || cat.items.size() == 0) { continue; }
            var pairs = [] as Array<String>;
            for (var j = 0; j < cat.items.size(); j++) {
                var item = cat.items[j];
                pairs.add(InfoSeed.percentEncode(item.label) + "~" + InfoSeed.percentEncode(item.value));
            }
            iGroups.add(i.toString() + ":" + InfoSeed.joinStr(pairs, ","));
        }
        var iStr = "I=" + InfoSeed.joinStr(iGroups, ";");

        return "1|" + cStr + "|" + iStr;
    }

    static function joinStr(parts as Array<String>, delim as String) as String {
        var result = "";
        for (var i = 0; i < parts.size(); i++) {
            if (i > 0) { result += delim; }
            result += parts[i];
        }
        return result;
    }

    // Decodes %XX percent-escapes back into their literal (Latin-1) characters.
    static function percentDecode(s as String) as String {
        var result = "";
        var i = 0;
        var len = s.length();
        while (i < len) {
            var c = s.substring(i, i + 1);
            if (c.equals("%") && i + 3 <= len) {
                var code = InfoSeed.fromBase16(s.substring(i + 1, i + 3) as String);
                result += code.toChar().toString();
                i += 3;
            } else {
                result += c;
                i += 1;
            }
        }
        return result;
    }

    // Returns null if the seed is missing, empty, or malformed.
    static function parse(seed as String) as Array<InfoCategory>? {
        if (seed.length() < 2 || !seed.substring(0, 2).equals("1|")) {
            return null;
        }
        var body = seed.substring(2, seed.length());
        var sections = InfoSeed.splitStr(body, "|");
        var cStr = null;
        var iStr = null;
        for (var i = 0; i < sections.size(); i++) {
            var s = sections[i] as String;
            if (s.find("C=") == 0) { cStr = s.substring(2, s.length()); }
            else if (s.find("I=") == 0) { iStr = s.substring(2, s.length()); }
        }
        if (cStr == null) {
            return null;
        }

        var categories = [] as Array<InfoCategory>;
        if ((cStr as String).length() > 0) {
            var cParts = InfoSeed.splitStr(cStr as String, ",");
            for (var i = 0; i < cParts.size(); i++) {
                var part = cParts[i] as String;
                var colon = part.find(":");
                if (colon == null) { continue; }
                var color = InfoSeed.fromBase16(part.substring(0, colon) as String);
                var rest = part.substring(colon + 1, part.length()) as String;
                var caret = rest.find("^");
                var name = "";
                var cat = null;
                if (caret == null) {
                    name = InfoSeed.percentDecode(rest);
                    cat = new InfoCategory(name, color, [] as Array<InfoItem>);
                } else {
                    name = InfoSeed.percentDecode(rest.substring(0, caret) as String);
                    cat = new InfoCategory(name, color, [] as Array<InfoItem>);
                    cat.isTimetable = true;
                    cat.timetableSeed = InfoSeed.percentDecode(rest.substring(caret + 1, rest.length()) as String);
                }
                categories.add(cat as InfoCategory);
            }
        }
        if (categories.size() == 0) {
            return null;
        }

        if (iStr != null && (iStr as String).length() > 0) {
            var groups = InfoSeed.splitStr(iStr as String, ";");
            for (var g = 0; g < groups.size(); g++) {
                var entry = groups[g] as String;
                var colon = entry.find(":");
                if (colon == null) { continue; }
                var catIdx = (entry.substring(0, colon) as String).toNumber();
                if (catIdx == null || catIdx < 0 || catIdx >= categories.size()) { continue; }
                var rest = entry.substring(colon + 1, entry.length()) as String;
                if (rest.length() == 0) { continue; }
                var pairs = InfoSeed.splitStr(rest, ",");
                for (var p = 0; p < pairs.size(); p++) {
                    var pair = pairs[p] as String;
                    var tilde = pair.find("~");
                    if (tilde == null) { continue; }
                    var label = InfoSeed.percentDecode(pair.substring(0, tilde) as String);
                    var value = InfoSeed.percentDecode(pair.substring(tilde + 1, pair.length()) as String);
                    categories[catIdx].items.add(new InfoItem(label, value));
                }
            }
        }

        return categories;
    }

}
