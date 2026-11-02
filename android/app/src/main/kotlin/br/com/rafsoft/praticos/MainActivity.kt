package br.com.rafsoft.praticos

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.provider.ContactsContract.CommonDataKinds.Phone
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingContact: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CONTACTS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "pick") pickContact(result) else result.notImplemented()
            }
    }

    // The phone picker needs no READ_CONTACTS: the system grants read access
    // only to the row the person chooses. That row has the name and the
    // number, not the e-mail, and contacts without a number are not listed.
    private fun pickContact(result: MethodChannel.Result) {
        if (pendingContact != null) {
            result.error("busy", "Contact picker already open", null)
            return
        }
        pendingContact = result
        try {
            startActivityForResult(
                Intent(Intent.ACTION_PICK).setType(Phone.CONTENT_TYPE),
                PICK_CONTACT_REQUEST,
            )
        } catch (e: ActivityNotFoundException) {
            pendingContact = null
            result.error("unavailable", e.message, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_CONTACT_REQUEST) return
        val result = pendingContact ?: return
        pendingContact = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        try {
            val projection = arrayOf(Phone.DISPLAY_NAME, Phone.NUMBER)
            contentResolver.query(uri, projection, null, null, null).use { cursor ->
                if (cursor == null || !cursor.moveToFirst()) {
                    result.success(null)
                } else {
                    result.success(
                        mapOf(
                            "name" to cursor.getString(0),
                            "phones" to listOfNotNull(cursor.getString(1)),
                        ),
                    )
                }
            }
        } catch (e: Exception) {
            result.error("unavailable", e.message, null)
        }
    }

    private companion object {
        const val CONTACTS_CHANNEL = "br.com.rafsoft.praticos/contacts"
        const val PICK_CONTACT_REQUEST = 7301
    }
}
