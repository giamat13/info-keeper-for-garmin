import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class info_keeper_for_garminApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    // Set once getInitialView() runs - onStart/onStop also run in the
    // background process, which must stay light (see Reminder.mc).
    private var inForeground as Boolean = false;

    // Covers every edit made during this session (item text changed,
    // item/category deleted...) in one place.
    function onStop(state as Dictionary?) as Void {
        if (inForeground) {
            Reminder.syncFromStore();
        }
    }

    // Background wake fired one-shot reminders: `data` is their item ids.
    // Clear them from WatchStore so they don't come back on the next sync.
    // Delivered right away if the app is open, else on next launch.
    (:typecheck(disableBackgroundCheck))
    function onBackgroundData(data as PropertyValueType) as Void {
        if (data == null) {
            return;
        }
        var ids = data as Array<Number>;
        var categories = WatchStore.loadAll();
        for (var c = 0; c < categories.size(); c++) {
            var cat = categories[c];
            for (var i = 0; i < cat.items.size(); i++) {
                var item = cat.items[i];
                if (item.fromWatch && item.reminderHour != null && ids.indexOf(item.id) >= 0) {
                    item.reminderHour = null;
                    item.reminderMinute = null;
                    item.reminderDays = null;
                    WatchStore.updateItemReminder(cat, item);
                }
            }
        }
    }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new ReminderBackgroundService() ];
    }

    (:typecheck(disableBackgroundCheck))
    function getInitialView() as [Views] or [Views, InputDelegates] {
        inForeground = true;
        Reminder.syncFromStore();
        // Phone SEED merged with whatever was created directly on the watch
        // (categories and/or items) - see WatchStore.loadAll().
        var categories = WatchStore.loadAll();
        if (categories.size() == 0) {
            var noDataView = new NoDataView();
            return [ noDataView, new NoDataViewDelegate(noDataView) ];
        }
        var view = new CategoriesView(categories);
        return [ view, new CategoriesDelegate(view) ];
    }

}

function getApp() as info_keeper_for_garminApp {
    return Application.getApp() as info_keeper_for_garminApp;
}
