import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// One tappable swatch in the color grid; bounds computed in onLayout.
class ColorSwatch {
    var color as Number;
    var x as Number = 0;
    var y as Number = 0;
    var w as Number = 0;
    var h as Number = 0;

    function initialize(c as Number) {
        color = c;
    }

    function contains(px as Number, py as Number) as Boolean {
        return px >= x && px <= x + w && py >= y && py <= y + h;
    }
}

// Grid picker for a category color: the SDK has no native color picker, so
// this reuses CategoriesView's tap-a-colored-band pattern in a 2-column grid.
class ColorPickerView extends WatchUi.View {

    static const PALETTE = [
        0x38BDF8, 0x22C55E, 0xF97316, 0xEF4444,
        0xA855F7, 0xEAB308, 0xFFFFFF, 0x808080
    ] as Array<Number>;

    private var swatches as Array<ColorSwatch> = [] as Array<ColorSwatch>;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cols = 2;
        var rows = (PALETTE.size() + cols - 1) / cols;
        var cellW = width / cols;
        var cellH = height / rows;

        swatches = [] as Array<ColorSwatch>;
        for (var i = 0; i < PALETTE.size(); i++) {
            var swatch = new ColorSwatch(PALETTE[i]);
            swatch.x = (i % cols) * cellW;
            swatch.y = (i / cols) * cellH;
            swatch.w = cellW;
            swatch.h = cellH;
            swatches.add(swatch);
        }
    }

    function onShow() as Void {
    }

    // Color of the swatch containing (x,y), or null if it misses every swatch.
    function colorAt(x as Number, y as Number) as Number? {
        for (var i = 0; i < swatches.size(); i++) {
            if (swatches[i].contains(x, y)) {
                return swatches[i].color;
            }
        }
        return null;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();
        for (var i = 0; i < swatches.size(); i++) {
            var s = swatches[i];
            dc.setColor(s.color, s.color);
            dc.fillRectangle(s.x, s.y, s.w, s.h);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.drawRectangle(s.x, s.y, s.w, s.h);
        }
    }

    function onHide() as Void {
    }

}
