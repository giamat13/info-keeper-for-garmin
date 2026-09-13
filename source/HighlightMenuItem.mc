import Toybox.WatchUi;
import Toybox.Graphics;
import Toybox.Lang;

// A Menu2 row that draws its label with one substring (the search match)
// picked out in a different color, since Menu2's stock MenuItem only
// supports a single plain-text label with no inline styling.
class HighlightMenuItem extends WatchUi.CustomMenuItem {

    private var before as String;
    private var match as String;
    private var after as String;

    // matchStart/matchLen: the [start, start+len) range of `label` to highlight.
    function initialize(id, label as String, matchStart as Number, matchLen as Number) {
        CustomMenuItem.initialize(id, {});
        before = label.substring(0, matchStart) as String;
        match = label.substring(matchStart, matchStart + matchLen) as String;
        after = label.substring(matchStart + matchLen, label.length()) as String;
    }

    // ponytail: long labels aren't truncated/wrapped like the stock
    // MenuItem's - fine for this app's short category/item names, revisit
    // with ellipsis clipping if labels start overflowing the row.
    function draw(dc as Dc) as Void {
        var font = Graphics.FONT_SMALL;
        var y = dc.getHeight() / 2;
        var x = 10;

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, before, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(before, font);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, match, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
        x += dc.getTextWidthInPixels(match, font);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, font, after, Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER);
    }

}
