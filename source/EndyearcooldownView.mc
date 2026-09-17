import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Timer;
import Toybox.WatchUi;

// ---------------------------------------------------------------------------
// End year cooldown widget.
//
// Two independent axes, driven by EndyearcooldownDelegate:
//   - _dateIndex: WHICH date is showing. 0 = the school year; 1..N = one of
//     the user-defined custom dates (the seed's "X=" field), in seed order.
//     One-off custom dates that have already passed are skipped. Changed by
//     scrolling (NEXT/PREV).
//   - _mode: regular countdown (MODE_REGULAR) vs. "net" countdown
//     (MODE_NET) - net subtracts nighttime (the shared awake window, "A=" in
//     the seed) from the plain countdown. Changed by a tap/press (START or a
//     screen tap), not by scrolling.
//
// School's regular mode is the classic days/hours/mins/secs countdown to the
// end of the year, with fireworks and a final 10..1 countdown; its net mode
// is net school hours left today (08:00 -> that day's end time). A custom
// date's regular mode counts down to its configured moment; its net mode
// counts down the same target minus nighttime.
//
// Both school modes draw a ring gauge showing how much of the school year
// has elapsed since September 1st; custom dates draw the ring in their own
// color.
// ---------------------------------------------------------------------------

const MODE_REGULAR = 0;
const MODE_NET = 1;

const SECONDS_PER_DAY = 86400;
const FIREWORKS_DURATION = 60; // seconds of fireworks after school ends

class EndyearcooldownView extends WatchUi.View {

    const TIMER_SLOW = 1000;  // normal refresh
    const TIMER_FAST = 100;   // fireworks / final countdown animation

    var _config as CooldownConfig;
    var _timer as Timer.Timer?;
    var _period as Number = TIMER_SLOW;
    var _wantFast as Boolean = false;
    var _frame as Number = 0;
    var _dateIndex as Number = 0;
    var _mode as Number = MODE_REGULAR;

    // Cache for the net-school-time calculation: the summed school seconds of
    // all enabled days strictly *after* today only changes when the calendar
    // day rolls over, so we recompute it lazily instead of every second.
    var _netDayKey as Number = -1;
    var _netFutureFull as Number = 0;

    // Same idea, per custom date index (key = index into _config.customDates).
    var _customNetDayKey as Dictionary = {};
    var _customNetFuture as Dictionary = {};

    // ── DEBUG TIME OVERRIDE ──────────────────────────────────────────────────
    // Set DEBUG_ENABLED = true to shift the clock to June 30 13:59 (one
    // minute before the default 14:00 end time). The timer still ticks.
    // Set back to false before releasing.
    const DEBUG_ENABLED = false;
    var _debugOffset as Number = 0;
    // ─────────────────────────────────────────────────────────────────────────

    function initialize(config as CooldownConfig) {
        View.initialize();
        _config = config;
        _timer = new Timer.Timer();
        if (DEBUG_ENABLED) {
            var target = momentAt(2026, 6, 30, 13, 59);
            _debugOffset = target.value() - Time.now().value();
        }
    }

    function onLayout(dc as Dc) as Void {
    }

    function onShow() as Void {
        startTimer(TIMER_SLOW);
    }

