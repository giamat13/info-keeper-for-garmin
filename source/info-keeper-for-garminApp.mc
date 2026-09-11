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
        var seedCategories = [] as Array<InfoCategory>;
        if (seed != null && !seed.equals("")) {
            var parsed = InfoSeed.parse(seed);
            if (parsed != null) {
                seedCategories = parsed;
            }
        }

        // Merge in whatever was created directly on the watch (categories
        // and/or items), in addition to whatever the phone SEED provided.
        var categories = WatchStore.loadMerged(seedCategories);
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
