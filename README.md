# complain_app

A new Flutter project.

## Firebase Configuration

You can configure Firebase for this app now that the basic structure is set up. Follow these steps to integrate Firebase Authentication, Firestore, and Storage.

### Prerequisites
- A Google account
- Flutter SDK installed
- FlutterFire CLI installed globally: `dart pub global activate flutterfire_cli`

### Steps

1. **Create a Firebase Project**
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Click "Create a project" or select an existing one
   - Follow the setup wizard to create your project

2. **Enable Authentication**
   - In your Firebase project, go to "Authentication" in the left sidebar
   - Click on the "Sign-in method" tab
   - Enable "Email/Password" sign-in provider
   - Optionally, enable other providers if needed

3. **Enable Firestore Database**
   - Go to "Firestore Database" in the left sidebar
   - Click "Create database"
   - Choose "Start in test mode" for development (you can change rules later for production)
   - Select a location for your database

4. **Enable Storage**
   - Go to "Storage" in the left sidebar
   - Click "Get started"
   - Choose "Start in test mode" for development
   - Select a location for your storage bucket

5. **Add Flutter App to Firebase**
   - In Firebase Console, click the gear icon (settings) > "Project settings"
   - Scroll down to "Your apps" section
   - Click "Add app" and select the Flutter icon (or add for each platform: Android, iOS, Web)
   - Follow the prompts to register your app:
     - For Android: Provide package name (from android/app/build.gradle)
     - For iOS: Provide bundle ID (from ios/Runner/Info.plist)
     - For Web: Provide nickname
   - Download the config files when prompted (google-services.json for Android, GoogleService-Info.plist for iOS)

6. **Configure FlutterFire**
   - Open a terminal in the project root
   - Run: `flutterfire configure`
   - Select your Firebase project from the list
   - Select the platforms you want to configure (Android, iOS, Web, etc.)
   - This will generate/update `lib/firebase_options.dart` with your project configuration

7. **Update Firebase Security Rules (Optional but Recommended)**
   - For Firestore: Go to Firestore > Rules, update rules to secure your data
   - For Storage: Go to Storage > Rules, update rules to secure your files
   - Example Firestore rules for this app:
     ```
     rules_version = '2';
     service cloud.firestore {
       match /databases/{database}/documents {
         // Allow read/write for authenticated users
         match /{document=**} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```
   - Example Storage rules:
     ```
     rules_version = '2';
     service firebase.storage {
       match /b/{bucket}/o {
         match /{allPaths=*} {
           allow read, write: if request.auth != null;
         }
       }
     }
     ```

8. **Run the App**
   - After configuration, run `flutter run` to test the app
   - The app should now connect to your Firebase project

### Troubleshooting
- If `flutterfire configure` fails, ensure you have the Firebase CLI installed and are logged in: `firebase login`
- Make sure your app's package name/bundle ID matches what's registered in Firebase
- Check that all Firebase dependencies are added in `pubspec.yaml` (they should already be included)

### Next Steps
- Test authentication by registering/logging in
- Submit a complaint to verify Firestore integration
- Upload attachments to test Storage

---

## Alternative: Cloudinary for File Storage (Free Tier with More Storage)

If you want more than Firebase Storage's free tier, Cloudinary offers:
- **10 GB storage** free
- **20 GB/month bandwidth** free
- Generous free tier perfect for this app

### Steps to Use Cloudinary

1. **Sign Up**
   - Go to [Cloudinary](https://cloudinary.com/users/register/free)
   - Sign up for a free account
   - Verify your email

2. **Get Your Cloud Name**
   - Log in to Cloudinary Dashboard
   - Copy your "Cloud name" (displayed in the dashboard)

3. **Create an Upload Preset**
   - Go to Settings > Upload
   - Click "Add upload preset"
   - Name: `complain_app_preset` (or any name)
   - Mode: Unsigned
   - Allowed formats: All
   - Click "Save"
   - Copy the preset name

4. **Update the App**
   - Open [lib/services/cloudinary_storage_service.dart](lib/services/cloudinary_storage_service.dart)
   - Replace `YOUR_CLOUD_NAME` with your Cloudinary cloud name
   - Replace `YOUR_UPLOAD_PRESET` with your upload preset name
   - In your complaint form, import and use `CloudinaryStorageService` instead of `StorageService`

5. **Example Usage**
   ```dart
   final cloudinaryService = CloudinaryStorageService();
   final fileUrl = await cloudinaryService.uploadComplaintAttachment(
     complaintId: complaintId,
     fileBytes: fileBytes,
     fileName: fileName,
   );
   ```

### Comparison

| Feature | Firebase Storage | Cloudinary |
|---------|-----------------|-----------|
| Free Storage | 1 GB | 10 GB |
| Free Bandwidth | 1 GB/month | 20 GB/month |
| Best For | Small apps | Apps with more uploads |
| Setup | Medium | Easy |

**Recommendation:** Start with Firebase Storage's free tier. Switch to Cloudinary if you need more storage.
