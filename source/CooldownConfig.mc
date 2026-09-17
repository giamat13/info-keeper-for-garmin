import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

// One user-defined extra countdown target (the "X=" seed field), in addition
// to the school year. `hasYear` false means it recurs every year like E/N;
// true means it's a one-off date that drops out of rotation once it passes.
class CustomDate {
    var name as String;
    var month as Number;
    var day as Number;
    var hasYear as Boolean;
    var year as Number;
    var endHour as Number;
    var endMinute as Number;
    var color as Number;

    function initialize(
        n as String,
        m as Number,
        d as Number,
        hy as Boolean,
        y as Number,
        eh as Number,
        em as Number,
        c as Number
    ) {
        name = n;
        month = m;
        day = d;
        hasYear = hy;
        year = y;
        endHour = eh;
        endMinute = em;
        color = c;
    }
}

// Parsed configuration decoded from the "cooldownSeed" web-UI seed string.
// All widget behavior comes from this object - there are no other settings.
//
// The school-end and next-year-start dates are stored as month/day only (no
// year), so the same seed works forever: schoolEndMoment()/nextYearStartMoment()
// pick whichever calendar year is currently relevant.
class CooldownConfig {
    var endMonth as Number;
    var endDay as Number;
    var nextStartMonth as Number;
    var nextStartDay as Number;
    var accentColor as Number;
    var schoolStartHour as Number;
    var schoolStartMinute as Number;

    // Index 0=Sun..6=Sat.
    var dayEnabled as Array<Boolean>;
    var dayEndHour as Array<Number>;
    var dayEndMinute as Array<Number>;

    var customDates as Array<CustomDate>;

    // Daily "awake window" (wake time -> bedtime), one pair per weekday
    // (index 0=Sun..6=Sat), used to compute custom dates' net (nightless)
    // countdown - see awakeSecondsToday()/awakeSecondsFuture().
    var awakeStartHour as Array<Number>;
    var awakeStartMinute as Array<Number>;
    var awakeEndHour as Array<Number>;
    var awakeEndMinute as Array<Number>;

    // Monkey C caps constructors at 9 parameters, so the awake window's
    // start/end minutes are packed into one 14-element array: indices 0-6 are
    // wake minutes (Sun..Sat), 7-13 are bedtime minutes (Sun..Sat).
    function initialize(
        dateParts as Array<Number>,
        accent as Number,
        startHour as Number,
        startMinute as Number,
        enabled as Array<Boolean>,
        endHour as Array<Number>,
        endMinute as Array<Number>,
        customs as Array<CustomDate>,
        awakeMinutes as Array<Number>
    ) {
        endMonth = dateParts[0];
        endDay = dateParts[1];
        nextStartMonth = dateParts[2];
        nextStartDay = dateParts[3];
        accentColor = accent;
        schoolStartHour = startHour;
        schoolStartMinute = startMinute;
        dayEnabled = enabled;
        dayEndHour = endHour;
        dayEndMinute = endMinute;
        customDates = customs;
        awakeStartHour = [] as Array<Number>;
        awakeStartMinute = [] as Array<Number>;
        awakeEndHour = [] as Array<Number>;
        awakeEndMinute = [] as Array<Number>;
        for (var i = 0; i < 7; i++) {
            awakeStartHour.add(awakeMinutes[i] / 60);
            awakeStartMinute.add(awakeMinutes[i] % 60);
            awakeEndHour.add(awakeMinutes[i + 7] / 60);
            awakeEndMinute.add(awakeMinutes[i + 7] % 60);
        }
    }

    // Splits `s` on single-character delimiter `delim` (Monkey C's String has no split()).
    static function splitStr(s as String, delim as String) as Array<String> {
        var result = [] as Array<String>;
        var start = 0;
        var idx = s.find(delim);
        while (idx != null) {
            result.add(s.substring(start, idx) as String);
            start = idx + delim.length();
            idx = s.substring(start, s.length()).find(delim);
            if (idx != null) { idx += start; }
        }
        result.add(s.substring(start, s.length()) as String);
        return result;
    }

