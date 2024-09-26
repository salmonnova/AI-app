import 'package:flutter/material.dart';
import 'package:rock_paper_scissors_mobile/scanner_screen.dart';
import 'package:camera/camera.dart';
Future<void> main() async  {
  WidgetsFlutterBinding.ensureInitialized();
  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();
  final firstCamera = cameras.first;


  // Get a specific camera from the list of available cameras.
  

  runApp(BottomNavigationBarApp(camera: firstCamera));
}

class BottomNavigationBarApp extends StatelessWidget {
   final CameraDescription camera;

   const BottomNavigationBarApp({required this.camera});


  
  @override
  Widget build(BuildContext context) {
    
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home:  ScannerScreen(camera: camera),
      
    );
  }
  
}

