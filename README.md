# 🏥 SwasthyaAI - Your Health Companion

<div align="center">

**An AI-Powered Personal Health Tracking & Wellness Management System**

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)](https://firebase.google.com)
[![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![AI](https://img.shields.io/badge/Gemini_AI-8E75B2?style=for-the-badge&logo=google&logoColor=white)](https://ai.google.dev)

</div>

---

## 📖 About The Project

**SwasthyaAI** (Sanskrit: स्वास्थ्य = Health) is a comprehensive, cross-platform mobile and web application designed to help users track and manage their holistic health. Combining modern technology with behavioral psychology principles, SwasthyaAI empowers users to monitor mood, sleep patterns, hydration levels, and physical activity—all in one beautifully designed, AI-powered interface.

### 🎯 Why SwasthyaAI?

In today's fast-paced world, people struggle to:
- ⏰ Maintain consistent health tracking habits
- 📊 Understand patterns in their physical and mental well-being
- 🤔 Get personalized health insights without expensive consultations
- 📱 Access health data seamlessly across devices

**SwasthyaAI solves these problems** by providing an intuitive, gamified, and AI-enhanced platform that makes health tracking effortless and engaging.

---

## ✨ Key Features

### 🎭 Mood Tracker
- 5-point emoji-based mood logging system (😟 😐 🙂 😊 😄)
- Daily mood patterns and emotional insights
- Historical mood trend visualization
- Quick and intuitive logging interface

### 😴 Sleep Tracker
- Log hours of sleep with timestamps
- Sleep quality analysis and patterns
- Personalized sleep recommendations
- Weekly and monthly sleep reports

### 💧 Water Intake Tracker
- Set daily hydration goals (default: 8 glasses)
- Visual progress indicators
- Track hydration trends over time
- Real-time completion status

### 🏃‍♂️ Activity Tracker
- Log various exercise types (walking, running, gym, yoga, cycling, etc.)
- Track duration and steps
- Activity streak monitoring
- Fitness insights and recommendations

### 🤖 AI Health Coach
- Powered by **Google Gemini API**
- Personalized health recommendations based on your data
- Natural language query support
- Context-aware responses
- 24/7 availability for health guidance

### 📊 Interactive Dashboard
- Real-time health metrics visualization
- **Animated bouncy icons** for enhanced engagement
- Streak tracking with gamification (fire icon for active streaks)
- Progress percentage indicators
- Recent activity timeline
- Daily completion status for all health goals
- Beautiful gradient cards with smooth animations

### 👤 User Profile & Settings
- Secure Firebase authentication
- Email/Password and Google Sign-In support
- Real-time profile updates
- Data privacy and security controls
- Account management

### 🎨 Beautiful UI/UX
- Modern, gradient-based design with purple/blue theme
- Smooth animations and transitions
- Bouncy, floating icon animations
- Responsive layout for all screen sizes
- Accessibility-friendly interface
- Cross-platform consistency (Android, iOS, Web)

---

## 🛠️ Tech Stack

### Frontend
- **Flutter 3.0+** - Cross-platform UI framework
- **Dart 3.0+** - Programming language
- **Provider** - State management
- **Material Design 3** - UI components

### Backend & Services
- **Firebase Authentication** - User authentication & authorization
- **Cloud Firestore** - Real-time NoSQL database
- **Firebase Storage** - Cloud file storage
- **Google Gemini AI** - AI-powered conversational chatbot

### Development Tools
- **Android Studio** - Android development IDE
- **VS Code** - Lightweight code editor
- **Git & GitHub** - Version control

---

## 🏗️ System Architecture
```
┌─────────────────────────────────────────────────────────┐
│              SWASTHYAAI SYSTEM ARCHITECTURE             │
└─────────────────────────────────────────────────────────┘

           ┌──────────────┐              ┌──────────────┐
           │              │              │              │
           │   FLUTTER    │◄────────────►│   FIREBASE   │
           │  (Frontend)  │   REST API   │  (Backend)   │
           │              │              │              │
           └──────┬───────┘              └──────┬───────┘
                  │                             │
    ┌─────────────┼─────────────────────────────┼──────────────┐
    │             │                             │              │
    │    ┌────────▼─────────┐         ┌────────▼────────┐     │
    │    │                  │         │                 │     │
    │    │  Authentication  │         │  Health         │     │
    │    │  Module          │         │  Monitoring     │     │
    │    │                  │         │  Module         │     │
    │    │  • Email/Pass    │         │  • Mood         │     │
    │    │  • Google OAuth  │         │  • Sleep        │     │
    │    │  • Session Mgmt  │         │  • Water        │     │
    │    │                  │         │  • Activity     │     │
    │    └──────────────────┘         └─────────────────┘     │
    │                                                          │
    │    ┌──────────────────┐         ┌─────────────────┐     │
    │    │                  │         │                 │     │
    │    │  AI Chatbot      │         │  Dashboard &    │     │
    │    │  Module          │         │  Visualization  │     │
    │    │  (Gemini API)    │         │                 │     │
    │    │                  │         │  • Progress     │     │
    │    │  • Insights      │         │  • Streaks      │     │
    │    │  • Recommend.    │         │  • Analytics    │     │
    │    │  • Chat Support  │         │  • Animations   │     │
    │    │                  │         │                 │     │
    │    └──────────────────┘         └─────────────────┘     │
    │                                                          │
    │    ┌──────────────────┐         ┌─────────────────┐     │
    │    │                  │         │                 │     │
    │    │  Data Storage &  │         │  Profile &      │     │
    │    │  Analytics       │         │  Settings       │     │
    │    │                  │         │                 │     │
    │    │  • Firestore DB  │         │  • User Info    │     │
    │    │  • Real-time     │         │  • Preferences  │     │
    │    │  • Health Logs   │         │  • Security     │     │
    │    │                  │         │                 │     │
    │    └──────────────────┘         └─────────────────┘     │
    │                                                          │
    └──────────────────────────────────────────────────────────┘
```

---

## 📱 Installation & Setup

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** (3.0 or higher) - [Download](https://flutter.dev/docs/get-started/install)
- **Dart SDK** (3.0 or higher) - Comes with Flutter
- **Android Studio** / **Xcode** (for mobile development)
- **Firebase Account** - [Create Account](https://firebase.google.com)
- **Google Gemini API Key** - [Get API Key](https://makersuite.google.com/app/apikey)

### Step 1: Clone the Repository
```bash
git clone https://github.com/yourusername/swasthyaai-health-app.git
cd swasthyaai-health-app
```

### Step 2: Install Flutter Dependencies
```bash
flutter pub get
```

### Step 3: Firebase Setup

#### 3.1 Create Firebase Project
1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Enter project name: `swasthyaai-health-app`
4. Follow the setup wizard

#### 3.2 Add Android App
1. In Firebase Console, click "Add App" → Android
2. Enter package name: `com.example.minor_project` (or your package name)
3. Download `google-services.json`
4. Place it in: `android/app/google-services.json`

#### 3.3 Add iOS App (Optional)
1. Click "Add App" → iOS
2. Enter bundle ID
3. Download `GoogleService-Info.plist`
4. Place it in: `ios/Runner/GoogleService-Info.plist`

#### 3.4 Enable Authentication
1. In Firebase Console → Authentication
2. Click "Get Started"
3. Enable "Email/Password"
4. Enable "Google" sign-in method

#### 3.5 Create Firestore Database
1. In Firebase Console → Firestore Database
2. Click "Create Database"
3. Choose "Start in test mode" (for development)
4. Select your preferred location

### Step 4: Web Configuration (For Web Support)

Edit `web/index.html` and add your Firebase config:
```html
<!-- Add this before closing </body> tag -->
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-auth-compat.js"></script>
<script src="https://www.gstatic.com/firebasejs/10.7.0/firebase-firestore-compat.js"></script>

<script>
  const firebaseConfig = {
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT_ID.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
    measurementId: "YOUR_MEASUREMENT_ID"
  };
  
  firebase.initializeApp(firebaseConfig);
</script>
```

### Step 5: Gemini AI Setup

1. Get your API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Add it to your code in `ai_chat_screen.dart` (replace `YOUR_GEMINI_API_KEY`)

### Step 6: Update main.dart

Replace Firebase initialization in `main.dart`:
```dart
import 'package:flutter/foundation.dart' show kIsWeb;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "YOUR_API_KEY",
        authDomain: "YOUR_PROJECT_ID.firebaseapp.com",
        projectId: "YOUR_PROJECT_ID",
        storageBucket: "YOUR_PROJECT_ID.appspot.com",
        messagingSenderId: "YOUR_SENDER_ID",
        appId: "YOUR_APP_ID",
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
  
  runApp(MyApp());
}
```

### Step 7: Run the Application

**For Android:**
```bash
flutter run -d android
```

**For iOS:**
```bash
flutter run -d ios
```

**For Web:**
```bash
flutter run -d chrome
```

**For All Platforms:**
```bash
flutter run
```

### Step 8: Build for Production

**Android APK:**
```bash
flutter build apk --release
```

**Android App Bundle (for Play Store):**
```bash
flutter build appbundle --release
```

**iOS (on macOS):**
```bash
flutter build ios --release
```

**Web:**
```bash
flutter build web --release
```

---

## 📂 Project Structure
```
swasthyaai-health-app/
│
├── lib/
│   ├── main.dart                          # Application entry point
│   │
│   ├── screens/
│   │   ├── splash_screen.dart             # Initial splash screen
│   │   ├── auth_screen.dart               # Login/Register screen
│   │   ├── dashboard_screen.dart          # Main dashboard with all features
│   │   │
│   │   └── health_logging/
│   │       ├── mood_tracker_screen.dart       # Mood tracking interface
│   │       ├── sleep_tracker_screen.dart      # Sleep logging interface
│   │       ├── water_tracker_screen.dart      # Water intake tracker
│   │       ├── activity_tracker_screen.dart   # Physical activity logger
│   │       ├── ai_chat_screen.dart            # AI chatbot interface
│   │       ├── insights_screen.dart           # Analytics and insights
│   │       └── profile_screen.dart            # User profile management
│   │
│   └── services/
│       ├── auth_service.dart              # Authentication business logic
│       └── theme_service.dart             # App theming service
│
├── web/
│   ├── index.html                         # Web entry point (with Firebase config)
│   ├── manifest.json                      # Web app manifest
│   └── icons/                             # Web app icons
│
├── android/
│   └── app/
│       └── google-services.json           # Firebase config for Android
│
├── ios/
│   └── Runner/
│       └── GoogleService-Info.plist       # Firebase config for iOS
│
├── assets/
│   └── images/                            # App images and assets
│
├── pubspec.yaml                           # Flutter dependencies
├── README.md                              # Project documentation
└── .gitignore                             # Git ignore rules
```

---

## 🎮 How to Use

### 1️⃣ Sign Up / Login
- Open the app and you'll see the splash screen
- Choose to **Sign Up** with email/password or **Sign In with Google**
- Complete your profile information

### 2️⃣ Track Your Daily Health

**Mood Tracker:**
- Tap on the "Mood" quick action button
- Select your current mood (1-5 scale with emojis)
- Add optional notes about your feelings
- Save your mood log

**Sleep Tracker:**
- Tap "Sleep" button
- Enter the number of hours you slept
- The app automatically timestamps your entry
- View sleep patterns over time

**Water Tracker:**
- Tap "Water" button
- Track each glass of water (goal: 8 glasses/day)
- Visual progress bar shows your hydration level
- Get reminders to stay hydrated

**Activity Tracker:**
- Tap "Activity" button
- Select exercise type (walking, running, gym, yoga, etc.)
- Enter duration and estimated steps
- Track your fitness streak

### 3️⃣ View Your Dashboard
- **Streak Card:** See how many consecutive days you've been tracking
- **Progress Card:** View daily completion percentage (4 categories)
- **Health Summary:** Quick overview of today's logged data
- **AI Suggestions:** Get personalized health tips
- **Quick Actions:** One-tap access to all trackers (with bouncy animations!)
- **Recent Activity:** Timeline of your latest health logs

### 4️⃣ Chat with AI Health Coach
- Navigate to the "Chat" tab
- Ask questions like:
  - "How can I improve my sleep quality?"
  - "What's a healthy water intake for my age?"
  - "Suggest exercises for beginners"
- Get personalized recommendations based on your health data

### 5️⃣ View Insights & Analytics
- Go to "Insights" tab
- View charts and graphs of your health trends
- Understand patterns in your mood, sleep, and activity
- Identify areas for improvement

### 6️⃣ Manage Your Profile
- Tap "Profile" tab
- Update personal information
- View account details
- Manage preferences
- Sign out securely

---

## 🔐 Security & Privacy

SwasthyaAI takes your privacy seriously:

- 🔒 **End-to-End Encryption:** All data transmitted between app and servers is encrypted
- 🛡️ **Firebase Security Rules:** Database access is restricted to authenticated users only
- 🔑 **Secure Authentication:** Token-based sessions with automatic expiration
- 📊 **No Third-Party Sharing:** Your health data is never shared with third parties
- ✅ **GDPR Compliant:** Data handling follows international privacy regulations
- 🗑️ **Data Deletion:** Users can request complete data deletion at any time

### Firebase Security Rules Example:
```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /users/{userId}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

---

## 🤝 Contributing

We love contributions! Here's how you can help make SwasthyaAI better:

### Ways to Contribute:
- 🐛 Report bugs
- 💡 Suggest new features
- 📝 Improve documentation
- 🎨 Design improvements
- 💻 Code contributions

### Contribution Steps:

1. **Fork the Repository**
```bash
   # Click the "Fork" button on GitHub
```

2. **Clone Your Fork**
```bash
   git clone https://github.com/YOUR_USERNAME/swasthyaai-health-app.git
   cd swasthyaai-health-app
```

3. **Create a Feature Branch**
```bash
   git checkout -b feature/AmazingFeature
```

4. **Make Your Changes**
   - Write clean, well-documented code
   - Follow Flutter/Dart best practices
   - Test thoroughly

5. **Commit Your Changes**
```bash
   git add .
   git commit -m "Add: Amazing new feature description"
```

6. **Push to Your Fork**
```bash
   git push origin feature/AmazingFeature
```

7. **Open a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Describe your changes clearly

### Coding Guidelines:
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) style guide
- Write meaningful commit messages
- Add comments for complex logic
- Update documentation for new features
- Ensure all tests pass before submitting

---

## 🐛 Bug Reports & Feature Requests

### Found a Bug? 🐛

Please provide:
- Clear bug description
- Steps to reproduce
- Expected vs actual behavior
- Screenshots (if applicable)
- Device/browser information
- Flutter/Dart version

[Report a Bug →](https://github.com/yourusername/swasthyaai-health-app/issues/new)

### Have a Feature Idea? 💡

We'd love to hear it! Please include:
- Feature description
- Use case/problem it solves
- Mockups or examples (if available)
- Priority (low/medium/high)

[Request a Feature →](https://github.com/yourusername/swasthyaai-health-app/issues/new)

---

## 📊 Roadmap

### ✅ Completed
- [x] Core health tracking (mood, sleep, water, activity)
- [x] Firebase authentication and database
- [x] AI-powered chatbot with Gemini
- [x] Cross-platform support (Android, iOS, Web)
- [x] Dashboard with animations and gamification
- [x] Real-time data synchronization
- [x] User profile management

### 🚧 In Progress
- [ ] Advanced analytics and data visualization
- [ ] Insights screen with trend analysis
- [ ] Push notifications for health reminders

### 🔮 Future Plans
- [ ] **Wearable Integration:** Sync with Fitbit, Apple Watch, Garmin
- [ ] **Social Features:** Health challenges, friend leaderboards, social sharing
- [ ] **Nutrition Tracking:** Meal logging, calorie counter, macro tracking
- [ ] **Doctor Consultation:** In-app booking and telemedicine
- [ ] **Health Reports:** Export PDF reports for medical records
- [ ] **Medication Reminders:** Pill tracking and reminders
- [ ] **Mental Health Tools:** Meditation guides, breathing exercises
- [ ] **Multi-language Support:** Hindi, Spanish, French, etc.
- [ ] **Offline Mode:** Work without internet, sync when connected
- [ ] **Voice Commands:** Voice-based health logging
- [ ] **Smart Watch App:** Dedicated smartwatch interface
- [ ] **Premium Features:** Advanced AI coaching, personalized meal plans

---

## 🎓 Educational Use

This project was developed as part of an academic minor project at **Chandigarh University** and serves as:

- 📚 Learning resource for Flutter development
- 🏗️ Example of Firebase integration
- 🤖 Demonstration of AI/ML integration in mobile apps
- 🎨 Showcase of modern UI/UX design principles
- 📊 Case study for health tech applications

Students and developers are encouraged to:
- Study the codebase
- Learn Flutter best practices
- Understand Firebase architecture
- Explore AI integration patterns
- Use as a reference for their own projects

---

## 📜 License

This project is licensed under the **MIT License** - see the [LICENSE](LICENSE) file for details.
```
MIT License

Copyright (c) 2024 SwasthyaAI Team

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 👥 Team & Credits

### Developed By
**Sunil Nagarkoti**
- 🎓 Chandigarh University
- 📧 Email: aunilanghuasarkoti108@gmail.com
- 💼 GitHub: [@SUNILNAGARKOTI](https://github.com/SUNILNAGARKOTI)
- 🔗 LinkedIn: [Your LinkedIn Profile]

### Acknowledgments

Special thanks to:
- **Flutter Team** - For the amazing cross-platform framework
- **Firebase Team** - For reliable backend infrastructure
- **Google AI** - For Gemini API access
- **Chandigarh University** - For academic support and guidance
- **Open Source Community** - For inspiration and resources
- **Material Design Team** - For beautiful design guidelines

### Technologies & Libraries Used
- Flutter SDK
- Dart Programming Language
- Firebase Authentication
- Cloud Firestore
- Google Gemini AI
- Provider (State Management)
- HTTP Package
- Intl (Internationalization)

---

## 📞 Support & Contact

### Need Help?

- 📧 **Email:** support@swasthyaai.com
- 💬 **Discord:** [Join Community](https://discord.gg/swasthyaai)
- 🐦 **Twitter:** [@SwasthyaAI](https://twitter.com/swasthyaai)
- 📱 **WhatsApp:** [Support Group]
- 📖 **Documentation:** [Wiki](https://github.com/yourusername/swasthyaai-health-app/wiki)

### Quick Links
- [Report Bug](https://github.com/yourusername/swasthyaai-health-app/issues)
- [Request Feature](https://github.com/yourusername/swasthyaai-health-app/issues)
- [FAQs](https://github.com/yourusername/swasthyaai-health-app/wiki/FAQ)
- [Changelog](https://github.com/yourusername/swasthyaai-health-app/releases)

---

## ⭐ Show Your Support

If you find this project helpful or interesting:

- ⭐ **Star this repository** on GitHub
- 🍴 **Fork it** and build something awesome
- 📢 **Share it** with your friends and colleagues
- 🐛 **Report bugs** to help improve it
- 💡 **Suggest features** for future enhancements
- 📝 **Contribute** code or documentation

Your support motivates us to keep improving SwasthyaAI!

---

## 📈 Project Stats

![GitHub Stars](https://img.shields.io/github/stars/yourusername/swasthyaai-health-app?style=social)
![GitHub Forks](https://img.shields.io/github/forks/yourusername/swasthyaai-health-app?style=social)
![GitHub Issues](https://img.shields.io/github/issues/yourusername/swasthyaai-health-app)
![GitHub Pull Requests](https://img.shields.io/github/issues-pr/yourusername/swasthyaai-health-app)
![GitHub Last Commit](https://img.shields.io/github/last-commit/yourusername/swasthyaai-health-app)
![GitHub Code Size](https://img.shields.io/github/languages/code-size/yourusername/swasthyaai-health-app)

---

## 🌟 Version History

### v1.0.0 (Current) - Initial Release
- ✅ Core health tracking features
- ✅ AI chatbot integration
- ✅ Cross-platform support
- ✅ Firebase authentication
- ✅ Real-time data sync
- ✅ Dashboard with gamification

[View All Releases](https://github.com/yourusername/swasthyaai-health-app/releases)

---

<div align="center">

### 💙 Made with Love and Flutter

**SwasthyaAI - Empowering Healthier Lives Through Technology**

[⬆ Back to Top](#-swasthyaai---your-health-companion)

---

© 2024 SwasthyaAI. All Rights Reserved.

</div>
