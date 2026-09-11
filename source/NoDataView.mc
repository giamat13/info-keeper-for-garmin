import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Communications;
import Toybox.Application;

const SETUP_URL = "https://giamat13.github.io/info-keeper-for-garmin";

// Shown when no SEED has been configured yet: a QR code to the web editor,
// and a best-effort attempt to open it directly on a paired phone.
class NoDataView extends WatchUi.View {

    private var createY as Number = 0;

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        createY = (dc.getHeight() * 0.94).toNumber();
    }

    // Also fires when this view is revealed again after the "Require PIN?"
    // question (pushed directly on top of this, the app's only view at
    // first-time setup) is answered and popped - by which point the new
    // category is already persisted (see CategoryCreateFlow / Confirm.show),
    // so switching to CategoriesView here, rather than synchronously from
    // the confirm callback, can't race that pop.
    function onShow() as Void {
        if (WatchStore.hasWatchCategories()) {
            var catsView = new CategoriesView(WatchStore.loadMerged([] as Array<InfoCategory>));
            WatchUi.switchToView(catsView, new CategoriesDelegate(catsView), WatchUi.SLIDE_IMMEDIATE);
            return;
        }
        if (Communications has :openWebPage) {
            Communications.openWebPage(SETUP_URL, {}, null);
        }
    }

    // True if (x,y) hits the "create on watch" hint at the bottom of the screen.
    function createButtonContains(x as Number, y as Number) as Boolean {
        return y >= createY - 22;
    }

    function onUpdate(dc as Dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        dc.drawText(cx, h * 0.1, Graphics.FONT_SMALL, "Scan to set up", Graphics.TEXT_JUSTIFY_CENTER);

        var qr = Application.loadResource(Rez.Drawables.QrCode) as BitmapResource;
        var qrSize = qr.getWidth();
        dc.drawBitmap(cx - qrSize / 2, h * 0.46 - qrSize / 2, qr);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY, "giamat13.github.io", Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_DK_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, createY, Graphics.FONT_XTINY, "+ or create on watch", Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    function onHide() as Void {
    }

}

// InputDelegate (not BehaviorDelegate) for the same touch+button reason as
// CategoriesDelegate. Only handles the "create on watch" hint at the bottom.
class NoDataViewDelegate extends WatchUi.InputDelegate {

    var view as NoDataView;

    function initialize(v as NoDataView) {
        InputDelegate.initialize();
        view = v;
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    function onHold(clickEvent as WatchUi.ClickEvent) as Boolean {
        var coords = clickEvent.getCoordinates();
        return handleTapAt(coords[0], coords[1]);
    }

    private function handleTapAt(x as Number, y as Number) as Boolean {
        if (!view.createButtonContains(x, y)) {
            return false;
        }
        new CategoryCreateFlow(method(:onFirstCategoryCreated)).start();
        return true;
    }

    // No-op: the category is already persisted by the time this runs (see
    // WatchStore.addCategory), and NoDataView.onShow() picks it up and
    // switches to CategoriesView once this screen is visible again.
    function onFirstCategoryCreated(cat as InfoCategory) as Void {
    }

}
