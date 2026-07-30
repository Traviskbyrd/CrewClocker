package com.tbyrd.crewclocker.data

import io.github.jan.supabase.createSupabaseClient
import io.github.jan.supabase.postgrest.Postgrest
import io.github.jan.supabase.gotrue.Auth
import io.github.jan.supabase.gotrue.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.serializer.KotlinXSerializer
import kotlinx.serialization.json.Json

// This module handles the connection to your Supabase project (jpppwigxbnbhqlhsekkz)
object SupabaseClient {
    private const val SUPABASE_URL = "https://jpppwigxbnbhqlhsekkz.supabase.co"
    // Note: In a production app, the key should be retrieved securely at runtime
    private const val SUPABASE_ANON_KEY = "sb_publishable_kS2eOJpIB1FdR4y3H8NwYg_VssqttVq" 

    val client = createSupabaseClient(
        supabaseUrl = SUPABASE_URL,
        supabaseKey = SUPABASE_ANON_KEY
    ) {
        install(Postgrest)
        install(Auth)
        
        defaultSerializer = KotlinXSerializer(Json {
            ignoreUnknownKeys = true
            coerceInputValues = true
        })
    }

    val auth = client.auth
    val postgrest = client.postgrest
}
