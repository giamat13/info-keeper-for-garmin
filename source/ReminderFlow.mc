import Toybox.WatchUi;
import Toybox.Lang;

// Add/edit/remove flow for one item's reminder (time, days, repeat,
// vibration, sound). Nothing is persisted until "Save" - see
// InfoItem.reminderHour etc and Reminder.mc for how it's scheduled/fired.
// Reached from ItemsDelegate.openItemMenu, gated by Reminder.isSupported().
class ReminderFlow {

    var category as InfoCategory;
    var item as InfoItem;

    private var draftHour as Number?;
    private var draftMinute as Number?;
    private var draftDays as Array<Number>?;
    private var draftRepeat as Boolean;
    private var draftVibe as Number;
    private var draftSound as Boolean;

    function initialize(cat as InfoCategory, i as InfoItem) {
        category = cat;
        item = i;
        draftHour = item.reminderHour;
        draftMinute = item.reminderMinute;
        draftDays = item.reminderDays;
        draftRepeat = item.reminderRepeat;
        draftVibe = item.reminderVibe;
        draftSound = item.reminderSound;
    }

    function start() as Void {
        showMainMenu();
    }

    private function soundSupported() as Boolean {
        return (Toybox has :Attention) && (Attention has :playTone);
    }

    private function timeLabel() as String {
        if (draftHour == null) {
            return "Time: not set";
        }
        var h = draftHour as Number;
        var m = draftMinute as Number;
        return "Time: " + h.format("%02d") + ":" + m.format("%02d");
    }

    private function daysLabel() as String {
        if (draftDays == null || (draftDays as Array).size() == 0) {
            return "Days: Every day";
        }
        var names = [ "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" ];
        var days = draftDays as Array<Number>;
        var text = "Days: ";
        for (var i = 0; i < days.size(); i++) {
            if (i > 0) { text += ","; }
            text += names[days[i] - 1];
        }
        return text;
    }

    private function vibeLabel() as String {
        var names = [ "Off", "Light", "Medium", "Strong" ];
        return "Vibration: " + names[draftVibe];
    }

