import Toybox.Application;
import Toybox.Lang;
import Toybox.WatchUi;

class info_keeper_for_garminApp extends Application.AppBase {

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state as Dictionary?) as Void {
    }

    function onStop(state as Dictionary?) as Void {
    }

    function getInitialView() as [Views] or [Views, InputDelegates] {
        var seed = Application.Properties.getValue("dataSeed") as String?;
        if (seed == null || seed.equals("")) {
            return [ new NoDataView() ];
        }
        var categories = InfoSeed.parse(seed);
        if (categories == null || categories.size() == 0) {
            return [ new NoDataView() ];
        }
        var view = new CategoriesView(categories);
        return [ view, new CategoriesDelegate(view) ];
    }

}

function getApp() as info_keeper_for_garminApp {
    return Application.getApp() as info_keeper_for_garminApp;
}
