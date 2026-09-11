import Toybox.Lang;
import Toybox.StringUtil;
import Toybox.Math;
import Toybox.Cryptography;

// AES-128-CBC encryption (PKCS7-padded) plus SHA-256 hashing, used to keep
// PIN-protected category data encrypted at rest and to verify a typed PIN
// without ever storing the PIN itself. The AES key is always derived from
// the PIN (deriveKey), never stored - so nothing needs to change when the
// PIN changes except re-running encrypt()/decrypt() with the two keys (see
// PinManager.changePin).
//
// Toybox.Cryptography was added in Connect IQ API 3.0.0; this app's device
// list reaches back to API 2.4.0, so devices without it fall back to a
// non-cryptographic hash/passthrough here. On those devices PIN-protected
// data is still gated by the PIN prompt, just not encrypted at rest.
class Crypto {

    static function isSupported() as Boolean {
        return (Toybox has :Cryptography);
    }

    static function isNumeric(s as String) as Boolean {
        if (s.length() == 0) {
            return false;
        }
        for (var i = 0; i < s.length(); i++) {
            if ("0123456789".find(s.substring(i, i + 1) as String) == null) {
                return false;
            }
        }
        return true;
    }

    static function toBytes(s as String) as ByteArray {
        return StringUtil.convertEncodedString(s, {
            :fromRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :toRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :encoding => StringUtil.CHAR_ENCODING_UTF8,
        }) as ByteArray;
    }

    static function toStr(b as ByteArray) as String {
        return StringUtil.convertEncodedString(b, {
            :fromRepresentation => StringUtil.REPRESENTATION_BYTE_ARRAY,
            :toRepresentation => StringUtil.REPRESENTATION_STRING_PLAIN_TEXT,
            :encoding => StringUtil.CHAR_ENCODING_UTF8,
        }) as String;
    }

    // 32-byte digest of `s`, used both for PIN verification (sha256 of the
    // whole PIN) and to derive the AES key (first 16 bytes, see deriveKey).
    static function sha256(s as String) as ByteArray {
        if (!isSupported()) {
            return fallbackHash(s);
        }
        var hash = new Cryptography.Hash({ :algorithm => Cryptography.HASH_SHA256 });
        hash.update(toBytes(s));
        return hash.digest();
    }

    static function deriveKey(pin as String) as ByteArray {
        var digest = sha256(pin);
        var key = []b;
        for (var i = 0; i < 16; i++) {
            key.add(digest[i]);
        }
        return key;
    }

    // ponytail: not real cryptography, just a deterministic byte-mixing
    // function - only used on devices with no Cryptography module at all,
    // so PIN verification still works there (encrypt()/decrypt() below fall
    // back to storing plaintext on those same devices).
    private static function fallbackHash(s as String) as ByteArray {
        var bytes = toBytes(s);
        var out = []b;
        var acc = 7;
        for (var i = 0; i < 32; i++) {
            for (var j = 0; j < bytes.size(); j++) {
                acc = ((acc * 31) + bytes[j] + i) & 0xFF;
            }
            out.add(acc);
        }
        return out;
    }

    private static function pkcs7Pad(b as ByteArray) as ByteArray {
        var padLen = 16 - (b.size() % 16);
        var out = []b;
        out.addAll(b);
        for (var i = 0; i < padLen; i++) {
            out.add(padLen);
        }
        return out;
    }

    private static function pkcs7Unpad(b as ByteArray) as ByteArray {
        if (b.size() == 0) {
            return b;
        }
        var padLen = b[b.size() - 1] as Number;
        if (padLen < 1 || padLen > 16 || padLen > b.size()) {
            return b;
        }
        var out = []b;
        for (var i = 0; i < b.size() - padLen; i++) {
            out.add(b[i]);
        }
        return out;
    }

    // Encrypts `plain` under `key`; returns a single blob (16-byte random IV
    // followed by ciphertext) so callers only need to persist one value.
    static function encrypt(plain as String, key as ByteArray) as ByteArray {
        if (!isSupported()) {
            return toBytes(plain);
        }
        var iv = randomBytes(16);
        var cipher = new Cryptography.Cipher({
            :algorithm => Cryptography.CIPHER_AES128,
            :mode => Cryptography.MODE_CBC,
            :key => key,
            :iv => iv,
        });
        var ct = cipher.encrypt(pkcs7Pad(toBytes(plain)));
        var blob = []b;
        blob.addAll(iv);
        blob.addAll(ct);
        return blob;
    }

    // Reverses encrypt(): splits the leading 16-byte IV back off `blob`.
    static function decrypt(blob as ByteArray, key as ByteArray) as String {
        if (!isSupported()) {
            return toStr(blob);
        }
        var iv = []b;
        for (var i = 0; i < 16; i++) {
            iv.add(blob[i]);
        }
        var ct = []b;
        for (var i = 16; i < blob.size(); i++) {
            ct.add(blob[i]);
        }
        var cipher = new Cryptography.Cipher({
            :algorithm => Cryptography.CIPHER_AES128,
            :mode => Cryptography.MODE_CBC,
            :key => key,
            :iv => iv,
        });
        var padded = cipher.decrypt(ct);
        return toStr(pkcs7Unpad(padded));
    }

    private static function randomBytes(n as Number) as ByteArray {
        var ba = []b;
        for (var i = 0; i < n; i++) {
            ba.add(Math.rand() % 256);
        }
        return ba;
    }

}
