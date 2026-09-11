import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;

// Full-screen message with an X button to dismiss - used for warnings the
// user must actively acknowledge (e.g. a PIN-locked category opened with no
// PIN set, or a wrong PIN on change/remove).
class AlertView extends WatchUi.View {

    var message as String;
    private var xX as Number = 0;
    private var xY as Number = 0;
    private var xR as Number = 22;

    function initialize(msg as String) {
        View.initialize();
        message = msg;
    }

    function onLayout(dc as Dc) as Void {
        xX = dc.getWidth() / 2;
        xY = (dc.getHeight() * 0.85).toNumber();
    }

    function onShow() as Void {
    }

    function xButtonContains(x as Number, y as Number) as Boolean {
        var dx = x - xX;
        var dy = y - xY;
        var r = xR + 10;
        return (dx * dx + dy * dy) <= (r * r);
    }

    // Wraps `text` to fit within `maxWidth`, one line per array entry (same as ItemsView.wrapText).
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
        var y = (xY * 0.6) - (totalHeight / 2);

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        for (var i = 0; i < lines.size(); i++) {
            dc.drawText(w / 2, y, font, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            y += lineHeight;
        }

        dc.setColor(Graphics.COLOR_DK_RED, Graphics.COLOR_DK_RED);
        dc.fillCircle(xX, xY, xR);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(xX, xY, Graphics.FONT_MEDIUM, "X", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

}
