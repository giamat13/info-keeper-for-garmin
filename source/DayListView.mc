import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.System;
import Toybox.Math;

// Shows every period of one day (the whole day at once), scrollable, instead
// of the single-slot view TimetableView shows. Reached by pressing select
// from the per-period scroll view; swipe left/right switches day, swipe
// up/down (or the up/down buttons) scroll the list.
class DayListView extends WatchUi.View {

    var timetable as Timetable;
    var dayIdx as Number; // index into timetable.activeDays
    var scrollIndex as Number = 0; // topmost period index currently shown
    var visibleRows as Number = 1;
    var centered as Boolean = false; // whether we've auto-scrolled to "now" yet

    function initialize(t as Timetable, initialDayIdx as Number) {
        View.initialize();
        timetable = t;
        dayIdx = initialDayIdx;
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        scrollIndex = 0;
        centered = false;
    }

    function moveDay(delta as Number) as Void {
        var numDays = timetable.activeDays.size();
        if (numDays == 0) { return; }
        dayIdx = (dayIdx + delta + numDays * 100) % numDays;
        scrollIndex = 0;
        centered = false; // re-center on "now" for the newly selected day
        WatchUi.requestUpdate();
    }

    function scroll(delta as Number) as Void {
        var maxScroll = timetable.periods.size() - visibleRows;
        if (maxScroll < 0) { maxScroll = 0; }
        scrollIndex += delta;
        if (scrollIndex < 0) { scrollIndex = 0; }
        if (scrollIndex > maxScroll) { scrollIndex = maxScroll; }
        WatchUi.requestUpdate();
    }

    // Shrinks/truncates `text` (adding "...") until it fits within maxWidth
    // pixels at the given font. Needed because rows near the top/bottom of a
    // round screen have much less usable width than rows near the center.
    function fitText(dc as Dc, text as String, font as Graphics.FontDefinition, maxWidth as Number) as String {
        if (dc.getTextDimensions(text, font)[0] <= maxWidth) {
            return text;
        }
        var truncated = text;
        while (truncated.length() > 1) {
            truncated = truncated.substring(0, truncated.length() - 1);
            var candidate = truncated + "...";
            if (dc.getTextDimensions(candidate, font)[0] <= maxWidth) {
                return candidate;
            }
        }
        return truncated;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        if (timetable.activeDays.size() == 0 || timetable.periods.size() == 0) { return; }

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cyMid = h / 2;
        var day = timetable.activeDays[dayIdx];

        var isRound = (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND);
        var radius = w / 2.0;
        var edgeMargin = 8; // extra safety buffer inside the true circle, for the bezel

        var headerH = h * 0.16;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, headerH * 0.5, Graphics.FONT_MEDIUM, DAY_NAMES[day], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        var listTop = headerH;
        var listH = h - headerH;
        var rowFont = Graphics.FONT_XTINY;
        var rowH = dc.getFontHeight(rowFont) + 14;
        visibleRows = (listH / rowH).toNumber();
        if (visibleRows < 1) { visibleRows = 1; }

        var todayInfo = Gregorian.info(Time.now(), Time.FORMAT_SHORT);
        var todayDow = todayInfo.day_of_week - 1;
        var isToday = (day == todayDow);
        var nowMinutes = todayInfo.hour * 60 + todayInfo.min;

        if (!centered) {
            var target = 0;
            if (isToday) {
                target = timetable.currentOrNextPeriodIndex(nowMinutes);
                if (target >= timetable.periods.size()) { target = timetable.periods.size() - 1; }
            }
            scrollIndex = target;
            var maxScroll = timetable.periods.size() - visibleRows;
            if (maxScroll < 0) { maxScroll = 0; }
            if (scrollIndex > maxScroll) { scrollIndex = maxScroll; }
            if (scrollIndex < 0) { scrollIndex = 0; }
            centered = true;
        }

        var endIdx = scrollIndex + visibleRows;
        if (endIdx > timetable.periods.size()) { endIdx = timetable.periods.size(); }

        for (var i = scrollIndex; i < endIdx; i++) {
            var period = timetable.periods[i];
            var rowY = listTop + (i - scrollIndex) * rowH;
            var rowCenterY = rowY + rowH / 2;
            var subject = timetable.subjectAt(day, i);
            if (subject.equals("")) {
                subject = period.isBreak ? "Break" : "Free";
            }

            var isCurrent = isToday && nowMinutes >= period.startMinutes && nowMinutes < period.endMinutes;
            if (isCurrent) {
                dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(0, rowY, w, rowH);
            }

            // How much horizontal room is actually safe at this row's height,
            // given the round bezel (full width on a rectangular device).
            var dy = (rowCenterY - cyMid).abs().toFloat();
            var halfWidth = radius;
            if (isRound && dy < radius) {
                halfWidth = Math.sqrt(radius * radius - dy * dy);
            }
            var maxWidth = ((halfWidth - edgeMargin) * 2).toNumber();
            if (maxWidth < 30) { maxWidth = 30; }

            var line = fitText(dc, period.startLabel + "  " + subject, rowFont, maxWidth);

            var subjectColor = period.isBreak ? Graphics.COLOR_ORANGE : Graphics.COLOR_WHITE;
            dc.setColor(subjectColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, rowCenterY, rowFont, line, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
        }

        if (scrollIndex > 0) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, listTop - dc.getFontHeight(Graphics.FONT_XTINY), Graphics.FONT_XTINY, "^", Graphics.TEXT_JUSTIFY_CENTER);
        }
        if (endIdx < timetable.periods.size()) {
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h - dc.getFontHeight(Graphics.FONT_XTINY), Graphics.FONT_XTINY, "v", Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    function onHide() as Void {
    }

}
