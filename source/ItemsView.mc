import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Shows one item (label + value) at a time from a category, scrollable.
class ItemsView extends WatchUi.View {

    var category as InfoCategory;
    var cursor as Number = 0;

    function initialize(cat as InfoCategory) {
        View.initialize();
        category = cat;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function move(delta as Number) as Void {
        var n = category.items.size();
        if (n == 0) { return; }
        cursor = (cursor + delta + n) % n;
        WatchUi.requestUpdate();
    }

    // Wraps `text` to fit within `maxWidth`, returning one line per array entry.
    function wrapText(dc as Dc, text as String, font as Graphics.FontType, maxWidth as Number) as Array<String> {
        var lines = [] as Array<String>;
        var words = InfoSeed.splitStr(text, " ");
        var line = "";
        for (var i = 0; i < words.size(); i++) {
            var word = words[i] as String;
            var candidate = line.length() == 0 ? word : (line + " " + word);
            if (dc.getTextWidthInPixels(candidate, font) <= maxWidth || line.length() == 0) {
                line = candidate;
            } else {
                lines.add(line);
                line = word;
            }
        }
        if (line.length() > 0) {
            lines.add(line);
        }
        return lines;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var maxWidth = (w * 0.82).toNumber();

        dc.setColor(category.color, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.1, Graphics.FONT_SMALL, category.name, Graphics.TEXT_JUSTIFY_CENTER);

        if (category.items.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, "No items", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var item = category.items[cursor];

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.32, Graphics.FONT_TINY, item.label, Graphics.TEXT_JUSTIFY_CENTER);

        var lines = wrapText(dc, item.value, Graphics.FONT_MEDIUM, maxWidth);
        var lineHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var totalHeight = lines.size() * lineHeight;
        var y = (h * 0.55) - (totalHeight / 2);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(cx, y, Graphics.FONT_MEDIUM, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight;
        }

        if (category.items.size() > 1) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            var label = (cursor + 1).toString() + "/" + category.items.size().toString();
            dc.drawText(cx, h * 0.92, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }

}