    // Decodes a base36 string (0-9, a-z) into a Number.
    static function fromBase36(s as String) as Number {
        var digits = "0123456789abcdefghijklmnopqrstuvwxyz";
        var value = 0;
        for (var i = 0; i < s.length(); i++) {
            var c = s.substring(i, i + 1);
            var d = digits.find(c);
            if (d == null) { return 0; }
            value = value * 36 + d;
        }
        return value;
    }

    // Seed format (produced by web/index.html):
    // 2|E=<b36 month*100+day>|N=<b36 month*100+day>|W=<decimal bitmask, bit0=Sun..bit6=Sat>|T=<b36 endMinutes Sun,Mon,...,Sat>|C=<decimal 0-7>|S=<b36 startMinutes>
    // Version 3 additionally allows a trailing X=<entry>~<entry>~... field for
    // user-defined custom countdown dates, entry = <b36 monthday>^<hasYear 0|1>^<b36 year>^<b36 endMinutes>^<color>^<name>
    // ...and an A=<b36 wake0>-<b36 sleep0>,<b36 wake1>-<b36 sleep1>,...,<Sat> field:
    // one wake/bedtime pair per weekday (Sun..Sat), used to compute custom
    // dates' net (nightless) countdown. Defaults to 08:00-22:00 every day
    // when absent.
    static function parse(seed as String) as CooldownConfig? {
        if (seed.length() < 2 or (!seed.substring(0, 2).equals("2|") and !seed.substring(0, 2).equals("3|"))) {
            return null;
        }
        var sections = CooldownConfig.splitStr(seed.substring(2, seed.length()), "|");
        var eStr = null;
        var nStr = null;
        var wStr = null;
        var tStr = null;
        var cStr = null;
        var sStr = null;
        var xStr = null;
        var aStr = null;
        for (var i = 0; i < sections.size(); i++) {
            var s = sections[i] as String;
            if (s.find("E=") == 0) { eStr = s.substring(2, s.length()); }
            else if (s.find("N=") == 0) { nStr = s.substring(2, s.length()); }
            else if (s.find("W=") == 0) { wStr = s.substring(2, s.length()); }
            else if (s.find("T=") == 0) { tStr = s.substring(2, s.length()); }
            else if (s.find("C=") == 0) { cStr = s.substring(2, s.length()); }
            else if (s.find("S=") == 0) { sStr = s.substring(2, s.length()); }
            else if (s.find("X=") == 0) { xStr = s.substring(2, s.length()); }
            else if (s.find("A=") == 0) { aStr = s.substring(2, s.length()); }
        }
        if (eStr == null or nStr == null or wStr == null or tStr == null or cStr == null or sStr == null) {
            return null;
        }

        var tParts = CooldownConfig.splitStr(tStr as String, ",");
        if (tParts.size() != 7) {
            return null;
        }

        var days = (wStr as String).toNumber();
        var accent = (cStr as String).toNumber();
        if (days == null or accent == null) {
            return null;
        }

        var enabled = [] as Array<Boolean>;
        var endHour = [] as Array<Number>;
        var endMinute = [] as Array<Number>;
        for (var i = 0; i < 7; i++) {
            enabled.add(((days >> i) & 1) == 1);
            var minutes = CooldownConfig.fromBase36(tParts[i] as String);
            endHour.add(minutes / 60);
            endMinute.add(minutes % 60);
        }

        var startMinutes = CooldownConfig.fromBase36(sStr as String);
        var eVal = CooldownConfig.fromBase36(eStr as String);
        var nVal = CooldownConfig.fromBase36(nStr as String);

        var customs = [] as Array<CustomDate>;
        if (xStr != null and (xStr as String).length() > 0) {
            var entries = CooldownConfig.splitStr(xStr as String, "~");
            for (var i = 0; i < entries.size(); i++) {
                var custom = CooldownConfig.parseCustomDate(entries[i] as String);
                if (custom != null) {
                    customs.add(custom as CustomDate);
                }
            }
        }

        // Default awake window (08:00-22:00 every day) when the seed has no A=
        // field. Indices 0-6 are wake minutes (Sun..Sat), 7-13 are bedtime
        // minutes (Sun..Sat) - see initialize()'s packing comment.
        var awakeMinutes = [480, 480, 480, 480, 480, 480, 480, 1320, 1320, 1320, 1320, 1320, 1320, 1320] as Array<Number>;
        if (aStr != null and (aStr as String).length() > 0) {
            var awakeDays = CooldownConfig.splitStr(aStr as String, ",");
            if (awakeDays.size() == 7) {
                for (var i = 0; i < 7; i++) {
                    var pair = CooldownConfig.splitStr(awakeDays[i] as String, "-");
                    if (pair.size() == 2) {
                        awakeMinutes[i] = CooldownConfig.fromBase36(pair[0] as String);
                        awakeMinutes[i + 7] = CooldownConfig.fromBase36(pair[1] as String);
                    }
                }
            }
        }

        return new CooldownConfig(
            [ eVal / 100, eVal % 100, nVal / 100, nVal % 100 ] as Array<Number>,
            accent,
            startMinutes / 60,
            startMinutes % 60,
            enabled,
            endHour,
            endMinute,
            customs,
            awakeMinutes
        );
    }

