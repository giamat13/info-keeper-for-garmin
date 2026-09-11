import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Full-screen Yes/No question: a red X (bottom-left, "No") and a green
// checkmark (bottom-right, "Yes"), mirroring the layout language already
// used by CategoriesView/ItemsView's bottom-corner buttons.
class ConfirmView extends WatchUi.View {

    var message as String;
    private var noX as Number = 0;
    private var noY as Number = 0;
    private var yesX as Number = 0;
    private var yesY as Number = 0;
    private var btnR as Number = 22;

    function initialize(msg as String) {
        View.initialize();
        message = msg;
    }

    function onLayout(dc as Dc) as Void {
        var w = dc.getWidth();
        var h = dc.getHeight();
        noX = (w * 0.14).toNumber();
        noY = (h * 0.88).toNumber();
        yesX = (w * 0.86).toNumber();
        yesY = (h * 0.88).toNumber();
    }

    function onShow() as Void {
    }

    function noButtonContains(x as Number, y as Number) as Boolean {
        var dx = x - noX;
        var dy = y - noY;
        var r = btnR + 10;
        return (dx * dx + dy * dy) <= (r * r);
    }

    function yesButtonContains(x as Number, y as Number) as Boolean {
        var dx = x - yesX;
        var dy = y - yesY;
        var r = btnR + 10;
        return (dx * dx + dy * dy) <= (r * r);
    }

    // Wraps `text` to fit within `maxWidth`, one line per array entry (same as ItemsView.wrapText/AlertView.wrapText).
    private function wrapText(dc as Dc, text as String, font as Graphics.FontType, maxWidth as Number) as Array<String> {
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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var maxWidth = (w * 0.8).toNumber();
        var font = Graphics.FONT_SMALL;
        var lines = wrapText(dc, message, font, maxWidth);
        var lineHeight = dc.getFontHeight(font);
        var totalHeight = lines.size() * lineHeight;
        var y = (dc.getHeight() * 0.42) - (totalHeight / 2);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(w / 2, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight;
        }

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_DK_RED);
        dc.fillCircle(noX, noY, btnR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(noX, noY, Graphics.FONT_MEDIUM, "X", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        dc.setColor(Graphics.COLOR_DK_GREEN, Graphics.COLOR_DK_GREEN);
        dc.fillCircle(yesX, yesY, btnR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(yesX, yesY, Graphics.FONT_MEDIUM, "V", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

}