    function onHide() as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
        }
    }

    function startTimer(period as Number) as Void {
        if (_timer != null) {
            (_timer as Timer.Timer).stop();
            (_timer as Timer.Timer).start(method(:onTick), period, true);
            _period = period;
        }
    }

    function onTick() as Void {
        _frame += 1;
        // Reconcile the timer period decided during the last draw.
        var desired = _wantFast ? TIMER_FAST : TIMER_SLOW;
        if (desired != _period) {
            startTimer(desired);
        }
        WatchUi.requestUpdate();
    }

    // Scroll (NEXT/PREV) handlers called by the input delegate: change WHICH
    // date is showing, keep the current mode. Blocked on the last school day
    // and during summer break.
    function nextDate() as Void {
        if (!isLockedToSingleScreen()) {
            var count = dateCount(nowValue());
            _dateIndex = (_dateIndex + 1) % count;
        }
        WatchUi.requestUpdate();
    }

    function previousDate() as Void {
        if (!isLockedToSingleScreen()) {
            var count = dateCount(nowValue());
            _dateIndex = (_dateIndex + count - 1) % count;
        }
        WatchUi.requestUpdate();
    }

    // Tap/press handler: toggle regular <-> net for the current date, keep
    // the current date.
    function toggleMode() as Void {
        if (!isLockedToSingleScreen()) {
            _mode = (_mode == MODE_REGULAR) ? MODE_NET : MODE_REGULAR;
        }
        WatchUi.requestUpdate();
    }

    // Indices into _config.customDates that are still due to happen (one-off
    // dates that already passed drop out; recurring dates always stay in).
    function activeCustomIndices(now as Number) as Array<Number> {
        var result = [] as Array<Number>;
        for (var i = 0; i < _config.customDates.size(); i++) {
            if (!_config.isCustomDatePast(now, i)) {
                result.add(i);
            }
        }
        return result;
    }

    // 1 (school) + one per still-upcoming custom date.
    function dateCount(now as Number) as Number {
        return 1 + activeCustomIndices(now).size();
    }

    function isLockedToSingleScreen() as Boolean {
        var now = nowValue();
        var schoolEnd = schoolEndMoment(now).value();
        if (now >= schoolEnd) {
            return true;
        }
        // Lock on the last school day: midnight of that day until schoolEnd.
        var endInfo = Gregorian.info(schoolEndMoment(now), Time.FORMAT_SHORT);
        var lastDayMidnight = momentAt(endInfo.year, endInfo.month, endInfo.day, 0, 0).value();
        return now >= lastDayMidnight;
    }

    // -----------------------------------------------------------------------
    // Drawing
    // -----------------------------------------------------------------------

    function onUpdate(dc as Dc) as Void {
        _wantFast = (_config.accentColor == 7);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        var width = dc.getWidth();
        var height = dc.getHeight();
        var now = nowValue();
        var schoolEnd = schoolEndMoment(now).value();
        var yearStart = schoolYearStartMoment(now).value();

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        // During summer: lock to single vacation screen, no switching.
        // drawVacationCountdown draws its own progress ring (summer %).
        if (now >= schoolEnd) {
            var elapsed = now - schoolEnd;
            if (elapsed < FIREWORKS_DURATION) {
                _wantFast = true;
                drawFireworks(dc, width, height);
                drawFireworksOverlay(dc, width, height);
            } else {
                drawVacationCountdown(dc, now);
            }
            return;
        }

        // Ring gauge: fraction of the school year that has elapsed.
        var yearPct = fraction(now - yearStart, schoolEnd - yearStart);

        var actives = activeCustomIndices(now);
        var count = 1 + actives.size();
        if (_dateIndex >= count) {
            _dateIndex = 0; // a one-off custom date dropped out since the last draw
        }

        if (_dateIndex >= 1) {
            var customIdx = actives[_dateIndex - 1];
            var customColor = _config.customDates[customIdx].color;
            _wantFast = _wantFast or (customColor == 7);
            drawProgressRing(dc, yearPct, customAccentColor(customColor));
            if (_mode == MODE_NET) {
                drawCustomNetScreen(dc, now, customIdx);
            } else {
                drawCustomDateScreen(dc, now, customIdx);
            }
        } else if (_mode == MODE_NET) {
            drawProgressRing(dc, yearPct, accentColor());
            drawNetSchoolScreen(dc, now, schoolEnd);
        } else {
            drawProgressRing(dc, yearPct, accentColor());
            drawYearScreen(dc, now, schoolEnd);
        }

        drawScreenHint(dc, yearPct, count);
    }

    // Plain countdown to a user-defined custom date's configured moment.
    // Same visual language as drawYearScreen, parameterized by name/color.
    function drawCustomDateScreen(dc as Dc, now as Number, idx as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cd = _config.customDates[idx];
        var target = _config.customDateMoment(now, idx).value();
        var remaining = target - now;

        if (remaining <= 10 and remaining >= 0) {
            _wantFast = true;
            drawDramaticCountdown(dc, width, height, remaining);
            return;
        }
        if (remaining < 0) {
            remaining = 0;
        }

        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;
        var days = remaining / SECONDS_PER_DAY;
        var rest = remaining % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        dc.setColor(customAccentColor(cd.color), Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, cd.name, width / 2, height * 16 / 100, Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
        } else if (hours > 0) {
            drawCentered(dc, hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "hours left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else if (minutes > 0) {
            drawCentered(dc, minutes.format("%d") + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "minutes left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, seconds.format("%d"), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "seconds left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        }
    }

    // Net (nightless) countdown to a custom date: the plain countdown minus
    // every night's sleep window in between, using the seed's shared awake
    // schedule ("A="). Same idea as drawNetSchoolScreen but for one target
    // moment instead of a sum of remaining school days.
    function drawCustomNetScreen(dc as Dc, now as Number, idx as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cd = _config.customDates[idx];
        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;

        dc.setColor(customAccentColor(cd.color), Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, cd.name + " (net)", width / 2, height * 16 / 100, Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        var target = _config.customDateMoment(now, idx).value();
        if (now >= target) {
            drawCentered(dc, "It's here!", width / 2, height * 48 / 100, Graphics.FONT_MEDIUM);
            return;
        }

        var net = netCustomSecondsRemaining(now, idx, target);
        var days = net / SECONDS_PER_DAY;
        var rest = net % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "awake time left", width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, hms(net), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "awake time left", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        }
    }

    // Sum of awake seconds from `now` until a custom date's target. The
    // future-days portion only changes at midnight, so it is cached per index.
    function netCustomSecondsRemaining(now as Number, idx as Number, target as Number) as Number {
        var todayInfo = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT);
        var todayKey = todayInfo.year * 10000 + todayInfo.month * 100 + todayInfo.day;
        var cachedKey = _customNetDayKey.hasKey(idx) ? _customNetDayKey[idx] : -1;
        if (cachedKey != todayKey) {
            _customNetDayKey[idx] = todayKey;
            _customNetFuture[idx] = _config.awakeSecondsFuture(todayInfo, target);
        }
        return _config.awakeSecondsToday(now, todayInfo, target) + (_customNetFuture[idx] as Number);
    }

    function drawYearScreen(dc as Dc, now as Number, schoolEnd as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var remaining = schoolEnd - now;

        if (remaining <= 10) {
            // Final 10 seconds: dramatic animated countdown.
            _wantFast = true;
            drawDramaticCountdown(dc, width, height, remaining);
            return;
        }

        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;
        var days = remaining / SECONDS_PER_DAY;
        var rest = remaining % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        drawCentered(dc, "School ends in", width / 2, height * 16 / 100, Graphics.FONT_SMALL);

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "summer is close", width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else if (hours > 0) {
            drawCentered(dc, hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "hours left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else if (minutes > 0) {
            drawCentered(dc, minutes.format("%d") + ":" + twoDigits(seconds), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "minutes left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, seconds.format("%d"), width / 2, height * 48 / 100, bodyFont);
            drawCentered(dc, "seconds left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
        }
    }

    // Net learning time left from now until the end of the school year:
    // the sum of every remaining enabled school day's hours (08:00 -> that
    // day's end time). Ticks down second-by-second while school is in session.
    function drawNetSchoolScreen(dc as Dc, now as Number, schoolEnd as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var bodyFont = (width >= 240) ? Graphics.FONT_NUMBER_MEDIUM : Graphics.FONT_NUMBER_MILD;

        drawCentered(dc, "Net school time", width / 2, height * 16 / 100, Graphics.FONT_SMALL);

        if (now >= schoolEnd) {
            drawCentered(dc, "All done!", width / 2, height * 48 / 100, Graphics.FONT_MEDIUM);
            drawCentered(dc, "0 hours left", width / 2, height * 70 / 100, Graphics.FONT_XTINY);
            return;
        }

        var net = netSchoolSecondsRemaining(now, schoolEnd);
        var days = net / SECONDS_PER_DAY;
        var rest = net % SECONDS_PER_DAY;
        var hours = rest / 3600;
        rest = rest % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;

        if (days > 0) {
            drawCentered(dc, days.format("%d") + (days == 1 ? " day" : " days"), width / 2, height * 38 / 100, Graphics.FONT_LARGE);
            drawCentered(dc, twoDigits(hours) + ":" + twoDigits(minutes) + ":" + twoDigits(seconds), width / 2, height * 60 / 100, bodyFont);
            drawCentered(dc, "of learning left", width / 2, height * 80 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, hms(net), width / 2, height * 50 / 100, bodyFont);
            drawCentered(dc, "of learning left", width / 2, height * 72 / 100, Graphics.FONT_XTINY);
        }
    }

    // Sum of remaining school seconds from `now` until the end of the year.
    // The future-days portion only changes at midnight, so it is cached.
    function netSchoolSecondsRemaining(now as Number, schoolEnd as Number) as Number {
        if (now >= schoolEnd) {
            return 0;
        }

        var todayInfo = Gregorian.info(new Time.Moment(nowValue()), Time.FORMAT_SHORT);
        var todayKey = todayInfo.year * 10000 + todayInfo.month * 100 + todayInfo.day;
        if (todayKey != _netDayKey) {
            _netDayKey = todayKey;
            _netFutureFull = sumFutureSchoolSeconds(todayInfo, schoolEnd);
        }

        return netTodaySeconds(now, todayInfo, schoolEnd) + _netFutureFull;
    }

    // School seconds still available *today* from `now` onward.
    function netTodaySeconds(now as Number, todayInfo as Gregorian.Info, schoolEnd as Number) as Number {
        if (!isDayEnabled(todayInfo.day_of_week)) {
            return 0;
        }
        var startVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, _config.schoolStartHour, _config.schoolStartMinute).value();
        var endParts = endTimeForDow(todayInfo.day_of_week);
        var endVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, endParts[0], endParts[1]).value();
        if (endVal > schoolEnd) {
            endVal = schoolEnd;
        }
        var segStart = (now > startVal) ? now : startVal;
        return (endVal > segStart) ? endVal - segStart : 0;
    }

    // Full school seconds (08:00 -> end time) for every enabled day strictly
    // after today, up to and including the last school day.
    function sumFutureSchoolSeconds(todayInfo as Gregorian.Info, schoolEnd as Number) as Number {
        var day = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, 0, 0)
            .add(new Time.Duration(SECONDS_PER_DAY));
        var total = 0;
        var guard = 0;
        while (day.value() < schoolEnd and guard < 400) {
            var di = Gregorian.info(day, Time.FORMAT_SHORT);
            if (isDayEnabled(di.day_of_week)) {
                var startVal = momentAt(di.year, di.month, di.day, _config.schoolStartHour, _config.schoolStartMinute).value();
                var endParts = endTimeForDow(di.day_of_week);
                var endVal = momentAt(di.year, di.month, di.day, endParts[0], endParts[1]).value();
                if (endVal > schoolEnd) {
                    endVal = schoolEnd;
                }
                if (endVal > startVal) {
                    total += endVal - startVal;
                }
            }
            day = day.add(new Time.Duration(SECONDS_PER_DAY));
            guard += 1;
        }
        return total;
    }

    function drawVacationCountdown(dc as Dc, now as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var nextStart = nextYearStartMoment(now);
        var schoolEnd = schoolEndMoment(now).value();
        var remaining = nextStart.value() - now;
        var info = Gregorian.info(nextStart, Time.FORMAT_SHORT);

        var daysLeft = 0;
        if (remaining > 0) {
            daysLeft = (remaining + SECONDS_PER_DAY - 1) / SECONDS_PER_DAY;
        }

        var summerPct = fraction(now - schoolEnd, nextStart.value() - schoolEnd);

        drawProgressRing(dc, summerPct, accentColor());

        dc.setColor(Graphics.COLOR_YELLOW, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, "School is over!", width / 2, height * 16 / 100, Graphics.FONT_SMALL);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);

        if (remaining > 0) {
            drawCentered(dc, daysLeft.format("%d"), width / 2, height * 44 / 100, Graphics.FONT_NUMBER_MEDIUM);
            drawCentered(dc, (daysLeft == 1 ? "day until" : "days until"), width / 2, height * 66 / 100, Graphics.FONT_XTINY);
            drawCentered(dc, dateLabel(info), width / 2, height * 76 / 100, Graphics.FONT_XTINY);
        } else {
            drawCentered(dc, "Welcome back!", width / 2, height * 50 / 100, Graphics.FONT_MEDIUM);
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, (summerPct * 100).format("%d") + "% of summer", width / 2, height * 90 / 100, Graphics.FONT_XTINY);
    }

    // Small label at the bottom: year progress when there's only the school
    // date, or a "2/4" style position indicator once custom dates are in play.
    function drawScreenHint(dc as Dc, yearPct as Float, dateCount as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var text = (dateCount <= 1)
            ? (yearPct * 100).format("%d") + "% of year"
            : (_dateIndex + 1).format("%d") + "/" + dateCount.format("%d");
        drawCentered(dc, text, width / 2, height * 92 / 100, Graphics.FONT_XTINY);
    }

    function nowValue() as Number {
        return Time.now().value() + _debugOffset;
    }

    function drawCentered(dc as Dc, text as String, x as Number, y as Number, font as Graphics.FontType) as Void {
        dc.drawText(x, y, font, text, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Returns the accent color to use for the progress ring.
    function accentColor() as Number {
        return customAccentColor(_config.accentColor);
    }

    // Resolves a color setting (0-7) to a drawable color.
    // color setting: 0=Blue 1=Red 2=Green 3=Yellow 4=Orange 5=Pink 6=Purple 7=Rainbow
    function customAccentColor(setting as Number) as Number {
        var rainbow = [
            Graphics.COLOR_BLUE,
            Graphics.COLOR_RED,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_ORANGE,
            Graphics.COLOR_PINK,
            0x8800FF // purple
        ];
        if (setting == 7) {
            return rainbow[_frame % rainbow.size()];
        }
        if (setting == 6) { return 0x8800FF; }
        if (setting == 5) { return Graphics.COLOR_PINK; }
        if (setting == 4) { return Graphics.COLOR_ORANGE; }
        if (setting == 3) { return Graphics.COLOR_YELLOW; }
        if (setting == 2) { return Graphics.COLOR_GREEN; }
        if (setting == 1) { return Graphics.COLOR_RED; }
        return Graphics.COLOR_BLUE;
    }

    // Ring gauge around the edge showing the elapsed fraction of the year.
    function drawProgressRing(dc as Dc, pct as Float, color as Number) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var cx = width / 2;
        var cy = height / 2;
        var radius = ((width < height ? width : height) / 2) - 5;
        if (radius < 4) {
            return;
        }

        dc.setPenWidth(6);
        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, radius);

        if (pct <= 0.0) {
            dc.setPenWidth(1);
            return;
        }

        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        if (pct >= 0.999) {
            dc.drawCircle(cx, cy, radius);
        } else {
            // Start at the top (90 deg) and sweep clockwise.
            var endDeg = 90.0 - 360.0 * pct;
            while (endDeg < 0.0) {
                endDeg += 360.0;
            }
            dc.drawArc(cx, cy, radius, Graphics.ARC_CLOCKWISE, 90, endDeg.toNumber());
        }
        dc.setPenWidth(1);
    }

    // Deterministic-per-frame fireworks so the picture is stable within a frame
    // but animates across frames.
    function drawFireworks(dc as Dc, width as Number, height as Number) as Void {
        var bursts = 3;
        var cycle = 18; // frames per burst lifetime
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_RED,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_BLUE,
            Graphics.COLOR_PINK,
            Graphics.COLOR_ORANGE
        ];

        for (var i = 0; i < bursts; i += 1) {
            var f = (_frame + i * 6) % cycle;
            if (f >= 13) {
                continue; // gap between bursts
            }
            var era = (_frame + i * 6) / cycle; // which burst we are showing
            var seed = era * 31 + i * 7 + 1;

            var cx = 20 + rnd(seed) % (width > 40 ? width - 40 : 1);
            var cy = 25 + rnd(seed + 1) % (height > 70 ? height - 70 : 1);
            var color = palette[rnd(seed + 2) % palette.size()];
            var radius = 6 + f * 5;

            dc.setColor(color, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(2);
            var rays = 10;
            for (var r = 0; r < rays; r += 1) {
                var ang = (Math.PI * 2.0 * r) / rays;
                var ex = cx + (radius * Math.cos(ang)).toNumber();
                var ey = cy + (radius * Math.sin(ang)).toNumber();
                dc.drawLine(cx, cy, ex, ey);
                dc.fillCircle(ex, ey, 2);
            }
        }
        dc.setPenWidth(1);
    }

    // Dramatic 10..1 animated countdown: pulsing color + radiating spikes.
    function drawDramaticCountdown(dc as Dc, width as Number, height as Number, remaining as Number) as Void {
        var cx = width / 2;
        var cy = height / 2;

        // Cycle colors quickly: yellow → orange → red → pink → repeat.
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_ORANGE,
            Graphics.COLOR_RED,
            Graphics.COLOR_PINK,
            Graphics.COLOR_RED,
            Graphics.COLOR_ORANGE
        ];
        var color = palette[_frame % palette.size()];

        // Radiating spikes that grow outward each sub-frame.
        var spikes = 12;
        var inner = 18;
        var outer = inner + (_frame % 10) * 4;
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        for (var s = 0; s < spikes; s += 1) {
            var ang = (Math.PI * 2.0 * s) / spikes;
            dc.drawLine(
                cx + (inner * Math.cos(ang)).toNumber(),
                cy + (inner * Math.sin(ang)).toNumber(),
                cx + (outer * Math.cos(ang)).toNumber(),
                cy + (outer * Math.sin(ang)).toNumber()
            );
        }
        dc.setPenWidth(1);

        // Big flashing number.
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        var bigFont = Graphics.FONT_NUMBER_HOT;
        drawCentered(dc, remaining.format("%d"), cx, cy, bigFont);

        // Label above and below.
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, "SUMMER IN", cx, height * 18 / 100, Graphics.FONT_SMALL);
        drawCentered(dc, "SECONDS!", cx, height * 84 / 100, Graphics.FONT_SMALL);
    }

    // Text overlay shown on top of fireworks for the 60-second celebration.
    function drawFireworksOverlay(dc as Dc, width as Number, height as Number) as Void {
        var cx = width / 2;
        // Alternate between two celebration lines every ~10 frames.
        var lines = ["SCHOOL IS", "OVER! :D"];
        var palette = [
            Graphics.COLOR_YELLOW,
            Graphics.COLOR_GREEN,
            Graphics.COLOR_PINK,
            Graphics.COLOR_ORANGE
        ];
        dc.setColor(palette[(_frame / 5) % palette.size()], Graphics.COLOR_TRANSPARENT);
        drawCentered(dc, lines[(_frame / 10) % 2], cx, height * 50 / 100, Graphics.FONT_LARGE);
    }

    // -----------------------------------------------------------------------
    // School schedule calculation
    // -----------------------------------------------------------------------

    // Absolute moment when the school year ends, accounting for disabled
    // weekdays, evaluated at that day's configured end time. E/N are stored
    // as month/day only, so CooldownConfig picks whichever calendar year is
    // currently relevant.
    function schoolEndMoment(now as Number) as Time.Moment {
        return _config.schoolEndMoment(now);
    }

    // September 1st of the current school year (08:00), used for the gauge.
    function schoolYearStartMoment(now as Number) as Time.Moment {
        return _config.schoolYearStartMoment(now);
    }

    function nextYearStartMoment(now as Number) as Time.Moment {
        return _config.nextYearStartMoment(now);
    }

    function momentAt(year as Number, month as Number, day as Number, hour as Number, minute as Number) as Time.Moment {
        return _config.momentAt(year, month, day, hour, minute);
    }

    // dow is Gregorian.Info.day_of_week: 1=Sun..7=Sat. CooldownConfig arrays
    // are indexed 0=Sun..6=Sat.
    function endTimeForDow(dow as Number) as Array<Number> {
        if (dow < 1 or dow > 7) {
            dow = 1;
        }
        var idx = dow - 1;
        return [ _config.dayEndHour[idx], _config.dayEndMinute[idx] ];
    }

    function isDayEnabled(dow as Number) as Boolean {
        if (dow < 1 or dow > 7) {
            return false;
        }
        return _config.dayEnabled[dow - 1];
    }

    // -----------------------------------------------------------------------
    // Small helpers
    // -----------------------------------------------------------------------

    // Clamped fraction num/den in [0.0, 1.0].
    function fraction(num as Number, den as Number) as Float {
        if (den <= 0) {
            return (num <= 0) ? 0.0 : 1.0;
        }
        var f = num.toFloat() / den.toFloat();
        if (f < 0.0) {
            return 0.0;
        }
        if (f > 1.0) {
            return 1.0;
        }
        return f;
    }

    // Seconds -> "H:MM:SS".
    function hms(totalSeconds as Number) as String {
        if (totalSeconds < 0) {
            totalSeconds = 0;
        }
        var hours = totalSeconds / 3600;
        var rest = totalSeconds % 3600;
        var minutes = rest / 60;
        var seconds = rest % 60;
        return hours.format("%d") + ":" + twoDigits(minutes) + ":" + twoDigits(seconds);
    }

    function twoDigits(value as Number) as String {
        if (value < 10) {
            return "0" + value.format("%d");
        }
        return value.format("%d");
    }

    function dateLabel(info as Gregorian.Info) as String {
        return twoDigits(info.day) + "/" + twoDigits(info.month) + "/" + info.year.format("%d");
    }

    // Tiny deterministic pseudo-random generator for the fireworks.
    function rnd(seed as Number) as Number {
        var x = (seed * 1103515245 + 12345) & 0x7fffffff;
        return x;
    }
}
