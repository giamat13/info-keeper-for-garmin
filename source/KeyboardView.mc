import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

// One tappable key; bounds are computed in onLayout, same pattern as
// CategoryBand/ColorSwatch.
class KeyButton {
    var label as String;
    var action as String; // "char:<c>" | "space" | "del" | "page" | "ok"
    var x as Number = 0;
    var y as Number = 0;
    var w as Number = 0;
    var h as Number = 0;

    function initialize(l as String, a as String) {
        label = l;
        action = a;
    }

    function contains(px as Number, py as Number) as Boolean {
        return px >= x && px <= x + w && py >= y && py <= y + h;
    }
}

// Full-screen, touch-only on-watch keyboard (no native TextPicker wheel):
// page 0 is letters, page 1 is digits/symbols, "123"/"ABC" switches between
// them - mirrors calc-for-garmin's full-screen button-grid keypad.
class KeyboardView extends WatchUi.View {

    static const LETTERS = "ABCDEFGHIJKLMNOPQRSTUVWXYZ";
    static const DIGITS = "0123456789";
    static const SYMBOLS = "!@#$%^&*()-_=+.,";

    var text as String;
    var page as Number = 0;
    private var keys as Array<KeyButton> = [] as Array<KeyButton>;
    private var headerH as Number = 0;

    // Safe content area: on round watches a full-width row near the top/bottom
    // edge gets chopped off by the bezel, so the key grid is confined to the
    // largest square guaranteed to stay inside the circle (same fix as
    // calc-for-garmin's computeSafeArea()) - otherwise the corner keys of a
    // 6-wide grid land under the curved edge and are unreachable/invisible.
    private var safeX as Number = 0;
    private var safeY as Number = 0;
    private var safeW as Number = 0;
    private var safeH as Number = 0;

    function initialize(initialText as String) {
        View.initialize();
        text = initialText;
    }

    function onLayout(dc as Dc) as Void {
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        layoutForSize(dc.getWidth(), dc.getHeight(), isRound);
    }

    // Split out from onLayout() so layout math can be unit-tested with plain numbers.
    function layoutForSize(width as Number, height as Number, isRound as Boolean) as Void {
        computeSafeArea(width, height, isRound);
        headerH = (safeH * 0.22).toNumber();
        layoutKeys();
    }

    private function computeSafeArea(width as Number, height as Number, isRound as Boolean) as Void {
        if (isRound) {
            var side = (width < height ? width : height) * 0.72;
            safeW = side.toNumber();
            safeH = safeW;
            safeX = (width - safeW) / 2;
            safeY = (height - safeH) / 2;
        } else {
            safeX = 0;
            safeY = 0;
            safeW = width;
            safeH = height;
        }
    }

    private function contentChars() as String {
        return page == 0 ? LETTERS : (DIGITS + SYMBOLS);
    }

    private function layoutKeys() as Void {
        var chars = contentChars();
        var cols = 6;
        var totalCells = chars.length() + 4; // + SPACE, DEL, page-switch, OK
        var rows = (totalCells + cols - 1) / cols;

        var defs = [] as Array<KeyButton>;
        for (var i = 0; i < chars.length(); i++) {
            var c = chars.substring(i, i + 1) as String;
            defs.add(new KeyButton(c, "char:" + c));
        }
        defs.add(new KeyButton("SP", "space"));
        defs.add(new KeyButton("DEL", "del"));
        defs.add(new KeyButton(page == 0 ? "123" : "ABC", "page"));
        defs.add(new KeyButton("OK", "ok"));

        var gridTop = safeY + headerH;
        var gridH = safeH - headerH;
        var cellW = safeW / cols;
        var cellH = gridH / rows;

        keys = [] as Array<KeyButton>;
        for (var i = 0; i < defs.size(); i++) {
            var row = i / cols;
            var col = i % cols;
            var b = defs[i];
            b.x = safeX + col * cellW;
            b.y = gridTop + row * cellH;
            b.w = cellW;
            b.h = cellH;
            keys.add(b);
        }
    }

    function onShow() as Void {
    }

    function keyAt(x as Number, y as Number) as KeyButton? {
        for (var i = 0; i < keys.size(); i++) {
            if (keys[i].contains(x, y)) {
                return keys[i];
            }
        }
        return null;
    }

    function togglePage() as Void {
        page = page == 0 ? 1 : 0;
        layoutKeys();
    }

    function insertChar(c as String) as Void {
        text += c;
    }

    function backspace() as Void {
        if (text.length() > 0) {
            text = text.substring(0, text.length() - 1) as String;
        }
    }

    private function keyColor(action as String) as Number {
        if (action.equals("ok")) {
            return Graphics.COLOR_DK_GREEN;
        } else if (action.equals("del")) {
            return Graphics.COLOR_DK_RED;
        } else if (action.equals("page") || action.equals("space")) {
            return Graphics.COLOR_BLUE;
        }
        return Graphics.COLOR_DK_GRAY;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(safeX, safeY, safeW, headerH);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var shown = text.length() > 18 ? text.substring(text.length() - 18, text.length()) as String : text;
        dc.drawText(safeX + safeW / 2, safeY + headerH / 2, Graphics.FONT_SMALL, shown, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < keys.size(); i++) {
            var b = keys[i];
            var fill = keyColor(b.action);
            dc.setColor(fill, fill);
            dc.fillRoundedRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4, 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var font = b.label.length() > 1 ? Graphics.FONT_XTINY : Graphics.FONT_SMALL;
            dc.drawText(b.x + b.w / 2, b.y + b.h / 2, font, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function onHide() as Void {
    }

}
