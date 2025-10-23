import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'device_setup_screen.dart';
import 'home_screen.dart';
import '../services/mqtt_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  VideoPlayerController? _videoController;
  bool _isVideoMode = false;
  bool _videoInitialized = false;
  
  late AnimationController _circuitController;
  late AnimationController _dragonController;
  late AnimationController _transformController;
  late AnimationController _logoController;
  late AnimationController _glowController;
  
  late Animation<double> _circuitAnimation;
  late Animation<double> _dragonFadeAnimation;
  late Animation<double> _dragonScaleAnimation;
  late Animation<double> _fireAnimation;
  late Animation<double> _transformAnimation;
  late Animation<double> _logoFadeAnimation;
  late Animation<double> _glowAnimation;
  
  bool _showDragon = false;
  bool _showFire = false;
  bool _showTransform = false;
  bool _showLogo = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initVideo();
  }
  
  Future<void> _initVideo() async {
    try {
      print('🎬 Initializing video splash...');
      print('🖥️ Platform: ${Platform.operatingSystem}');
      
      // Check if platform supports video playback well
      final isVideoSupported = !kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isWindows);
      
      if (!isVideoSupported) {
        print('⚠️ Video not well supported on this platform, using animated splash');
        throw Exception('Platform does not support video well');
      }
      
      // Try to load custom video with NetworkVideoPlayerController for better compatibility
      // Use asset path for local video
      _videoController = VideoPlayerController.asset(
        'assets/splash_video.mp4',
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: false,
          allowBackgroundPlayback: false,
        ),
      );
      
      print('📂 Loading video from assets/splash_video.mp4');
      
      // Initialize with timeout
      await _videoController!.initialize().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Video initialization timeout after 10 seconds');
        },
      );
      
      if (!_videoController!.value.isInitialized) {
        throw Exception('Video controller not initialized properly');
      }
      
      print('✅ Video initialized successfully');
      print('📹 Video duration: ${_videoController!.value.duration}');
      print('📐 Aspect ratio: ${_videoController!.value.aspectRatio}');
      print('📏 Video size: ${_videoController!.value.size}');
      
      if (mounted) {
        setState(() {
          _isVideoMode = true;
          _videoInitialized = true;
        });
        
        // Set looping to false
        await _videoController!.setLooping(false);
        
        // Set volume
        await _videoController!.setVolume(1.0);
        
        // Add listener before playing
        _videoController!.addListener(_videoListener);
        
        // Small delay before playing
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Play video
        await _videoController!.play();
        
        print('▶️ Video play command sent');
        print('🎥 Is playing: ${_videoController!.value.isPlaying}');
        
        // Verify playback started after a moment
        await Future.delayed(const Duration(milliseconds: 500));
        if (!_videoController!.value.isPlaying) {
          print('⚠️ Video not playing after play command, retrying...');
          await _videoController!.play();
        }
      }
    } catch (e, stackTrace) {
      // Video not found or error, use animated splash
      print('⚠️ Video splash not available, using animated splash: $e');
      print('Stack trace: $stackTrace');
      
      if (mounted) {
        setState(() {
          _isVideoMode = false;
          _videoInitialized = false;
        });
        _startAnimation();
      }
    }
  }
  
  void _videoListener() {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return;
    }
    
    final position = _videoController!.value.position;
    final duration = _videoController!.value.duration;
    final isPlaying = _videoController!.value.isPlaying;
    
    // Debug log every second
    if (position.inSeconds % 1 == 0) {
      print('⏱️ Video position: ${position.inSeconds}s / ${duration.inSeconds}s, Playing: $isPlaying');
    }
    
    // Check if video completed
    if (position >= duration && duration.inSeconds > 0) {
      print('🏁 Video completed, navigating to home...');
      _videoController!.removeListener(_videoListener);
      _navigateToHome();
    }
  }

  void _initAnimations() {
    // Scene 1: Circuit animation (0s - 1.5s)
    _circuitController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _circuitAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _circuitController, curve: Curves.easeInOut),
    );

    // Scene 2: Dragon appears (1.5s - 2.5s)
    _dragonController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _dragonFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _dragonController, curve: Curves.easeIn),
    );
    _dragonScaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _dragonController, curve: Curves.elasticOut),
    );

    // Fire effect
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fireAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    // Scene 3: Transformation (2.5s - 3.5s)
    _transformController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _transformAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _transformController, curve: Curves.easeInOutCubic),
    );

    // Scene 4: Logo reveal (3.5s - 4s)
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _logoFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeIn),
    );
    
    _glowAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOut),
    );
  }

  void _startAnimation() async {
    // Scene 1: Circuit summon (0s - 1.5s)
    await Future.delayed(const Duration(milliseconds: 100));
    _circuitController.forward();
    
    // Scene 2: Dragon appears (1.5s - 2.5s)
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() => _showDragon = true);
    _dragonController.forward();
    
    // Dragon roar with fire (2.0s)
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showFire = true);
    _glowController.forward();
    
    // Scene 3: Transformation (2.5s - 3.5s)
    await Future.delayed(const Duration(milliseconds: 500));
    setState(() => _showTransform = true);
    _transformController.forward();
    
    // Scene 4: Logo reveal (3.5s - 4s)
    await Future.delayed(const Duration(milliseconds: 1000));
    setState(() => _showLogo = true);
    _logoController.forward();
    
    // Hold logo for a moment then navigate
    await Future.delayed(const Duration(milliseconds: 1500));
    _navigateToHome();
  }
  
  Future<void> _navigateToHome() async {
    if (!mounted) return;
    
    // Check if there's a saved device ID
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceId = prefs.getString('last_device_id');
    
    if (lastDeviceId != null && lastDeviceId.isNotEmpty) {
      // Try to auto-connect to last used device
      print('📱 Auto-connecting to last device: $lastDeviceId');
      
      final mqttService = MQTTService();
      
      try {
        // Use switchDevice for clean connection
        await mqttService.switchDevice(lastDeviceId);
        await Future.delayed(const Duration(seconds: 2));
        
        if (mqttService.isConnected) {
          print('✅ Auto-connected successfully to: $lastDeviceId');
          // Navigate to home
          if (mounted) {
            Navigator.of(context).pushReplacement(
              PageRouteBuilder(
                pageBuilder: (context, animation, secondaryAnimation) => const HomeScreen(),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
                transitionDuration: const Duration(milliseconds: 500),
              ),
            );
          }
          return;
        }
      } catch (e) {
        print('⚠️ Auto-connect failed: $e');
      }
    }
    
    // No saved device or connection failed, go to setup
    print('🔧 Navigating to device setup');
    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => const DeviceSetupScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 500),
        ),
      );
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _circuitController.dispose();
    _dragonController.dispose();
    _transformController.dispose();
    _logoController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E27), // Dark navy background
      body: _isVideoMode && _videoInitialized
          ? _buildVideoSplash()
          : _buildAnimatedSplash(),
    );
  }
  
  Widget _buildVideoSplash() {
    if (_videoController == null) {
      print('❌ Video controller is null');
      return _buildAnimatedSplash();
    }
    
    if (!_videoController!.value.isInitialized) {
      print('⏳ Video not initialized yet, showing loading...');
      return Container(
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFE63946),
              ),
              SizedBox(height: 20),
              Text(
                'Loading...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    print('🎬 Building video splash screen');
    print('📹 Video is playing: ${_videoController!.value.isPlaying}');
    
    return Stack(
      children: [
        // Black background
        Container(color: Colors.black),
        
        // Video player covering full screen with cover fit
        SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildAnimatedSplash() {
    return Stack(
        children: [
          // Background circuits
          AnimatedBuilder(
            animation: _circuitAnimation,
            builder: (context, child) {
              return CustomPaint(
                painter: CircuitPainter(_circuitAnimation.value),
                size: Size.infinite,
              );
            },
          ),
          
          // Center content
          Center(
            child: SizedBox(
              width: 300,
              height: 300,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Dragon (Scene 2)
                  if (_showDragon && !_showTransform)
                    AnimatedBuilder(
                      animation: _dragonController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _dragonFadeAnimation.value * (1 - (_transformAnimation.value)),
                          child: Transform.scale(
                            scale: _dragonScaleAnimation.value,
                            child: _buildDragonShape(),
                          ),
                        );
                      },
                    ),
                  
                  // Fire effect
                  if (_showFire)
                    AnimatedBuilder(
                      animation: _fireAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _fireAnimation.value * 0.8,
                          child: _buildFireEffect(),
                        );
                      },
                    ),
                  
                  // Transformation (Scene 3)
                  if (_showTransform)
                    AnimatedBuilder(
                      animation: _transformAnimation,
                      builder: (context, child) {
                        return CustomPaint(
                          painter: TransformationPainter(_transformAnimation.value),
                          size: const Size(250, 250),
                        );
                      },
                    ),
                  
                  // Final Logo (Scene 4)
                  if (_showLogo)
                    AnimatedBuilder(
                      animation: _logoFadeAnimation,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _logoFadeAnimation.value,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Glow effect
                              if (_glowAnimation.value > 0)
                                Container(
                                  width: 280,
                                  height: 280,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE63946).withOpacity(
                                          0.3 * (1 - _glowAnimation.value)
                                        ),
                                        blurRadius: 60 * (1 - _glowAnimation.value),
                                        spreadRadius: 20 * (1 - _glowAnimation.value),
                                      ),
                                    ],
                                  ),
                                ),
                              // Logo image with error handling
                              Image.asset(
                                'assets/logo.png',
                                width: 250,
                                height: 250,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  // Fallback to icon.png if logo.png not found
                                  return Image.asset(
                                    'assets/logo.png',
                                    width: 250,
                                    height: 250,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      // Fallback to custom painted logo
                                      return _buildFallbackLogo();
                                    },
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
          
          // Loading indicator at bottom
          if (_showLogo)
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _logoFadeAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: _logoFadeAnimation.value,
                    child: Column(
                      children: [
                        const Text(
                          'WORKSHOP NAGA TEAM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: 200,
                          child: LinearProgressIndicator(
                            backgroundColor: Colors.white.withOpacity(0.1),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Color(0xFFE63946),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
    );
  }

  Widget _buildDragonShape() {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFE63946).withOpacity(0.8),
            const Color(0xFFE63946).withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
      child: CustomPaint(
        painter: DragonHeadPainter(),
      ),
    );
  }

  Widget _buildFallbackLogo() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF0A0E27),
        border: Border.all(
          color: const Color(0xFFE63946),
          width: 3,
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dragon icon as fallback
          CustomPaint(
            size: const Size(200, 200),
            painter: DragonHeadPainter(),
          ),
          // Text around
          Positioned(
            bottom: 40,
            child: Column(
              children: const [
                Text(
                  'WORKSHOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'NAGA TEAM',
                  style: TextStyle(
                    color: Color(0xFFE63946),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFireEffect() {
    return Container(
      width: 250,
      height: 250,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            const Color(0xFFFFBE0B).withOpacity(0.6),
            const Color(0xFFE63946).withOpacity(0.4),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

// Circuit painter for background
class CircuitPainter extends CustomPainter {
  final double progress;
  
  CircuitPainter(this.progress);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Draw circuit lines from bottom
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final startX = centerX + math.cos(angle) * 100 * progress;
      final startY = centerY + math.sin(angle) * 100 * progress;
      final endX = centerX + math.cos(angle) * 400;
      final endY = centerY + math.sin(angle) * 400;
      
      paint.color = (i % 2 == 0 
        ? const Color(0xFFE63946) 
        : Colors.white
      ).withOpacity(0.3 * progress);
      
      canvas.drawLine(
        Offset(startX, startY),
        Offset(
          startX + (endX - startX) * progress,
          startY + (endY - startY) * progress,
        ),
        paint,
      );
      
      // Draw nodes
      canvas.drawCircle(
        Offset(startX, startY),
        3,
        Paint()..color = paint.color,
      );
    }
  }
  
  @override
  bool shouldRepaint(CircuitPainter oldDelegate) => progress != oldDelegate.progress;
}

// Dragon head simplified painter
class DragonHeadPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE63946)
      ..style = PaintingStyle.fill;
    
    final outlinePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final path = Path();
    
    // Simplified dragon head shape
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Head
    path.moveTo(centerX - 40, centerY);
    path.quadraticBezierTo(centerX - 50, centerY - 30, centerX - 20, centerY - 50);
    path.quadraticBezierTo(centerX + 20, centerY - 60, centerX + 40, centerY - 40);
    path.quadraticBezierTo(centerX + 60, centerY - 20, centerX + 50, centerY + 10);
    path.quadraticBezierTo(centerX + 40, centerY + 30, centerX + 20, centerY + 20);
    path.lineTo(centerX - 40, centerY);
    
    canvas.drawPath(path, paint);
    canvas.drawPath(path, outlinePaint);
    
    // Eye glow
    canvas.drawCircle(
      Offset(centerX + 20, centerY - 20),
      5,
      Paint()..color = const Color(0xFFFFBE0B),
    );
  }
  
  @override
  bool shouldRepaint(DragonHeadPainter oldDelegate) => false;
}

// Transformation painter
class TransformationPainter extends CustomPainter {
  final double progress;
  
  TransformationPainter(this.progress);
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    
    // Draw transforming particles
    for (int i = 0; i < 20; i++) {
      final angle = (i / 20) * 2 * math.pi;
      final radius = 50 + (progress * 80);
      final x = centerX + math.cos(angle) * radius;
      final y = centerY + math.sin(angle) * radius;
      
      paint.color = (i % 2 == 0 
        ? const Color(0xFFE63946) 
        : Colors.white
      ).withOpacity(1 - progress);
      
      canvas.drawCircle(Offset(x, y), 3, paint);
    }
    
    // Draw circuit lines emerging
    for (int i = 0; i < 12; i++) {
      final angle = (i / 12) * 2 * math.pi;
      final startRadius = 60;
      final endRadius = 60 + (progress * 40);
      
      paint.color = const Color(0xFF6C757D).withOpacity(progress);
      
      canvas.drawLine(
        Offset(
          centerX + math.cos(angle) * startRadius,
          centerY + math.sin(angle) * startRadius,
        ),
        Offset(
          centerX + math.cos(angle) * endRadius,
          centerY + math.sin(angle) * endRadius,
        ),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(TransformationPainter oldDelegate) => progress != oldDelegate.progress;
}
