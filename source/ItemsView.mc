import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

// Shows one item (label + value) at a time from a category, scrollable.
class ItemsView extends WatchUi.View {

    var category as InfoCategory;
    var cursor as Number = 0;
    private var plusX as Number = 0;
    private var plusY as Number = 0;
    private var plusR as Number = 18;

    function initialize(cat as InfoCategory) {
        View.initialize();
        category = cat;
    }

    function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        // On round watches the raw bottom-left corner (0.14w, 0.88h) falls
        // outside the circular face - inset toward the largest square
        // guaranteed to stay inside the circle (same fix as
        // KeyboardView.computeSafeArea()).
        if (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND) {
            var side = (width < height ? width : height) * 0.72;
            var safeX = (width - side) / 2;
            var safeY = (height - side) / 2;
            plusX = (safeX + side * 0.14).toNumber();
            plusY = (safeY + side * 0.88).toNumber();
        } else {
            plusX = (width * 0.14).toNumber();
            plusY = (height * 0.88).toNumber();
        }
    }

    // True if (x,y) hits the "options" button (bottom-left): add item, and
    // edit/delete the category itself when it was created on the watch.
    function plusButtonContains(x as Number, y as Number) as Boolean {
        var dx = x - plusX;
        var dy = y - plusY;
        var r = plusR + 10;
        return (dx * dx + dy * dy) <= (r * r);
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
        var title = category.favorite ? ("★ " + category.name) : category.name;
        dc.drawText(cx, h * 0.1, Graphics.FONT_SMALL, title, Graphics.TEXT_JUSTIFY_CENTER);

        if (category.items.size() == 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h / 2, Graphics.FONT_SMALL, "No items", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            drawPlusButton(dc);
            return;
        }

        var item = category.items[cursor];
        var hasLabel = !item.label.equals("");

        if (hasLabel) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.32, Graphics.FONT_TINY, item.label, Graphics.TEXT_JUSTIFY_CENTER);
        }

        var lines = wrapText(dc, item.value, Graphics.FONT_MEDIUM, maxWidth);
        var lineHeight = dc.getFontHeight(Graphics.FONT_MEDIUM);
        var totalHeight = lines.size() * lineHeight;
        // With no label line above, center the value in the same vertical
        // band the label+value pair would otherwise occupy.
        var valueCenter = hasLabel ? h * 0.55 : h * 0.46;
        var y = valueCenter - (totalHeight / 2);
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

        if (item.fromWatch) {
            dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "tap to edit", Graphics.TEXT_JUSTIFY_CENTER);
        }

        drawPlusButton(dc);
    }

    private function drawPlusButton(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(plusX, plusY, plusR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(plusX, plusY, Graphics.FONT_MEDIUM, "+", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

}
