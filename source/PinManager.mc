import Toybox.Lang;
import Toybox.Application.Storage;

// Owns the on-watch PIN: only its hash is ever kept in Storage, never the
// PIN itself. Changing the PIN requires the old one so every PIN-protected
// category can be re-encrypted under the new key in the same step (see
// WatchStore.reencryptCategory) - nothing becomes unreadable when the PIN
// changes, unlike a scheme that just re-derives a key from a new PIN alone.
class PinManager {

    private static const HASH_KEY = "wsPinHash";
    private static const NUMERIC_KEY = "wsPinIsNumeric";

    static function isSet() as Boolean {
        return Storage.getValue(HASH_KEY) != null;
    }

    // Whether the current PIN is digits-only - lets the unlock prompt use
    // the quick numeric pad instead of the full keyboard. Recorded at
    // set/change time since the PIN itself is never stored to check later.
    static function isNumeric() as Boolean {
        var v = Storage.getValue(NUMERIC_KEY);
        return v == null ? true : (v as Boolean);
    }

    static function verify(pin as String) as Boolean {
        var stored = Storage.getValue(HASH_KEY);
        if (stored == null) {
            return false;
        }
        return (Crypto.sha256(pin) as ByteArray).equals(stored as ByteArray);
    }

    // First-time PIN set: no existing protected data to re-encrypt.
    static function setPin(pin as String) as Void {
        Storage.setValue(HASH_KEY, Crypto.sha256(pin));
        Storage.setValue(NUMERIC_KEY, Crypto.isNumeric(pin));
    }

    // Re-encrypts every PIN-protected category's items under the new key,
    // then swaps the stored hash. Returns false (and changes nothing) if
    // `oldPin` doesn't match what's currently set.
    static function changePin(oldPin as String, newPin as String, categories as Array<InfoCategory>) as Boolean {
        if (!verify(oldPin)) {
            return false;
        }
        var oldKey = Crypto.deriveKey(oldPin);
        var newKey = Crypto.deriveKey(newPin);
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.requiresPin) {
                WatchStore.reencryptCategory(cat, oldKey, newKey);
            }
        }
        Storage.setValue(HASH_KEY, Crypto.sha256(newPin));
        Storage.setValue(NUMERIC_KEY, Crypto.isNumeric(newPin));
        return true;
    }

    // Clears the PIN without touching any category's encrypted items -
    // only used by WatchStore.resetAll() (DEBUGRESET), which wipes the
    // categories/items themselves right along with it. removePin() is the
    // one to use anywhere the data must stay readable afterward.
    static function reset() as Void {
        Storage.deleteValue(HASH_KEY);
        Storage.deleteValue(NUMERIC_KEY);
    }

    // Decrypts every PIN-protected category back to plaintext storage and
    // clears the PIN. Returns false (and changes nothing) if `pin` is wrong.
    static function removePin(pin as String, categories as Array<InfoCategory>) as Boolean {
        if (!verify(pin)) {
            return false;
        }
        var key = Crypto.deriveKey(pin);
        for (var i = 0; i < categories.size(); i++) {
            var cat = categories[i];
            if (cat.requiresPin) {
                WatchStore.decryptCategoryToPlain(cat, key);
            }
        }
        Storage.deleteValue(HASH_KEY);
        Storage.deleteValue(NUMERIC_KEY);
        return true;
    }

}
