import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Shows up to 3 categories per page, stacked in equal horizontal bands.
// More than 3 categories spill onto additional pages, reached by moving
// the cursor past the first/last slot on the current page.
class CategoriesView extends WatchUi.View {

    var categories as Array<InfoCategory>;
    var cursor as Number = 0;

    function initialize(cats as Array<InfoCategory>) {
        View.initialize();
        categories = cats;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
    }

    function move(delta as Number) as Void {
        var n = categories.size();
        if (n == 0) { return; }
        cursor = (cursor + delta + n) % n;
        WatchUi.requestUpdate();
    }

    // Returns the category index for a tap at screen y, or null if the tap
    // landed past the last real slot on the current page.
    function slotAt(y as Number, h as Number) as Number? {
        var page = cursor / 3;
        var slot = (y * 3) / h;
        if (slot < 0) { slot = 0; }
        if (slot > 2) { slot = 2; }
        var idx = page * 3 + slot;
        if (idx >= categories.size()) { return null; }
        return idx;
    }

    function enter(idx as Number) as Void {
        cursor = idx;
        var cat = categories[idx];
        var view = new ItemsView(cat);
        WatchUi.pushView(view, new ItemsDelegate(view), WatchUi.SLIDE_LEFT);
    }

    // Best-guess text color for readable contrast against `bg` (0xRRGGBB).
    function contrastColor(bg as Number) as Number {
        var r = (bg >> 16) & 0xFF;
        var g = (bg >> 8) & 0xFF;
        var b = bg & 0xFF;
        var luma = (r * 299 + g * 587 + b * 114) / 1000;
        return luma > 140 ? Graphics.COLOR_BLACK : Graphics.COLOR_WHITE;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var bandH = h / 3;

        var page = cursor / 3;
        var start = page * 3;

        for (var slot = 0; slot < 3; slot++) {
            var idx = start + slot;
            if (idx >= categories.size()) { break; }
            var cat = categories[idx];
            var y0 = slot * bandH;
            var bandHeight = (slot == 2) ? (h - y0) : bandH;

            dc.setColor(cat.color, cat.color);
            dc.fillRectangle(0, y0, w, bandHeight);

            if (idx == cursor) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(3);
                dc.drawRectangle(2, y0 + 2, w - 4, bandHeight - 4);
                dc.setPenWidth(1);
            }

            dc.setColor(contrastColor(cat.color), Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, y0 + bandHeight / 2, Graphics.FONT_MEDIUM, cat.name, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        var numPages = (categories.size() + 2) / 3;
        if (numPages > 1) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var label = (page + 1).toString() + "/" + numPages.toString();
            dc.drawText(w / 2, 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }

}
