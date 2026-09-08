import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// One tappable on-screen band; bounds are computed in onLayout so hit-testing
// (in the delegate's onTap) never has to recompute screen geometry itself.
class CategoryBand {
    var categoryIndex as Number;
    var x as Number = 0;
    var y as Number = 0;
    var w as Number = 0;
    var h as Number = 0;

    function initialize(idx as Number) {
        categoryIndex = idx;
    }

    function contains(px as Number, py as Number) as Boolean {
        return px >= x && px <= x + w && py >= y && py <= y + h;
    }
}

// Shows up to 3 categories per page, stacked in equal horizontal bands.
// More than 3 categories spill onto additional pages, reached by moving
// the cursor past the first/last slot on the current page.
class CategoriesView extends WatchUi.View {

    var categories as Array<InfoCategory>;
    var cursor as Number = 0;
    private var bands as Array<CategoryBand> = [] as Array<CategoryBand>;
    private var screenW as Number = 0;
    private var screenH as Number = 0;

    function initialize(cats as Array<InfoCategory>) {
        View.initialize();
        categories = cats;
    }

    function onLayout(dc as Dc) as Void {
        layoutForSize(dc.getWidth(), dc.getHeight());
    }

    // Split out from onLayout() so layout math can be unit-tested with plain numbers.
    function layoutForSize(width as Number, height as Number) as Void {
        screenW = width;
        screenH = height;
        var bandH = height / 3;
        var page = cursor / 3;
        var start = page * 3;

        bands = [] as Array<CategoryBand>;
        for (var slot = 0; slot < 3; slot++) {
            var idx = start + slot;
            if (idx >= categories.size()) { break; }
            var band = new CategoryBand(idx);
            band.x = 0;
            band.y = slot * bandH;
            band.w = width;
            band.h = (slot == 2) ? (height - band.y) : bandH;
            bands.add(band);
        }
    }

    function onShow() as Void {
    }

    function getBands() as Array<CategoryBand> {
        return bands;
    }

    // Index of the category whose band contains (x,y), or null if it misses every band.
    function categoryAt(x as Number, y as Number) as Number? {
        for (var i = 0; i < bands.size(); i++) {
            if (bands[i].contains(x, y)) {
                return bands[i].categoryIndex;
            }
        }
        return null;
    }

    function move(delta as Number) as Void {
        var n = categories.size();
        if (n == 0) { return; }
        cursor = (cursor + delta + n) % n;
        layoutForSize(screenW, screenH);
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

        for (var i = 0; i < bands.size(); i++) {
            var band = bands[i];
            var cat = categories[band.categoryIndex];

            dc.setColor(cat.color, cat.color);
            dc.fillRectangle(band.x, band.y, band.w, band.h);

            var isSelected = band.categoryIndex == cursor;
            if (isSelected) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.setPenWidth(4);
                dc.drawRectangle(band.x + 2, band.y + 2, band.w - 4, band.h - 4);
                dc.setPenWidth(1);
            }

            dc.setColor(contrastColor(cat.color), Graphics.COLOR_TRANSPARENT);
            var font = isSelected ? Graphics.FONT_LARGE : Graphics.FONT_MEDIUM;
            dc.drawText(band.x + band.w / 2, band.y + band.h / 2, font, cat.name, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

            if (isSelected) {
                dc.drawText(band.x + 14, band.y + band.h / 2, font, ">", Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
            }
        }

        var numPages = (categories.size() + 2) / 3;
        if (numPages > 1) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var page = cursor / 3;
            var label = (page + 1).toString() + "/" + numPages.toString();
            dc.drawText(w / 2, 2, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }

}
