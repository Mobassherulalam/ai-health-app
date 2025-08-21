import 'package:flutter/material.dart';
import 'package:country_picker/country_picker.dart';
import 'package:email_validator/email_validator.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'main_navigation.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool isDoctor = false;
  String? _errorMessage;

  Country selectedCountry = Country(
    phoneCode: "234",
    countryCode: "NG",
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: "Nigeria",
    example: "Nigeria",
    displayName: "Nigeria",
    displayNameNoCountryCode: "NG",
    e164Key: "",
  );

  List<Map<String, dynamic>> _doctors = [];
  String? _selectedDoctorId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Fetch doctors list when screen loads
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      debugPrint('Fetching doctors list...');
      final snapshot = await FirebaseService.doctorsCollection.get();
      
      setState(() {
        _doctors = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return {
            'id': doc.id,
            'name': data['name'] ?? 'Unknown Doctor',
          };
        }).toList();

        if (_doctors.isEmpty) {
          debugPrint('No doctors found in the collection.');
          _errorMessage = 'No doctors available at this time.';
        } else {
          debugPrint('Found ${_doctors.length} doctors');
          _errorMessage = null;
        }
      });
    } catch (e) {
      debugPrint('Error fetching doctors: $e');
      setState(() {
        _doctors = [];
        _errorMessage = 'Failed to load doctors. Please try again.';
      });
    }
  }

  void _onUserTypeChanged(bool? value) {
    setState(() {
      isDoctor = value!;
      _selectedDoctorId = null;
      _doctors = [];
      _errorMessage = null;
      if (!isDoctor) {
        _fetchDoctors(); // Fetch doctors when user selects "Patient"
      }
    });
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Allow patient registration without doctor selection if no doctors are available
    if (!isDoctor && _doctors.isNotEmpty && (_selectedDoctorId == null || _selectedDoctorId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a doctor.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    try {
      debugPrint('Starting registration process...');
      
      // Create auth user
      debugPrint('Creating authentication user...');
      final authResult = await AuthService.createUserWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
        isDoctor ? 'doctor' : 'patient',
      );

      if (authResult.user == null) {
        throw Exception('Failed to create user account');
      }

      final userId = authResult.user!.uid;
      final userData = {
        'id': userId,
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim().toLowerCase(),
        'phone': "+${selectedCountry.phoneCode}${_phoneController.text.trim()}",
        'createdAt': DateTime.now().toIso8601String(),
        'userType': isDoctor ? 'doctor' : 'patient',
      };

      debugPrint('Creating user document...');
      final collection = isDoctor ? 'doctors' : 'patients';
      
      // Add type-specific fields
      if (isDoctor) {
        userData['specialization'] = 'Not specified';
        userData['licenseNumber'] = 'Not specified';
      } else {
        userData['bloodType'] = 'Not specified';
        userData['age'] = '0';
        userData['assignedDoctorId'] = _selectedDoctorId ?? '';
      }

      // Save user data
      debugPrint('Saving user data to Firestore...');
      await FirebaseService.createDocument(collection, userId, userData);
      debugPrint('Registration completed successfully');

      if (mounted) {
        // Navigate to appropriate screen
        if (isDoctor) {
          Navigator.pushReplacementNamed(context, '/doctor-dashboard');
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainNavigation()),
          );
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${isDoctor ? "Doctor" : "Patient"} registered successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (e.toString().contains('email-already-in-use')) {
            _errorMessage = 'This email is already registered. Please try logging in.';
          } else if (e.toString().contains('weak-password')) {
            _errorMessage = 'Password is too weak. Please use a stronger password.';
          } else if (e.toString().contains('invalid-email')) {
            _errorMessage = 'Invalid email address. Please check your email.';
          } else {
            _errorMessage = 'Registration failed: $e';
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pushReplacementNamed(context, '/');
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back button
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                      padding: EdgeInsets.zero,
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 32),

                    // Create account text and subtitle
                    const Text(
                      'Create an account',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Securely create an account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Error message
                    if (_errorMessage != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),

                    // Full Name field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Full Name',
                          border: InputBorder.none,
                          icon: Icon(Icons.person_outline, color: Colors.grey[600]),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your name';
                          }
                          if (value.length < 2) {
                            return 'Name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Email field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: InputDecoration(
                          hintText: 'Email address',
                          border: InputBorder.none,
                          icon: Icon(Icons.email_outlined, color: Colors.grey[600]),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your email';
                          }
                          if (!EmailValidator.validate(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Phone number field with country code
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          // Country code selector
                          InkWell(
                            onTap: () {
                              showCountryPicker(
                                context: context,
                                showPhoneCode: true,
                                onSelect: (Country country) {
                                  setState(() {
                                    selectedCountry = country;
                                  });
                                },
                              );
                            },
                            child: Row(
                              children: [
                                Text(
                                  "${selectedCountry.flagEmoji} +${selectedCountry.phoneCode}",
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 1,
                                  height: 24,
                                  color: Colors.grey[300],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Phone number input
                          Expanded(
                            child: TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                hintText: 'Enter number',
                                border: InputBorder.none,
                              ),
                              keyboardType: TextInputType.phone,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                if (value.length < 10) {
                                  return 'Please enter a valid phone number';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Password field
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          border: InputBorder.none,
                          icon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: Colors.grey[600],
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Are You section
                    const Text(
                      'Are You:',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Radio<bool>(
                          value: true,
                          groupValue: isDoctor,
                          onChanged: _onUserTypeChanged,
                        ),
                        const Text('Doctor'),
                        const SizedBox(width: 32),
                        Radio<bool>(
                          value: false,
                          groupValue: isDoctor,
                          onChanged: _onUserTypeChanged,
                        ),
                        const Text('Patient'),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Doctor selection dropdown for patients
                    if (!isDoctor) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedDoctorId,
                        items: _doctors
                            .map((doctor) => DropdownMenuItem<String>(
                                  value: doctor['id'] as String,
                                  child: Text(doctor['name'] as String),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedDoctorId = value;
                          });
                        },
                        decoration: const InputDecoration(
                          labelText: 'Select Doctor',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (_doctors.isNotEmpty && (value == null || value.isEmpty)) {
                            return 'Please select a doctor';
                          }
                          return null;
                        },
                      ),
                    ],
                    const SizedBox(height: 24),

                    // Create Account button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleRegistration,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6C63FF),
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                    const SizedBox(height: 24),

                    // Login link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'I Already have an Account ',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Log in',
                            style: TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}