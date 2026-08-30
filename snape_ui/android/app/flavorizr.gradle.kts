import com.android.build.gradle.AppExtension

val android = project.extensions.getByType(AppExtension::class.java)

android.apply {
    flavorDimensions("flavor-type")

    productFlavors {
        create("dev") {
            dimension = "flavor-type"
            applicationId = "com.example.snape_ui.dev"
            resValue(type = "string", name = "app_name", value = "Snape Dev")
        }
        create("prod") {
            dimension = "flavor-type"
            applicationId = "com.example.snape_ui"
            resValue(type = "string", name = "app_name", value = "Snape")
        }
    }

    buildFeatures.resValues = true
}