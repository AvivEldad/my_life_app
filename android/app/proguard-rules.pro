# Required so flutter_local_notifications' internal Gson-based storage of
# scheduled notifications keeps working under R8 shrinking. Without these,
# zonedSchedule() throws "TypeToken must be created with a type argument"
# and every scheduled (non-immediate) notification silently fails to be
# registered with Android's AlarmManager.
-keep class com.dexterous.** { *; }
-keep class com.google.gson.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep public class * implements java.lang.reflect.Type
-keepattributes Signature
-keepattributes *Annotation*