    // entry = <b36 monthday>^<hasYear 0|1>^<b36 year>^<b36 endMinutes>^<color>^<name>
    static function parseCustomDate(entry as String) as CustomDate? {
        var parts = CooldownConfig.splitStr(entry, "^");
        if (parts.size() != 6) {
            return null;
        }
        var code = CooldownConfig.fromBase36(parts[0] as String);
        var hasYear = (parts[1] as String).equals("1");
        var year = CooldownConfig.fromBase36(parts[2] as String);
        var endMinutes = CooldownConfig.fromBase36(parts[3] as String);
        var color = (parts[4] as String).toNumber();
        var name = parts[5] as String;
        if (color == null) {
            return null;
        }
        return new CustomDate(name, code / 100, code % 100, hasYear, year, endMinutes / 60, endMinutes % 60, color);
    }

    // Corrects for the Garmin SDK quirk where Gregorian.moment() interprets
    // its fields as UTC rather than local time.
    function momentAt(year as Number, month as Number, day as Number, hour as Number, minute as Number) as Time.Moment {
        var offset = System.getClockTime().timeZoneOffset;
        return Gregorian.moment({
            :year => year,
            :month => month,
            :day => day,
            :hour => hour,
            :minute => minute,
            :second => 0
        }).subtract(new Time.Duration(offset));
    }

