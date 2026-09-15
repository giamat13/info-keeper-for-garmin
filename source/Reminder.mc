import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Background;
import Toybox.Attention;

// Schedules and fires per-item reminders (InfoItem.reminderHour etc).
//
// Only one Background temporal event can be registered at a time (Connect IQ
// restriction), so rescheduleNext() always looks at every reminder across
// every category and (re-)registers a single wake for whichever one is
// soonest. It's called both from the foreground app (after a reminder is
// added/edited/removed, and on launch) and from the background service
// itself after firing, so the "next soonest" wake is always kept current.
(:background)
class Reminder {

    // Gates any UI that offers reminders - see ItemsDelegate.openItemMenu.
    static function isSupported() as Boolean {
        return (Toybox has :Background) && (Background has :registerForTemporalEvent);
    }

    // 0=off, 1=light, 2=medium, 3=strong (see InfoItem.reminderVibe).
    static function vibeProfileFor(level as Number) as Array {
        if (!(Toybox has :Attention) || !(Attention has :VibeProfile)) {
            return [] as Array;
        }
        if (level == 1) { return [ new Attention.VibeProfile(50, 300) ] as Array; }
        if (level == 2) { return [ new Attention.VibeProfile(75, 500) ] as Array; }
        if (level == 3) { return [ new Attention.VibeProfile(100, 1000) ] as Array; }
        return [] as Array;
    }

    // The next Moment (strictly after now) at hour:minute on one of `days`
    // (Time.Gregorian day_of_week values, 1=Sunday..7=Saturday), or any day
    // if `days` is null/empty. Always returns something within a week.
    static function nextTriggerMoment(hour as Number, minute as Number, days as Array<Number>?) as Time.Moment {
        var now = Time.now();
        for (var offset = 0; offset < 8; offset++) {
            var day = now.add(new Time.Duration(offset * 86400));
            var info = Gregorian.info(day, Time.FORMAT_SHORT);
            var candidate = Gregorian.moment({
                :year => info.year, :month => info.month, :day => info.day,
                :hour => hour, :minute => minute, :second => 0,
            });
            if (daysMatch(days, info.day_of_week) && candidate.greaterThan(now)) {
                return candidate;
            }
        }
        return now.add(new Time.Duration(7 * 86400));
    }

    private static function daysMatch(days as Array<Number>?, dayOfWeek as Number) as Boolean {
        if (days == null || days.size() == 0) {
            return true;
        }
        for (var i = 0; i < days.size(); i++) {
            if (days[i] == dayOfWeek) {
                return true;
            }
        }
        return false;
    }

    // True if hour:minute on today's matching day, and it's within the last
    // 5 minutes - the slack a background wake can land after its target.
    private static function isDueNow(item as InfoItem, now as Time.Moment) as Boolean {
        var info = Gregorian.info(now, Time.FORMAT_SHORT);
        if (!daysMatch(item.reminderDays, info.day_of_week)) {
            return false;
        }
        var target = Gregorian.moment({
            :year => info.year, :month => info.month, :day => info.day,
            :hour => item.reminderHour, :minute => item.reminderMinute, :second => 0,
        });
        if (now.lessThan(target)) {
            return false;
        }
        return now.subtract(target).value() <= 300;
    }

    // Re-registers the single next background wake across every reminder in
    // every non-PIN category, or leaves nothing registered if there are
    // none. Safe to call often - it's cheap and idempotent.
    static function rescheduleNext() as Void {
        if (!isSupported()) {
            return;
        }
        var categories = WatchStore.loadAll();
        var soonest = null;
        for (var c = 0; c < categories.size(); c++) {
            var cat = categories[c];
            if (cat.requiresPin) { continue; }
            for (var i = 0; i < cat.items.size(); i++) {
                var item = cat.items[i];
                if (item.reminderHour == null) { continue; }
                var next = nextTriggerMoment(item.reminderHour as Number, item.reminderMinute as Number, item.reminderDays);
                if (soonest == null || next.lessThan(soonest as Time.Moment)) {
                    soonest = next;
                }
            }
        }
        if (soonest != null) {
            try {
                Background.registerForTemporalEvent(soonest as Time.Moment);
            } catch (e instanceof Background.InvalidBackgroundTimeException) {
                // Too soon after the last event (< 5 min) - the next
                // rescheduleNext() call will pick this back up.
            }
        }
    }

    // Runs on a background wake: fires (vibrates + requests an app-open
    // prompt for) every reminder due right now, clears the one-shot ones,
    // and re-registers the next wake. Returns a short summary for
    // AppBase.onBackgroundData() to show if the app happens to be open.
    static function fireDueAndReschedule() as Dictionary? {
        var categories = WatchStore.loadAll();
        var now = Time.now();
        var fired = null;
        for (var c = 0; c < categories.size(); c++) {
            var cat = categories[c];
            if (cat.requiresPin) { continue; }
            for (var i = 0; i < cat.items.size(); i++) {
                var item = cat.items[i];
                if (item.reminderHour == null || !isDueNow(item, now)) { continue; }

                var vibe = vibeProfileFor(item.reminderVibe);
                if (vibe.size() > 0 && (Toybox has :Attention) && (Attention has :vibrate)) {
                    Attention.vibrate(vibe);
                }
                var text = item.label.equals("") ? item.value : (item.label + ": " + item.value);
                if (text.length() > 120) {
                    text = text.substring(0, 120);
                }
                try {
                    Background.requestApplicationWake(text);
                } catch (e instanceof Background.MessageSizeLimitException) {
                }
                if (fired == null) {
                    fired = { "label" => item.label, "value" => item.value };
                }

                if (!item.reminderRepeat) {
                    item.reminderHour = null;
                    item.reminderMinute = null;
                    item.reminderDays = null;
                    WatchStore.updateItemReminder(cat, item);
                }
            }
        }
        rescheduleNext();
        return fired;
    }
}
