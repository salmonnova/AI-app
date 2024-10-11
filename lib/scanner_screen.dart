

import "dart:isolate";
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:rock_paper_scissors_mobile/clasifier.dart';
import 'package:rock_paper_scissors_mobile/image_utils.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'classes.dart';
/// Bundles data to pass between Isolate
class IsolateData {
  CameraImage cameraImage;
  int interpreterAddress;
  SendPort responsePort;

  IsolateData({
    required this.cameraImage,
    required this.interpreterAddress,
    required this.responsePort,
  });
}

class IsolateUtils {
  static const String DEBUG_NAME = "InferenceIsolate";

  late Isolate _isolate;
  final ReceivePort _receivePort = ReceivePort();
  late SendPort _sendPort;

  SendPort get sendPort => _sendPort;

  Future<void> start() async {
    _isolate = await Isolate.spawn<SendPort>(
      entryPoint,
      _receivePort.sendPort,
      debugName: DEBUG_NAME,
    );

    _sendPort = await _receivePort.first;
  }

  static void entryPoint(SendPort sendPort) async {
    final port = ReceivePort();
    sendPort.send(port.sendPort);

    await for (final IsolateData isolateData in port) {
      Classifier classifier = Classifier();
      // Restore interpreter from main isolate
    await classifier.loadModel(interpreter: Interpreter.fromAddress(isolateData.interpreterAddress));
     
      
      
      final ans = ImageUtils.convertCameraImage(isolateData.cameraImage);
      
      DetectionClasses output = await classifier.predict(ans!);
      
      

      isolateData.responsePort.send(output);
      /*
      final convertedImage8888 = ImageUtils.convertBGRA8888ToImage(isolateData.cameraImage);
      
      DetectionClasses results8888 = await classifier.predict(convertedImage8888);
      
      isolateData.responsePort.send(results8888);
      
      final convertedImage = ImageUtils.convertYUV420ToImage(isolateData.cameraImage);
      DetectionClasses results = await classifier.predict(convertedImage);
      
      isolateData.responsePort.send(results);
      */
    }
  }

  void dispose() {
    _isolate.kill();
  }
}
class ScannerScreen extends StatefulWidget {
   final CameraDescription camera;

  const ScannerScreen({required this.camera});
  
  @override
  _ScannerScreenState createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  late CameraController cameraController;
  late CameraController cameraController_bgra8888;
  final isolateUtils = IsolateUtils();
  late Interpreter interpreter;
  final  classifier = Classifier();

  bool initialized = false;
  bool isWorking = false;
  DetectionClasses detected = DetectionClasses.nothing;
  DateTime lastShot = DateTime.now();

  @override
  void initState() {
    
    super.initState();
    
    initialize();
    
    
      
    
  }

  Future<void> initialize() async {
    //await isolateUtils.start(); // Isolateの初期化を待つ
    await classifier.loadModel();
    
    cameraController = CameraController(
      widget.camera,
      ResolutionPreset.high,
      imageFormatGroup: Platform.isIOS ? ImageFormatGroup.bgra8888 : ImageFormatGroup.yuv420, // iOSならbgra8888、それ以外はyuv420
    );

    
    
    // Create a CameraController object bgra8888
    
   // Start Inference isolate
    await isolateUtils.start();
    
    
    // Initialize the CameraController and start the camera preview
    try {
    
    await cameraController.initialize();
    
  } catch (e) {
    // エラーハンドリング
    print('Controller initialization error: $e');
  }
    // Listen for image frames
    await cameraController.startImageStream((image) {
      // Make predictions every 1 second to avoid overloading the device
      if (!isWorking) {
        processCameraImage(image);
      }
    });

    setState(() {
      initialized = true;
    });
  }
  
  
  
  Future<void> processCameraImage(CameraImage cameraImage) async {
    setState(() {
      isWorking = true;
    });

    final result = await inference(cameraImage);

    if (detected != result) {
      detected = result;
    }

    setState(() {
      isWorking = false;
    });
  }

  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Camera Demo'),
      ),
      body: initialized
          ? Column(
              children: [
                SizedBox(
                  height: MediaQuery.of(context).size.width,
                  width: MediaQuery.of(context).size.width,
                  child: CameraPreview(cameraController),
                ),
                Text(
                  "Detected: ${detected.label}",
                  style: const TextStyle(
                    fontSize: 28,
                    color: Colors.blue,
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
  
   Future<DetectionClasses> inference(CameraImage cameraImage) async {
    ReceivePort responsePort = ReceivePort();
    final isolateData = IsolateData(
      cameraImage: cameraImage,
      interpreterAddress: classifier.interpreter.address,
      responsePort: responsePort.sendPort,
    );

    isolateUtils.sendPort.send(isolateData);
    var result = await responsePort.first;

    return result;
  }
  @override
  void dispose() {
    //cameraController.stopImageStream();
    cameraController.dispose();
    isolateUtils.dispose();
    super.dispose();
  }
}
