# Keep rules for R8 (minifyEnabled), scoped to the plugins this app actually
# uses. Most modern Flutter plugins bundle their own consumer-rules.pro inside
# their AAR and R8 picks those up automatically — the explicit rules below
# only cover cases worth pinning down rather than trusting to that.

# flutter_local_notifications: keeps its Android implementation classes, since
# they're referenced from AndroidManifest.xml receivers/services rather than
# only from Dart-callable code paths R8 can trace.
-keep class com.dexterous.** { *; }

# Gson is used internally by flutter_local_notifications for the scheduled
# notification payload; without this, deserializing scheduled notifications
# after a device reboot can drop fields to unpredictable values instead of
# just failing loudly.
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# home_widget: the RemoteViews-based widget provider is invoked by the
# launcher via reflection on the class name declared in AndroidManifest.xml
# and scrolltoll_widget_info.xml, not through a traceable Dart call.
-keep class com.chirag.scrolltoll.BrainfogWidgetProvider { *; }
-keep class es.antonborri.home_widget.** { *; }

# Our own overlay service and broadcast receivers: same reflection-by-name
# concern as the widget provider above.
-keep class com.chirag.scrolltoll.** { *; }

# timezone / flutter_timezone: ship bundled tzdata as resources rather than
# code, no reflection concern, but device_apps and usage_stats are thin
# community plugins with less consistent consumer-rules coverage than
# Google/first-party plugins — keep their package wholesale rather than
# risk a stripped method that only fires on ROM variations we don't cover
# in local testing.
-keep class fr.g123k.deviceapps.** { *; }
-keep class io.github.parassharmaa.usage_stats.** { *; }
-dontwarn fr.g123k.deviceapps.**
-dontwarn io.github.parassharmaa.usage_stats.**
