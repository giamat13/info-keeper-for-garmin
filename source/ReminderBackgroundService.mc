import Toybox.Lang;
import Toybox.System;
import Toybox.Background;

// Woken by the single temporal event Reminder.rescheduleNext() keeps
// registered for whichever reminder is soonest.
(:background)
class ReminderBackgroundService extends System.ServiceDelegate {

    function initialize() {
        System.ServiceDelegate.initialize();
    }

    function onTemporalEvent() as Void {
        var fired = Reminder.fireDueAndReschedule();
        Background.exit(fired);
    }

}