    // The calendar year whose E/N dates apply to `now`. E and N always fall
    // in the same calendar year (e.g. school ends June 2026, next year starts
    // September 2026); once this year's N has passed, the next cycle's E and
    // N are both in the following calendar year.
    function cycleYear(now as Number) as Number {
        var thisYear = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT).year;
        var nMoment = momentAt(thisYear, nextStartMonth, nextStartDay, schoolStartHour, schoolStartMinute).value();
        return (now > nMoment) ? thisYear + 1 : thisYear;
    }

    // Absolute moment when the school year ends, accounting for disabled
    // weekdays, evaluated at that day's configured end time.
    function schoolEndMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        var day = momentAt(year, endMonth, endDay, 0, 0);

        // Walk back to the last enabled school day (guarded against no days on).
        var guard = 0;
        while (guard < 14 and !dayEnabled[Gregorian.info(day, Time.FORMAT_SHORT).day_of_week - 1]) {
            day = day.subtract(new Time.Duration(86400));
            guard += 1;
        }

        var info = Gregorian.info(day, Time.FORMAT_SHORT);
        var idx = info.day_of_week - 1;
        return momentAt(info.year, info.month, info.day, dayEndHour[idx], dayEndMinute[idx]);
    }

    function nextYearStartMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        return momentAt(year, nextStartMonth, nextStartDay, schoolStartHour, schoolStartMinute);
    }

    // September 1st of the current school year (08:00), used for the gauge.
    function schoolYearStartMoment(now as Number) as Time.Moment {
        var year = cycleYear(now);
        var startYear = (endMonth >= 9) ? year : year - 1;
        return momentAt(startYear, 9, 1, schoolStartHour, schoolStartMinute);
    }

    // Target moment for custom date `idx`. One-off dates use their stored
    // year; recurring dates roll forward to next year once they've passed,
    // same idea as cycleYear() for E/N.
    function customDateMoment(now as Number, idx as Number) as Time.Moment {
        var cd = customDates[idx];
        var year = cd.hasYear ? cd.year : cycleCustomYear(now, cd);
        return momentAt(year, cd.month, cd.day, cd.endHour, cd.endMinute);
    }

    function cycleCustomYear(now as Number, cd as CustomDate) as Number {
        var thisYear = Gregorian.info(new Time.Moment(now), Time.FORMAT_SHORT).year;
        var m = momentAt(thisYear, cd.month, cd.day, cd.endHour, cd.endMinute).value();
        return (now > m) ? thisYear + 1 : thisYear;
    }

    // True once a one-off custom date's moment is in the past (recurring
    // dates never go stale - they just roll to next year).
    function isCustomDatePast(now as Number, idx as Number) as Boolean {
        var cd = customDates[idx];
        if (!cd.hasYear) {
            return false;
        }
        return now > momentAt(cd.year, cd.month, cd.day, cd.endHour, cd.endMinute).value();
    }

    // dow is Gregorian.Info.day_of_week: 1=Sun..7=Sat. Awake arrays are
    // indexed 0=Sun..6=Sat.
    function awakeIndexForDow(dow as Number) as Number {
        if (dow < 1 or dow > 7) {
            return 0;
        }
        return dow - 1;
    }

    // Awake-only seconds remaining *today* (from `now` or the day's awake
    // start, whichever is later, up to the day's awake end or `target`).
    // Every day counts - there's no day-of-week filtering for custom dates,
    // just the nightly gap subtracted out.
    function awakeSecondsToday(now as Number, todayInfo as Gregorian.Info, target as Number) as Number {
        var idx = awakeIndexForDow(todayInfo.day_of_week);
        var startVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, awakeStartHour[idx], awakeStartMinute[idx]).value();
        var endVal = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, awakeEndHour[idx], awakeEndMinute[idx]).value();
        if (endVal > target) { endVal = target; }
        var segStart = (now > startVal) ? now : startVal;
        return (endVal > segStart) ? endVal - segStart : 0;
    }

    // Awake-only seconds for every day strictly after `todayInfo`, up to `target`.
    function awakeSecondsFuture(todayInfo as Gregorian.Info, target as Number) as Number {
        var day = momentAt(todayInfo.year, todayInfo.month, todayInfo.day, 0, 0).add(new Time.Duration(86400));
        var total = 0;
        var guard = 0;
        while (day.value() < target and guard < 3650) {
            var di = Gregorian.info(day, Time.FORMAT_SHORT);
            var idx = awakeIndexForDow(di.day_of_week);
            var dayStart = momentAt(di.year, di.month, di.day, awakeStartHour[idx], awakeStartMinute[idx]).value();
            var dayEnd = momentAt(di.year, di.month, di.day, awakeEndHour[idx], awakeEndMinute[idx]).value();
            if (dayEnd > target) { dayEnd = target; }
            if (dayEnd > dayStart) { total += dayEnd - dayStart; }
            day = day.add(new Time.Duration(86400));
            guard += 1;
        }
        return total;
    }
}
