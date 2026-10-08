# R8 de la variante release. Hotwire Native retrouve les destinations par réflexion Kotlin (annotation
# @HotwireDestinationDeepLink lue par kotlin-reflect) : les classes de l'app et leurs métadonnées restent intactes.
-keep class com.lnclass.student.** { *; }
-keep class kotlin.Metadata { *; }
-keepattributes RuntimeVisibleAnnotations,AnnotationDefault,Signature,InnerClasses,EnclosingMethod,*Annotation*
-keep class kotlin.reflect.jvm.internal.** { *; }
# Annotations de compilation (errorprone, gardées par la règle com.google.** de Hotwire) : absentes sur Android.
-dontwarn javax.lang.model.element.Modifier
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**
