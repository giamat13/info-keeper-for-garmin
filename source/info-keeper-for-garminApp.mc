import Toybox.Application;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class info_keeper_for_garminApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
        Reminder.rescheduleNext();
    }

    function onStop(state as Dictionary?) as Void {
        Reminder.rescheduleNext();
    }

    // Called when a reminder fires while the app happens to be open (the
    // background wake already vibrated/prompted - see
    // Reminder.fireDueAndReschedule). Nothing to show once the app itself
    // isn't running yet, e.g. right after launch from the wake prompt -
    // getInitialView() below will just show current data as usual.
    function onBackgroundData(data as PropertyValueType) as Void {
        if (data == null) {
            return;
        }
        var fired = data as Dictionary;
        var label = fired["label"] as String;
        var value = fired["value"] as String;
        var text = label.equals("") ? value : (label + ": " + value);
        Alert.show(text, method(:noop));
    }

    function noop() as Void {
    }

    (:background)
    function getServiceDelegate() as [System.ServiceDelegate] {
        return [ new ReminderBackgroundService() ];
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
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
