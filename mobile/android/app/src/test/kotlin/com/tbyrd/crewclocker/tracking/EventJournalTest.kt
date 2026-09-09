package com.tbyrd.crewclocker.tracking

import android.content.Context
import android.database.sqlite.SQLiteDatabase
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

@RunWith(RobolectricTestRunner::class)
@Config(sdk=[28], manifest=Config.NONE)
class EventJournalTest {
    private lateinit var context: Context
    private val site=JSONObject("""{"id":"site-a","assignment_id":"assignment-a","assignment_version":1}""")
    @Before fun setup(){context=RuntimeEnvironment.getApplication();context.deleteDatabase("crewclocker_events.db")}
    @After fun cleanup(){context.deleteDatabase("crewclocker_events.db")}
    @Test fun captureSurvivesCloseAndAcknowledgeOnlyTouchesExactIds() {
        EventJournal(context).use { it.append("owner-a","device-a",listOf(site),"enter");it.append("owner-a","device-a",listOf(site),"exit") }
        EventJournal(context).use {
            assertEquals(2L,it.count())
            val first=it.pending().first()
            assertEquals("assignment-a",first["assignment_id"])
            assertEquals("device-a",first["device_id"])
            it.acknowledge(listOf(first["event_id"] as String,"unknown-id"))
        }
        EventJournal(context).use { assertEquals(1L,it.count());assertEquals("exit",it.pending().single()["transition"]) }
    }
    @Test fun pendingRecordsBlockADeviceOwnerHandoff() {
        EventJournal(context).use {
            it.append("owner-a","device-a",listOf(site),"dwell")
            assertFalse(it.hasOtherOwner("owner-a"));assertTrue(it.hasOtherOwner("owner-b"))
        }
    }
    @Test fun versionOneUpgradePreservesUnsentObservations() {
        val path=context.getDatabasePath("crewclocker_events.db");path.parentFile!!.mkdirs()
        SQLiteDatabase.openOrCreateDatabase(path,null).use {
            it.execSQL("CREATE TABLE observations(sequence INTEGER PRIMARY KEY AUTOINCREMENT,event_id TEXT NOT NULL UNIQUE,employee_id TEXT NOT NULL,site_id TEXT NOT NULL,transition TEXT NOT NULL,observed_at TEXT NOT NULL,uploaded INTEGER NOT NULL DEFAULT 0)")
            it.execSQL("INSERT INTO observations(event_id,employee_id,site_id,transition,observed_at) VALUES('legacy','owner-a','site-a','enter','2026-09-09T00:00:00Z')")
            it.version=1
        }
        EventJournal(context).use {
            assertEquals(1L,it.count());assertEquals("legacy",it.pending().single()["event_id"])
            assertNull(it.pending().single()["assignment_id"])
            it.append("owner-a","device-a",listOf(site),"exit")
            assertEquals(2L,it.count())
        }
    }
}
