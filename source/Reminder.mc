import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.Background;
import Toybox.Attention;
import Toybox.Notifications;
import Toybox.Application.Storage;

// Schedules and fires per-item reminders (InfoItem.reminderHour etc).
//
// The background process only gets a small memory pool (64KB on most
// watches) and 30s, so it never touches WatchStore/InfoSeed. Instead the
// foreground (syncFromStore) flattens every reminder into a compact
// "rmList" Storage array, and the background (rescheduleNext /
// fireDueAndReschedule) reads just that.
//
// Only one Background temporal event can be registered at a time (Connect IQ
// restriction), so rescheduleNext() always registers a single wake for
// whichever reminder is soonest.
//
// All times are LOCAL: built from Time.today() (local midnight) plus an
// offset. Gregorian.moment() would treat hour/minute as UTC and fire hours
// off in any non-UTC timezone.
(:background)
class Reminder {

    private static const LIST_KEY = "rmList";

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

    // Local-time Moment for hour:minute, `dayOffset` days from today.
    private static function localMoment(dayOffset as Number, hour as Number, minute as Number) as Time.Moment {
        return Time.today().add(new Time.Duration(dayOffset * 86400 + hour * 3600 + minute * 60));
    }

    // The next Moment (strictly after now) at hour:minute on one of `days`
    // (Time.Gregorian day_of_week values, 1=Sunday..7=Saturday), or any day
    // if `days` is null/empty. Always returns something within a week.
    static function nextTriggerMoment(hour as Number, minute as Number, days as Array<Number>?) as Time.Moment {
        var now = Time.now();
        for (var offset = 0; offset < 8; offset++) {
            var candidate = localMoment(offset, hour, minute);
            var dow = Gregorian.info(localMoment(offset, 12, 0), Time.FORMAT_SHORT).day_of_week;
            if (daysMatch(days, dow) && candidate.greaterThan(now)) {
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

    // True if hour:minute today (on a matching day) is at most 10 minutes
    // ago - the slack a background wake can land after its target (the
    // 5-minute minimum between temporal events can push it later) - and
    // after the previous wake (`last`, epoch secs), so it never fires twice.
    private static function isDueNow(r as Dictionary, now as Time.Moment, last as Number?) as Boolean {
        var dow = Gregorian.info(now, Time.FORMAT_SHORT).day_of_week;
        if (!daysMatch(r["d"] as Array<Number>?, dow)) {
            return false;
        }
        var target = localMoment(0, r["h"] as Number, r["m"] as Number);
        if (now.lessThan(target)) {
            return false;
        }
        if (last != null && target.value() <= last) {
            return false;
        }
        return now.subtract(target).value() <= 600;
    }

    // Foreground only: flattens every reminder (non-PIN categories) into
    // Storage "rmList" and re-registers the next wake. Call after anything
    // that could change reminders, their items' text, or delete them.
    (:typecheck(disableBackgroundCheck))
    static function syncFromStore() as Void {
        if (!isSupported()) {
            return;
        }
        var list = [] as Array<Dictionary>;
        var categories = WatchStore.loadAll();
        for (var c = 0; c < categories.size(); c++) {
            var cat = categories[c];
            if (cat.requiresPin) { continue; }
            for (var i = 0; i < cat.items.size(); i++) {
                var item = cat.items[i];
                if (item.reminderHour == null) { continue; }
                var title = item.label.equals("") ? item.value : item.label;
                var body = item.label.equals("") ? "" : item.value;
                if (title.length() > 60) { title = title.substring(0, 60); }
                if (body.length() > 100) { body = body.substring(0, 100); }
                list.add({
                    "id" => item.id, "h" => item.reminderHour, "m" => item.reminderMinute,
                    "d" => item.reminderDays, "r" => item.reminderRepeat,
                    "v" => item.reminderVibe, "s" => item.reminderSound,
                    "t" => title, "b" => body,
                });
            }
        }
        Storage.setValue(LIST_KEY, list);
        rescheduleNext();
    }

    // Re-registers the single next background wake across "rmList", or
    // clears it if there are none. Cheap - safe in the background.
    static function rescheduleNext() as Void {
        if (!isSupported()) {
            return;
        }
        var list = Storage.getValue(LIST_KEY) as Array<Dictionary>?;
        var soonest = null;
        if (list != null) {
            for (var i = 0; i < list.size(); i++) {
                var r = list[i];
                var next = nextTriggerMoment(r["h"] as Number, r["m"] as Number, r["d"] as Array<Number>?);
                if (soonest == null || next.lessThan(soonest as Time.Moment)) {
                    soonest = next;
                }
            }
        }
        if (soonest == null) {
            Background.deleteTemporalEvent();
            return;
        }
        try {
            Background.registerForTemporalEvent(soonest as Time.Moment);
        } catch (e) {
            // Too soon after the last event (< 5 min) - the system fires it
            // as soon as allowed, or the next rescheduleNext() picks it up.
        }
    }

    // Runs on a background wake: shows a notification (or an app-open
    // prompt on older watches) plus vibration/tone for every reminder due
    // now, drops one-shot ones from "rmList", and re-registers the next
    // wake. Returns the fired one-shot item ids so the foreground can clear
    // them from WatchStore (AppBase.onBackgroundData), or null.
    static function fireDueAndReschedule() as Array<Number>? {
        var list = Storage.getValue(LIST_KEY) as Array<Dictionary>?;
        if (list == null) {
            return null;
        }
        var now = Time.now();
        var last = Storage.getValue("rmLast") as Number?;
        Storage.setValue("rmLast", now.value());
        var keep = [] as Array<Dictionary>;
        var cleared = [] as Array<Number>;
        for (var i = 0; i < list.size(); i++) {
            var r = list[i];
            if (!isDueNow(r, now, last)) {
                keep.add(r);
                continue;
            }
            notify(r);
            if (r["r"] as Boolean) {
                keep.add(r);
            } else {
                cleared.add(r["id"] as Number);
            }
        }
        if (cleared.size() > 0) {
            Storage.setValue(LIST_KEY, keep);
        }
        rescheduleNext();
        return cleared.size() > 0 ? cleared : null;
    }

    private static function notify(r as Dictionary) as Void {
        var title = r["t"] as String;
        var body = r["b"] as String;
        if (Toybox has :Attention) {
            var vibe = vibeProfileFor(r["v"] as Number);
            if (vibe.size() > 0 && (Attention has :vibrate)) {
                Attention.vibrate(vibe);
            }
            if ((r["s"] as Boolean) && (Attention has :playTone)) {
                Attention.playTone(Attention.TONE_ALARM);
            }
        }
        if (Toybox has :Notifications) {
            Notifications.showNotification(title, body, { :body => body });
            return;
        }
        var text = body.equals("") ? title : (title + ": " + body);
        try {
            Background.requestApplicationWake(text);
        } catch (e) {
        }
    }
}
