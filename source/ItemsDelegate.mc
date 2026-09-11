import Toybox.WatchUi;
import Toybox.Lang;

// InputDelegate rather than BehaviorDelegate for the same reason as
// CategoriesDelegate: BehaviorDelegate's touch translation can misfire on
// touch+button devices, so raw onSwipe/onKey are used directly instead of
// its onNextPage/onPreviousPage/onBack. Tap is used for the bottom-left
// options button and for editing the current item (when it's watch-created).
class ItemsDelegate extends WatchUi.InputDelegate {

    var view as ItemsView;
    var categoriesView as CategoriesView;

    function initialize(v as ItemsView, catsView as CategoriesView) {
        InputDelegate.initialize();
        view = v;
        categoriesView = catsView;
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
        if (view.plusButtonContains(x, y)) {
            openBottomMenu();
            return true;
        }
        if (view.category.items.size() > 0 && view.category.items[view.cursor].fromWatch) {
            openItemMenu();
            return true;
        }
        return false;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var dir = swipeEvent.getDirection();
        if (dir == WatchUi.SWIPE_UP) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (dir == WatchUi.SWIPE_DOWN) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (dir == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            view.move(1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            view.move(-1);
            WatchUi.requestUpdate();
            return true;
        } else if (key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    // -- Bottom-left options menu: add item, plus edit/delete the category
    // -- itself when it was created on the watch (not the phone).

    private function openBottomMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => "Options" });
        menu.addItem(new WatchUi.MenuItem("Add item", null, :addItem, null));
        if (view.category.fromWatch) {
            menu.addItem(new WatchUi.MenuItem("Edit category", null, :editCategory, null));
        }
        var actions = {
            :addItem => method(:startAddItem),
            :editCategory => method(:openCategoryEditMenu),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    function startAddItem() as Void {
        new ItemCreateFlow(view.category, method(:onItemCreated)).start();
    }

    function onItemCreated(item as InfoItem) as Void {
        view.category.items.add(item);
        view.cursor = view.category.items.size() - 1;
        WatchUi.requestUpdate();
    }

    function openCategoryEditMenu() as Void {
        var menu = new WatchUi.Menu2({ :title => view.category.name });
        menu.addItem(new WatchUi.MenuItem("Rename", null, :rename, null));
        menu.addItem(new WatchUi.MenuItem("Change color", null, :recolor, null));
        menu.addItem(new WatchUi.MenuItem("Delete", null, :del, null));
        var actions = {
            :rename => method(:startRenameCategory),
            :recolor => method(:startRecolorCategory),
            :del => method(:confirmDeleteCategory),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    function startRenameCategory() as Void {
        Keyboard.show(view.category.name, method(:onCategoryRenamed));
    }

    function onCategoryRenamed(text as String) as Void {
        if (text.equals("")) {
            return;
        }
        WatchStore.updateCategoryName(view.category, text);
        view.category.name = text;
        WatchUi.requestUpdate();
    }

    function startRecolorCategory() as Void {
        var cpView = new ColorPickerView();
        WatchUi.pushView(cpView, new ColorPickerDelegate(cpView, method(:onCategoryRecolored)), WatchUi.SLIDE_UP);
    }

    function onCategoryRecolored(color as Number) as Void {
        WatchStore.updateCategoryColor(view.category, color);
        view.category.color = color;
        WatchUi.requestUpdate();
    }

    function confirmDeleteCategory() as Void {
        WatchUi.pushView(new WatchUi.Confirmation("Delete category?"), new ConfirmDelegate(method(:onCategoryDeleteConfirmed)), WatchUi.SLIDE_IMMEDIATE);
    }

    function onCategoryDeleteConfirmed() as Void {
        WatchStore.deleteCategory(view.category);
        categoriesView.removeCategory(view.category);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    // -- Per-item menu: only reachable for items created on the watch.

    private function openItemMenu() as Void {
        var item = view.category.items[view.cursor];
        var menu = new WatchUi.Menu2({ :title => item.label });
        menu.addItem(new WatchUi.MenuItem("Edit label", null, :editLabel, null));
        menu.addItem(new WatchUi.MenuItem("Edit value", null, :editValue, null));
        menu.addItem(new WatchUi.MenuItem("Delete", null, :del, null));
        var actions = {
            :editLabel => method(:startEditItemLabel),
            :editValue => method(:startEditItemValue),
            :del => method(:confirmDeleteItem),
        };
        WatchUi.pushView(menu, new ActionMenuDelegate(actions), WatchUi.SLIDE_UP);
    }

    function startEditItemLabel() as Void {
        Keyboard.show(view.category.items[view.cursor].label, method(:onItemLabelEdited));
    }

    function onItemLabelEdited(text as String) as Void {
        if (text.equals("")) {
            return;
        }
        var item = view.category.items[view.cursor];
        WatchStore.updateItem(view.category, item, text, null);
        item.label = text;
        WatchUi.requestUpdate();
    }

    function startEditItemValue() as Void {
        Keyboard.show(view.category.items[view.cursor].value, method(:onItemValueEdited));
    }

    function onItemValueEdited(text as String) as Void {
        var item = view.category.items[view.cursor];
        WatchStore.updateItem(view.category, item, null, text);
        item.value = text;
        WatchUi.requestUpdate();
    }

    function confirmDeleteItem() as Void {
        WatchUi.pushView(new WatchUi.Confirmation("Delete item?"), new ConfirmDelegate(method(:onItemDeleteConfirmed)), WatchUi.SLIDE_IMMEDIATE);
    }

    function onItemDeleteConfirmed() as Void {
        var item = view.category.items[view.cursor];
        WatchStore.deleteItem(view.category, item);
        view.category.items.remove(item);
        if (view.cursor >= view.category.items.size() && view.cursor > 0) {
            view.cursor -= 1;
        }
        WatchUi.requestUpdate();
    }

}
