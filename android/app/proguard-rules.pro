# flutter_local_notifications — 防止 R8 剥离 Gson TypeToken 泛型信息
-keep class com.dexterous.** { *; }
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken
