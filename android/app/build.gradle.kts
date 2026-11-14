import com.android.build.api.instrumentation.AsmClassVisitorFactory
import com.android.build.api.instrumentation.ClassContext
import com.android.build.api.instrumentation.ClassData
import com.android.build.api.instrumentation.InstrumentationParameters
import com.android.build.api.instrumentation.InstrumentationScope
import org.objectweb.asm.ClassVisitor
import org.objectweb.asm.MethodVisitor
import org.objectweb.asm.Opcodes
import org.objectweb.asm.Type

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

/** Upstream protocol diagnostics can contain stream names/keys. Remove only
 * RootEncoder's Android Log calls in every variant, including debug/profile.
 * Application diagnostics and encoder behavior remain unchanged.
 */
abstract class PrivateTransportLogs : AsmClassVisitorFactory<InstrumentationParameters.None> {
    override fun isInstrumentable(classData: ClassData) =
        classData.className.startsWith("com.pedro.rtmp.") ||
            classData.className.startsWith("com.pedro.common.")

    override fun createClassVisitor(classContext: ClassContext, nextClassVisitor: ClassVisitor): ClassVisitor =
        object : ClassVisitor(Opcodes.ASM9, nextClassVisitor) {
            override fun visitMethod(access: Int, name: String, descriptor: String, signature: String?, exceptions: Array<out String>?): MethodVisitor {
                val next = super.visitMethod(access, name, descriptor, signature, exceptions)
                return object : MethodVisitor(Opcodes.ASM9, next) {
                    override fun visitMethodInsn(opcode: Int, owner: String, name: String, descriptor: String, isInterface: Boolean) {
                        if (opcode != Opcodes.INVOKESTATIC || owner != "android/util/Log") {
                            super.visitMethodInsn(opcode, owner, name, descriptor, isInterface)
                            return
                        }
                        Type.getArgumentTypes(descriptor).reversed().forEach {
                            super.visitInsn(if (it.size == 2) Opcodes.POP2 else Opcodes.POP)
                        }
                        when (Type.getReturnType(descriptor).sort) {
                            Type.VOID -> Unit
                            Type.OBJECT, Type.ARRAY -> super.visitInsn(Opcodes.ACONST_NULL)
                            else -> super.visitInsn(Opcodes.ICONST_0)
                        }
                    }
                }
            }
        }
}

androidComponents.onVariants(androidComponents.selector().all()) { variant ->
    variant.instrumentation.transformClassesWith(PrivateTransportLogs::class.java, InstrumentationScope.ALL) {}
}

val releaseStore = System.getenv("XRECORDER_STORE_FILE")
val releaseStorePassword = System.getenv("XRECORDER_STORE_PASSWORD")
val releaseAlias = System.getenv("XRECORDER_KEY_ALIAS")
val releaseKeyPassword = System.getenv("XRECORDER_KEY_PASSWORD")
val signingValues = listOf(releaseStore, releaseStorePassword, releaseAlias, releaseKeyPassword)
require(signingValues.all { it.isNullOrBlank() } || signingValues.all { !it.isNullOrBlank() }) {
    "Configure all four XRECORDER signing environment variables, or omit all for an unsigned release."
}

android {
    namespace = "com.xrecorder.xrecorder"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.xrecorder.xrecorder"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        externalNativeBuild {
            cmake {
                arguments += listOf("-DANDROID_STL=c++_shared")
                targets += listOf("threeh_whisper")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    signingConfigs {
        if (!releaseStore.isNullOrBlank()) {
            create("production") {
                storeFile = file(releaseStore)
                storePassword = releaseStorePassword
                keyAlias = releaseAlias
                keyPassword = releaseKeyPassword
            }
        }
    }
    buildTypes {
        release {
            signingConfig = if (!releaseStore.isNullOrBlank()) signingConfigs.getByName("production") else null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// Android editor-engine spike: pin one version across preview/effects/export.
dependencies {
    testImplementation("junit:junit:4.13.2")
    implementation("androidx.media3:media3-transformer:1.11.1")
    implementation("androidx.media3:media3-effect:1.11.1")
    implementation("androidx.media3:media3-ui:1.11.1")
    implementation("com.github.pedroSG94.RootEncoder:rtmp:2.8.2")
}
