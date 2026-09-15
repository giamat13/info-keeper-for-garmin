import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;

// One tappable key on the numeric pad; bounds computed in onLayout, same
// pattern as KeyButton/CategoryBand/ColorSwatch.
class PinKey {
    var label as String;
    var action as String; // "digit:<d>" | "del" | "ok"
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

// Full-screen numeric keypad for PIN entry (digits only, masked display) -
// used instead of the full alphanumeric Keyboard when the set PIN is known
// to be digits-only (see PinEntry).
class PinPadView extends WatchUi.View {

    var entered as String = "";
    // Masked "* * *" display for PIN entry (PinEntry.request). TimeEntry.show
    // sets this false to show the typed digits themselves, and maxLen to 4.
    var masked as Boolean = true;
    var maxLen as Number = 12;
    private var keys as Array<PinKey> = [] as Array<PinKey>;
    private var headerH as Number = 0;
    private var safeX as Number = 0;
    private var safeY as Number = 0;
    private var safeW as Number = 0;
    private var safeH as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        var isRound = System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND;
        layoutForSize(dc.getWidth(), dc.getHeight(), isRound);
    }

    // Split out from onLayout() so layout math can be unit-tested with plain numbers.
    function layoutForSize(width as Number, height as Number, isRound as Boolean) as Void {
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
        headerH = (safeH * 0.22).toNumber();
        layoutKeys();
    }

    private function layoutKeys() as Void {
        var defs = [
            new PinKey("1", "digit:1"), new PinKey("2", "digit:2"), new PinKey("3", "digit:3"),
            new PinKey("4", "digit:4"), new PinKey("5", "digit:5"), new PinKey("6", "digit:6"),
            new PinKey("7", "digit:7"), new PinKey("8", "digit:8"), new PinKey("9", "digit:9"),
            new PinKey("DEL", "del"), new PinKey("0", "digit:0"), new PinKey("OK", "ok"),
        ] as Array<PinKey>;

        var cols = 3;
        var rows = 4;
        var gridTop = safeY + headerH;
        var gridH = safeH - headerH;
        var cellW = safeW / cols;
        var cellH = gridH / rows;

        keys = [] as Array<PinKey>;
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

    function keyAt(x as Number, y as Number) as PinKey? {
        for (var i = 0; i < keys.size(); i++) {
            if (keys[i].contains(x, y)) {
                return keys[i];
            }
        }
        return null;
    }

    function insertDigit(d as String) as Void {
        if (entered.length() < maxLen) {
            entered += d;
        }
    }

    function backspace() as Void {
        if (entered.length() > 0) {
            entered = entered.substring(0, entered.length() - 1) as String;
        }
    }

    private function keyColor(action as String) as Number {
        if (action.equals("ok")) {
            return Graphics.COLOR_DK_GREEN;
        } else if (action.equals("del")) {
            return Graphics.COLOR_DK_RED;
        }
        return Graphics.COLOR_DK_GRAY;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_DK_GRAY);
        dc.fillRectangle(safeX, safeY, safeW, headerH);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var display = "";
        if (masked) {
            for (var i = 0; i < entered.length(); i++) {
                display += "* ";
            }
        } else {
            display = entered;
        }
        dc.drawText(safeX + safeW / 2, safeY + headerH / 2, Graphics.FONT_MEDIUM, display, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        for (var i = 0; i < keys.size(); i++) {
            var b = keys[i];
            var fill = keyColor(b.action);
            dc.setColor(fill, fill);
            dc.fillRoundedRectangle(b.x + 2, b.y + 2, b.w - 4, b.h - 4, 4);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var font = b.label.length() > 1 ? Graphics.FONT_XTINY : Graphics.FONT_MEDIUM;
            dc.drawText(b.x + b.w / 2, b.y + b.h / 2, font, b.label, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }
    }

    function onHide() as Void {
    }

}