    private function showMainMenu() as Void {
        var title = item.label.equals("") ? item.value : item.label;
        var menu = new WatchUi.Menu2({ :title => title });
        menu.addItem(new WatchUi.MenuItem(timeLabel(), null, :time, null));
        menu.addItem(new WatchUi.MenuItem(daysLabel(), null, :days, null));
        menu.addItem(new WatchUi.MenuItem("Repeat: " + (draftRepeat ? "On" : "Off"), null, :repeat, null));
        menu.addItem(new WatchUi.MenuItem(vibeLabel(), null, :vibe, null));
        if (soundSupported()) {
            menu.addItem(new WatchUi.MenuItem("Sound: " + (draftSound ? "On" : "Off"), null, :sound, null));
        }
        menu.addItem(new WatchUi.MenuItem("Save", null, :save, null));
        if (item.reminderHour != null) {
            menu.addItem(new WatchUi.MenuItem("Remove reminder", null, :remove, null));
        }
        var actions = {
            :time => method(:openTimeEntry),
            :days => method(:openDaysMenu),
            :repeat => method(:toggleRepeat),
            :vibe => method(:openVibeMenu),
            :sound => method(:toggleSound),
            :save => method(:save),
            :remove => method(:remove),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    // -- Time --

    function openTimeEntry() as Void {
        var initial = "";
        if (draftHour != null) {
            initial = (draftHour as Number).format("%02d") + (draftMinute as Number).format("%02d");
        }
        TimeEntry.show(initial, method(:onTimeEntered));
    }

    function onTimeEntered(digits as String) as Void {
        if (digits.length() == 3 || digits.length() == 4) {
            var hh = digits.length() == 3 ? digits.substring(0, 1) : digits.substring(0, 2);
            var mm = digits.substring(digits.length() - 2, digits.length());
            var h = (hh as String).toNumber();
            var m = (mm as String).toNumber();
            if (h != null && m != null && h < 24 && m < 60) {
                draftHour = h;
                draftMinute = m;
            }
        }
        showMainMenu();
    }

    // -- Days --

    function openDaysMenu() as Void {
        var names = [ "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" ];
        var menu = new WatchUi.CheckboxMenu({ :title => "Days" });
        var dayItems = [] as Array<WatchUi.CheckboxMenuItem>;
        for (var d = 1; d <= 7; d++) {
            var checked = draftDays != null && arrayContains(draftDays as Array<Number>, d);
            var checkItem = new WatchUi.CheckboxMenuItem(names[d - 1], null, d, checked, null);
            dayItems.add(checkItem);
            menu.addItem(checkItem);
        }
        WatchUi.pushView(menu, new DaysMenuDelegate(dayItems, method(:onDaysChosen)), WatchUi.SLIDE_UP);
    }

    private function arrayContains(arr as Array<Number>, n as Number) as Boolean {
        for (var i = 0; i < arr.size(); i++) {
            if (arr[i] == n) { return true; }
        }
        return false;
    }

    function onDaysChosen(days as Array<Number>) as Void {
        draftDays = days.size() == 0 ? null : days;
        showMainMenu();
    }

    // -- Repeat / Vibration / Sound --

    function toggleRepeat() as Void {
        draftRepeat = !draftRepeat;
        showMainMenu();
    }

    function toggleSound() as Void {
        draftSound = !draftSound;
        showMainMenu();
    }

    function openVibeMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Vibration" });
        menu.addItem(new WatchUi.MenuItem("Off", null, :v0, null));
        menu.addItem(new WatchUi.MenuItem("Light", null, :v1, null));
        menu.addItem(new WatchUi.MenuItem("Medium", null, :v2, null));
        menu.addItem(new WatchUi.MenuItem("Strong", null, :v3, null));
        var actions = {
            :v0 => method(:setVibe0), :v1 => method(:setVibe1),
            :v2 => method(:setVibe2), :v3 => method(:setVibe3),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    function setVibe0() as Void { draftVibe = 0; showMainMenu(); }
    function setVibe1() as Void { draftVibe = 1; showMainMenu(); }
    function setVibe2() as Void { draftVibe = 2; showMainMenu(); }
    function setVibe3() as Void { draftVibe = 3; showMainMenu(); }

    // -- Save / Remove --

    function save() as Void {
        if (draftHour == null) {
            return;
        }
        item.reminderHour = draftHour;
        item.reminderMinute = draftMinute;
        item.reminderDays = draftDays;
        item.reminderRepeat = draftRepeat;
        item.reminderVibe = draftVibe;
        item.reminderSound = draftSound;
        WatchStore.updateItemReminder(category, item);
        Reminder.rescheduleNext();
    }

    function remove() as Void {
        item.reminderHour = null;
        item.reminderMinute = null;
        item.reminderDays = null;
        WatchStore.updateItemReminder(category, item);
        Reminder.rescheduleNext();
    }

}

// CheckboxMenu delegate for the day-of-week picker: taps toggle a checkbox;
// swiping/pressing back (the menu's own Back gesture - same as everywhere
// else in the app) collects the checked days and invokes the callback.
class DaysMenuDelegate extends WatchUi.Menu2InputDelegate {

    var dayItems as Array<WatchUi.CheckboxMenuItem>;
    var onDone as Lang.Method;

    function initialize(items as Array<WatchUi.CheckboxMenuItem>, cb as Lang.Method) {
        Menu2InputDelegate.initialize();
        dayItems = items;
        onDone = cb;
    }

    function onSelect(item as WatchUi.MenuItem) as Void {
        var checkItem = item as WatchUi.CheckboxMenuItem;
        checkItem.setChecked(!checkItem.isChecked());
    }

    function onBack() as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
        var days = [] as Array<Number>;
        for (var i = 0; i < dayItems.size(); i++) {
            if (dayItems[i].isChecked()) {
                days.add(dayItems[i].getId() as Number);
            }
        }
        onDone.invoke(days);
    }

}
