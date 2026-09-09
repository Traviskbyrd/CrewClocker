package com.tbyrd.crewclocker.tracking

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import org.json.JSONObject
import java.time.Instant
import java.util.UUID

/** Native-owned append-only capture, including when Flutter is not running. */
class EventJournal(context: Context) : SQLiteOpenHelper(context, "crewclocker_events.db", null, 2), java.io.Closeable {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE observations (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT, event_id TEXT NOT NULL UNIQUE,
            employee_id TEXT NOT NULL, site_id TEXT NOT NULL, transition TEXT NOT NULL,
            observed_at TEXT NOT NULL, uploaded INTEGER NOT NULL DEFAULT 0,
            assignment_id TEXT, assignment_version INTEGER, device_id TEXT)""")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        if (oldVersion == 1 && newVersion == 2) {
            db.execSQL("ALTER TABLE observations ADD COLUMN assignment_id TEXT")
            db.execSQL("ALTER TABLE observations ADD COLUMN assignment_version INTEGER")
            db.execSQL("ALTER TABLE observations ADD COLUMN device_id TEXT")
        } else error("Explicit journal migration required")
    }
    fun append(employee: String, device: String, sites: List<JSONObject>, transition: String) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            val observed = Instant.now().toString()
            sites.forEach { site ->
                val row = ContentValues().apply {
                    put("event_id", UUID.randomUUID().toString()); put("employee_id", employee)
                    put("site_id", site.getString("id")); put("transition", transition)
                    put("observed_at", observed); put("assignment_id", site.getString("assignment_id"))
                    put("assignment_version", site.getInt("assignment_version")); put("device_id", device)
                }
                db.insertOrThrow("observations", null, row)
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun count(): Long = readableDatabase.rawQuery("SELECT count(*) FROM observations WHERE uploaded=0", null).use {
        it.moveToFirst(); it.getLong(0)
    }
    fun hasOtherOwner(employee: String): Boolean = readableDatabase.rawQuery(
        "SELECT 1 FROM observations WHERE uploaded=0 AND employee_id<>? LIMIT 1", arrayOf(employee)
    ).use { it.moveToFirst() }
    fun pending(): List<Map<String, Any?>> = readableDatabase.rawQuery(
        "SELECT sequence,event_id,employee_id,site_id,transition,observed_at,assignment_id,assignment_version,device_id FROM observations WHERE uploaded=0 ORDER BY sequence LIMIT 500", null
    ).use { c -> buildList {
        while (c.moveToNext()) add(mapOf("sequence" to c.getLong(0), "event_id" to c.getString(1),
            "employee_id" to c.getString(2), "site_id" to c.getString(3), "transition" to c.getString(4),
            "observed_at" to c.getString(5), "assignment_id" to c.getString(6),
            "assignment_version" to if(c.isNull(7)) null else c.getInt(7), "device_id" to c.getString(8)))
    } }
    fun acknowledge(ids: List<String>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            ids.forEach { db.execSQL("UPDATE observations SET uploaded=1 WHERE event_id=?", arrayOf(it)) }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
