import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/google_auth_service.dart';
import '../widgets/success_animation.dart';
import '../../../../core/utils/validation_utils.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/password_field.dart';

class LoginScreen extends HookConsumerWidget {
  const LoginScreen({super.key});

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email';
      case 'wrong-password':
        return 'Incorrect password';
      case 'invalid-email':
        return 'Please enter a valid RVCE email address';
      case 'user-disabled':
        return 'This account has been disabled';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later';
      case 'invalid-role':
        return 'This account is not authorized for the selected login type';
      default:
        return 'Authentication failed: ${e.message}';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final emailController = useTextEditingController();
    final passwordController = useTextEditingController();
    final isLoading = useState(false);
    final errorMessage = useState<String?>(null);
    final isSecurityLogin = useState(false);
    final isPasswordVisible = useState(false);

    final formKey = useMemoized(() => GlobalKey<FormState>());
    final emailError = useState<String?>(null);
    final passwordError = useState<String?>(null);

    useEffect(() {
      void validateEmail() {
        emailError.value = ValidationUtils.validateEmail(emailController.text);
      }

      void validatePassword() {
        passwordError.value = ValidationUtils.validateLoginPassword(
          passwordController.text,
        );
      }

      emailController.addListener(validateEmail);
      passwordController.addListener(validatePassword);

      return () {
        emailController.removeListener(validateEmail);
        passwordController.removeListener(validatePassword);
      };
    }, [emailController, passwordController]);

    Future<void> handleLogin() async {
      if (emailError.value != null || passwordError.value != null) {
        errorMessage.value = 'Please fix the errors before continuing';
        return;
      }

      try {
        isLoading.value = true;
        errorMessage.value = null;
        final email = emailController.text.trim();

        // Validate email domain first
        final emailError = ValidationUtils.validateEmail(email);
        if (emailError != null) {
          throw FirebaseAuthException(
            code: 'invalid-email',
            message: emailError,
          );
        }

        // Simple authentication based on login screen type
        await ref.read(authProvider.notifier).signInWithEmailAndPassword(
              email: email,
              password: passwordController.text,
              role: isSecurityLogin.value ? 'Security' : 'Host',
            );

        if (context.mounted) {
          // Navigate based on which login screen we're on
          if (isSecurityLogin.value) {
            // If logging in through security screen, always go to main screen
            context.go('/register');
          } else {
            // If logging in through host screen, always go to host dashboard
            context.go('/host');
          }
        }
      } on FirebaseAuthException catch (e) {
        errorMessage.value = _handleAuthException(e);
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    Future<void> handleGoogleSignIn() async {
      try {
        isLoading.value = true;
        errorMessage.value = null;

        // Validate email domain for Google Sign-In
        final googleUser = await GoogleSignIn().signIn();
        if (googleUser == null) {
          throw 'Sign in cancelled';
        }
        if (!googleUser.email.endsWith('@rvce.edu.in')) {
          throw 'Only RVCE email addresses (@rvce.edu.in) are allowed';
        }

        final userCredential = await ref
            .read(googleAuthServiceProvider.notifier)
            .signInWithGoogle(role: 'Host');

        if (context.mounted) {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, _, __) => SuccessAnimation(
                onAnimationComplete: () => context.go('/host'),
              ),
            ),
          );
        }
      } on FirebaseAuthException catch (e) {
        errorMessage.value = _handleAuthException(e);
      } catch (e) {
        errorMessage.value = e.toString();
      } finally {
        isLoading.value = false;
      }
    }

    return Scaffold(
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                const Color(0xFF3A81F1),
                const Color(0xFF3A81F1).withOpacity(0.8),
              ],
            ),
          ),
          child: CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'RVCE Visitor Management System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isSecurityLogin.value ? 'Security Login' : 'Host Login',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 32),
                      Card(
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Image.asset(
                                'assets/images/college_logo.png',
                                height: 100,
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                'Welcome Back',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              if (errorMessage.value != null) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .errorContainer
                                        .withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .error
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color:
                                            Theme.of(context).colorScheme.error,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: SelectableText(
                                          errorMessage.value!,
                                          style: TextStyle(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .error,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              const SizedBox(height: 24),
                              Form(
                                key: formKey,
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: emailController,
                                      decoration: InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon: const Icon(Icons.email),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        errorText: emailError.value,
                                      ),
                                      keyboardType: TextInputType.emailAddress,
                                      textInputAction: TextInputAction.next,
                                      onChanged: (_) => emailError.value =
                                          ValidationUtils.validateEmail(
                                        emailController.text,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    PasswordField(
                                      controller: passwordController,
                                      labelText: 'Password',
                                      errorText: passwordError.value,
                                      onChanged: (_) => passwordError.value =
                                          ValidationUtils.validateLoginPassword(
                                              passwordController.text),
                                      onFieldSubmitted: (_) => handleLogin(),
                                    ),
                                    const SizedBox(height: 24),
                                    FilledButton(
                                      onPressed:
                                          isLoading.value ? null : handleLogin,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                            vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: isLoading.value
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(isSecurityLogin.value
                                                    ? Icons.security
                                                    : Icons.login),
                                                const SizedBox(width: 8),
                                                Text(isSecurityLogin.value
                                                    ? 'SECURITY LOGIN'
                                                    : 'HOST LOGIN'),
                                              ],
                                            ),
                                    ),
                                    if (!isSecurityLogin.value) ...[
                                      const SizedBox(height: 24),
                                      const Row(
                                        children: [
                                          Expanded(child: Divider()),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Text('OR'),
                                          ),
                                          Expanded(child: Divider()),
                                        ],
                                      ),
                                      const SizedBox(height: 24),
                                      OutlinedButton(
                                        onPressed: isLoading.value
                                            ? null
                                            : handleGoogleSignIn,
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          backgroundColor: Colors.white,
                                        ),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Image.asset(
                                              'assets/images/google_logo.png',
                                              height: 24,
                                            ),
                                            const SizedBox(width: 8),
                                            const Text('Sign in with Google'),
                                          ],
                                        ),
                                      ),
                                      if (!isSecurityLogin.value)
                                        TextButton(
                                          onPressed: () =>
                                              context.push('/signup'),
                                          child: const Text(
                                              "Don't have an account? Sign Up"),
                                        ),
                                    ],
                                    TextButton(
                                      onPressed: () {
                                        isSecurityLogin.value =
                                            !isSecurityLogin.value;
                                        emailController.clear();
                                        passwordController.clear();
                                        errorMessage.value = null;
                                      },
                                      child: Text(
                                        isSecurityLogin.value
                                            ? 'Switch to Host Login'
                                            : 'Switch to Security Login',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
