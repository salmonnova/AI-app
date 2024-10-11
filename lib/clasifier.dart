import 'dart:typed_data';
import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:rock_paper_scissors_mobile/classes.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class Classifier {
  /// Instance of Interpreter
  late Interpreter _interpreter;

  static const String modelFile = "assets/model.tflite";

  /// Loads interpreter from asset
  Future<void> loadModel({Interpreter? interpreter}) async {
    final options = InterpreterOptions();
    if (Platform.isIOS) {
      options.addDelegate(GpuDelegate());
    }
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            modelFile,
            options: InterpreterOptions()..threads = 4,
          );

      _interpreter.allocateTensors();
      
    } catch (e) {
      print("Error while creating interpreter: $e");
      
    }
  }

  /// Gets the interpreter instance
  Interpreter get interpreter => _interpreter;

  Future<DetectionClasses> predict(img.Image image) async {
    img.Image resizedImage = img.copyResize(image, width: 150, height: 150);

    // Convert the resized image to a 1D Float32List.
    Float32List inputBytes = Float32List(1 * 150 * 150 * 3);
    int pixelIndex = 0;
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
    /*
       int pixel = resizedImage.getPixel(x, y);
        inputBytes[pixelIndex++] = img.getRed(pixel) / 127.5 - 1.0;
        inputBytes[pixelIndex++] = img.getGreen(pixel) / 127.5 - 1.0;
        inputBytes[pixelIndex++] = img.getBlue(pixel) / 127.5 - 1.0;
    */
    
      // getPixelではPixel型が返るため、それに応じた処理を行う
      img.Pixel pixel = resizedImage.getPixel(x, y);

    num red = pixel.r;
    num green = pixel.g;
    num blue = pixel.b;

      // ピクセルの値を正規化して入力バイトに設定する
      inputBytes[pixelIndex++] = red / 127.5 - 1.0;
      inputBytes[pixelIndex++] = green / 127.5 - 1.0;
      inputBytes[pixelIndex++] = blue / 127.5 - 1.0;
    
    }
    
    }

    final output = Float32List(1 * 4).reshape([1, 4]);

    // Reshape to input format specific for model. 1 item in list with pixels 150x150 and 3 layers for RGB
    final input = inputBytes.reshape([1, 150, 150, 3]);

    interpreter.run(input, output);

    final predictionResult = output[0] as List<double>;
    double maxElement = predictionResult.reduce(
      (double maxElement, double element) =>
          element > maxElement ? element : maxElement,
    );
    return DetectionClasses.values[predictionResult.indexOf(maxElement)];
  }
  void close() {
    _interpreter.close();
  }
}

