# The Flutter adapter references every optional ML Kit text-recognition script,
# while ConvoCoach deliberately bundles and instantiates only the Latin script.
# These absent optional modules are therefore safe for R8 to ignore.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
