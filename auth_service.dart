import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<Map<String, dynamic>> signUpWithEmailPassword({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      print('🚀 AuthService: Starting signup process for $email');

      // Create user account
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      print('👤 AuthService: User created with UID: ${user?.uid}');

      if (user == null) {
        print('❌ AuthService: User creation failed - user is null');
        return {
          'success': false,
          'message': 'Failed to create account - user is null'
        };
      }

      // Update display name
      try {
        await user.updateDisplayName(name);
        print('📝 AuthService: Display name updated to: $name');
      } catch (e) {
        print('⚠️ AuthService: Warning - Failed to update display name: $e');
        // Continue anyway, this is not critical
      }

      // Create user document in Firestore
      try {
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'email': email,
          'name': name,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
          'profileCompleted': false,
          'healthProfile': {
            'age': null,
            'gender': null,
            'height': null,
            'weight': null,
            'bloodGroup': null,
            'allergies': [],
            'medications': [],
          },
          'appSettings': {
            'notifications': true,
            'reminders': true,
            'dataSharing': false,
          },
        });

        print('💾 AuthService: User document created in Firestore');
      } catch (e) {
        print('⚠️ AuthService: Warning - Failed to create Firestore document: $e');
        // Continue anyway, user account was created
      }

      return {
        'success': true,
        'user': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        },
        'message': 'Account created successfully!'
      };

    } on FirebaseAuthException catch (e) {
      print('🔥 AuthService: FirebaseAuthException - ${e.code}: ${e.message}');
      String message = '';
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak. Use at least 6 characters.';
          break;
        case 'email-already-in-use':
          message = 'An account already exists with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          message = 'Email/password accounts are not enabled.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'An error occurred. Please try again.';
      }
      return {
        'success': false,
        'message': message,
        'error': e.code
      };
    } catch (e) {
      print('💥 AuthService: Unexpected error during signup: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred.',
        'error': e.toString()
      };
    }
  }

  // Sign in with email and password
  Future<Map<String, dynamic>> signInWithEmailPassword({
    required String email,
    required String password,
  }) async {
    try {
      print('🚀 AuthService: Starting signin process for $email');

      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? user = result.user;
      print('👤 AuthService: User signed in with UID: ${user?.uid}');

      if (user == null) {
        print('❌ AuthService: Signin failed - user is null');
        return {
          'success': false,
          'message': 'Login failed - user is null'
        };
      }

      // Update last login
      try {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLogin': FieldValue.serverTimestamp(),
        });
        print('💾 AuthService: Last login updated in Firestore');
      } catch (e) {
        print('⚠️ AuthService: Warning - Failed to update last login: $e');
        // Continue anyway, user is signed in
      }

      return {
        'success': true,
        'user': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
        },
        'message': 'Welcome back!'
      };

    } on FirebaseAuthException catch (e) {
      print('🔥 AuthService: FirebaseAuthException - ${e.code}: ${e.message}');
      String message = '';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'wrong-password':
          message = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'user-disabled':
          message = 'This account has been disabled.';
          break;
        case 'too-many-requests':
          message = 'Too many failed attempts. Please try again later.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        case 'invalid-credential':
          message = 'Invalid email or password. Please check your credentials.';
          break;
        default:
          message = 'Login failed. Please check your credentials.';
      }
      return {
        'success': false,
        'message': message,
        'error': e.code
      };
    } catch (e) {
      print('💥 AuthService: Unexpected error during signin: $e');
      return {
        'success': false,
        'message': 'An unexpected error occurred.',
        'error': e.toString()
      };
    }
  }

  // Sign in with Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      print('🚀 AuthService: Starting Google sign-in process');

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        print('❌ AuthService: Google sign-in cancelled by user');
        return {
          'success': false,
          'message': 'Google sign-in cancelled'
        };
      }

      print('👤 AuthService: Google user obtained: ${googleUser.email}');

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(credential);
      final User? user = result.user;

      print('🔥 AuthService: Firebase user created with UID: ${user?.uid}');

      if (user == null) {
        print('❌ AuthService: Google sign-in failed - user is null');
        return {
          'success': false,
          'message': 'Google sign-in failed - user is null'
        };
      }

      // Handle Firestore operations
      try {
        // Check if user document exists
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();

        if (!userDoc.exists) {
          print('💾 AuthService: Creating new user document for Google user');
          // Create new user document
          await _firestore.collection('users').doc(user.uid).set({
            'uid': user.uid,
            'email': user.email,
            'name': user.displayName ?? 'User',
            'photoURL': user.photoURL,
            'createdAt': FieldValue.serverTimestamp(),
            'lastLogin': FieldValue.serverTimestamp(),
            'profileCompleted': false,
            'loginProvider': 'google',
            'healthProfile': {
              'age': null,
              'gender': null,
              'height': null,
              'weight': null,
              'bloodGroup': null,
              'allergies': [],
              'medications': [],
            },
            'appSettings': {
              'notifications': true,
              'reminders': true,
              'dataSharing': false,
            },
          });
        } else {
          print('💾 AuthService: Updating existing user last login');
          // Update last login
          await _firestore.collection('users').doc(user.uid).update({
            'lastLogin': FieldValue.serverTimestamp(),
          });
        }
      } catch (e) {
        print('⚠️ AuthService: Warning - Firestore operation failed: $e');
        // Continue anyway, user is signed in
      }

      return {
        'success': true,
        'user': {
          'uid': user.uid,
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
        },
        'message': 'Google sign-in successful!'
      };

    } catch (e) {
      print('💥 AuthService: Google sign-in error: $e');
      return {
        'success': false,
        'message': 'Google sign-in error: ${e.toString()}',
        'error': e.toString()
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      print('🚀 AuthService: Starting sign out process');
      await Future.wait([
        _googleSignIn.signOut(),
        _auth.signOut(),
      ]);
      print('✅ AuthService: Sign out completed');
    } catch (e) {
      print('💥 AuthService: Sign out error: $e');
    }
  }

  // Reset password
  Future<Map<String, dynamic>> resetPassword(String email) async {
    try {
      print('🚀 AuthService: Sending password reset email to $email');
      await _auth.sendPasswordResetEmail(email: email);
      print('✅ AuthService: Password reset email sent');
      return {
        'success': true,
        'message': 'Password reset email sent! Check your inbox.'
      };
    } on FirebaseAuthException catch (e) {
      print('🔥 AuthService: Password reset error - ${e.code}: ${e.message}');
      String message = '';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email.';
          break;
        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Failed to send reset email.';
      }
      return {
        'success': false,
        'message': message,
        'error': e.code
      };
    } catch (e) {
      print('💥 AuthService: Password reset unexpected error: $e');
      return {
        'success': false,
        'message': 'An error occurred. Please try again.',
        'error': e.toString()
      };
    }
  }

  // Get user profile data
  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final User? user = currentUser;
      if (user != null) {
        DocumentSnapshot doc = await _firestore.collection('users').doc(user.uid).get();
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('💥 AuthService: Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile - THIS IS THE IMPORTANT FIX
  Future<bool> updateUserProfile(Map<String, dynamic> data) async {
    try {
      final User? user = currentUser;
      if (user != null) {
        // Update Firestore first
        await _firestore.collection('users').doc(user.uid).update(data);

        // If name is being updated, also update Firebase Auth displayName
        if (data.containsKey('name') && data['name'] != null) {
          await user.updateDisplayName(data['name']);
          await user.reload();
          print('✅ AuthService: DisplayName updated to: ${data['name']}');
        }

        print('✅ AuthService: Profile updated successfully');
        return true;
      }
      return false;
    } catch (e) {
      print('💥 AuthService: Error updating user profile: $e');
      return false;
    }
  }
}