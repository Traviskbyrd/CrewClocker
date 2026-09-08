package com.tbyrd.crewclocker.tracking

import android.content.ContentValues
import android.content.Context
import android.database.sqlite.SQLiteDatabase
import android.database.sqlite.SQLiteOpenHelper
import java.time.Instant
import java.util.UUID

/** Native-owned SQLite journal. Capture commits before any network or Flutter work. */
class EventJournal(context: Context) : SQLiteOpenHelper(context, "crewclocker_events.db", null, 1) {
    override fun onCreate(db: SQLiteDatabase) {
        db.execSQL("""CREATE TABLE observations (
            sequence INTEGER PRIMARY KEY AUTOINCREMENT,
            event_id TEXT NOT NULL UNIQUE,
            employee_id TEXT NOT NULL,
            site_id TEXT NOT NULL,
            transition TEXT NOT NULL,
            observed_at TEXT NOT NULL,
            uploaded INTEGER NOT NULL DEFAULT 0
        )""")
    }
    override fun onUpgrade(db: SQLiteDatabase, oldVersion: Int, newVersion: Int) {
        error("An explicit non-destructive event journal migration is required")
    }
    fun append(employeeId: String, siteIds: List<String>, transition: String) {
        require(employeeId.isNotBlank())
        val db = writableDatabase
        db.beginTransaction()
        try {
            val observedAt = Instant.now().toString()
            siteIds.forEach { siteId ->
                val row = ContentValues().apply {
                    put("event_id", UUID.randomUUID().toString())
                    put("employee_id", employeeId)
                    put("site_id", siteId)
                    put("transition", transition)
                    put("observed_at", observedAt)
                }
                db.insertOrThrow("observations", null, row)
            }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
    fun pending(): List<Map<String, Any>> = readableDatabase.rawQuery(
        "SELECT sequence,event_id,employee_id,site_id,transition,observed_at FROM observations WHERE uploaded=0 ORDER BY sequence LIMIT 500", null
    ).use { cursor -> buildList {
        while (cursor.moveToNext()) add(mapOf(
            "sequence" to cursor.getLong(0), "event_id" to cursor.getString(1),
            "employee_id" to cursor.getString(2), "site_id" to cursor.getString(3),
            "transition" to cursor.getString(4), "observed_at" to cursor.getString(5)
        ))
    } }
    /** Call only after the server acknowledges these exact immutable event IDs. */
    fun acknowledge(ids: List<String>) {
        val db = writableDatabase
        db.beginTransaction()
        try {
            ids.forEach { id -> db.execSQL("UPDATE observations SET uploaded=1 WHERE event_id=?", arrayOf(id)) }
            db.setTransactionSuccessful()
        } finally { db.endTransaction() }
    }
}
