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

/*YOLOｖ５ */
/*import 'dart:math';
import 'dart:ui';

import 'package:image/image.dart' as image_lib;
import 'package:tflite_flutter/tflite_flutter.dart';


import 'package:flutter_yolov5_app/utils/logger.dart';
import 'package:flutter_yolov5_app/data/entity/recognition.dart';

class Classifier {
  Classifier({
    Interpreter? interpreter,
  }) {
    loadModel(interpreter);
  }
  late Interpreter? _interpreter;
  Interpreter? get interpreter => _interpreter;

  static const String modelFileName = 'coco128.tflite';

  /// image size into interpreter
  static const int inputSize = 640;

  ImageProcessor? imageProcessor;
  late List<List<int>> _outputShapes;
  late List<TfLiteType> _outputTypes;

  static const int clsNum = 80;
  static const double objConfTh = 0.80;
  static const double clsConfTh = 0.80;

  /// load interpreter
  Future<void> loadModel(Interpreter? interpreter) async {
    try {
      _interpreter = interpreter ??
          await Interpreter.fromAsset(
            modelFileName,
            options: InterpreterOptions()..threads = 4,
          );
      final outputTensors = _interpreter!.getOutputTensors();
      _outputShapes = [];
      _outputTypes = [];
      for (final tensor in outputTensors) {
        _outputShapes.add(tensor.shape);
        _outputTypes.add(tensor.type);
      }
    } on Exception catch (e) {
      logger.warning(e.toString());
    }
  }

  /// image pre process
  TensorImage getProcessedImage(TensorImage inputImage) {
    final padSize = max(inputImage.height, inputImage.width);

    imageProcessor ??= ImageProcessorBuilder()
        .add(
      ResizeWithCropOrPadOp(
        padSize,
        padSize,
      ),
    )
        .add(
      ResizeOp(
        inputSize,
        inputSize,
        ResizeMethod.BILINEAR,
      ),
    )
        .build();
    return imageProcessor!.process(inputImage);
  }
  //正規化
  List<Recognition> predict(image_lib.Image image) {
    if (_interpreter == null) {
      return [];
    }

    var inputImage = TensorImage.fromImage(image);
    inputImage = getProcessedImage(inputImage);

    ///  normalize from zero to one
    List<double> normalizedInputImage = [];
    for (var pixel in inputImage.tensorBuffer.getDoubleList()) {
      normalizedInputImage.add(pixel / 255.0);
    }
    var normalizedTensorBuffer = TensorBuffer.createDynamic(TfLiteType.float32);
    normalizedTensorBuffer.loadList(normalizedInputImage, shape: [inputSize, inputSize, 3]);

    final inputs = [normalizedTensorBuffer.buffer];

    /// tensor for results of inference
    final outputLocations = TensorBufferFloat(_outputShapes[0]);
    final outputs = {
      0: outputLocations.buffer,
    };

    _interpreter!.runForMultipleInputs(inputs, outputs);

    /// make recognition
    final recognitions = <Recognition>[];
    List<double> results = outputLocations.getDoubleList();
    for (var i = 0; i < results.length; i += (5 + clsNum)) {
      // check obj conf
      if (results[i + 4] < objConfTh) continue;

      /// check cls conf
      // double maxClsConf = results[i + 5];
      double maxClsConf = results.sublist(i + 5, i + 5 + clsNum - 1).reduce(max);
      if (maxClsConf < clsConfTh) continue;

      /// add detects
      // int cls = 0;
      int cls = results.sublist(i + 5, i + 5 + clsNum - 1).indexOf(maxClsConf) % clsNum;
      Rect outputRect = Rect.fromCenter(
        center: Offset(
          results[i] * inputSize,
          results[i + 1] * inputSize,
        ),
        width: results[i + 2] * inputSize,
        height: results[i + 3] * inputSize,
      );
      Rect transformRect = imageProcessor!.inverseTransformRect(outputRect, image.height, image.width);

      recognitions.add(
          Recognition(i, cls, maxClsConf, transformRect)
      );
    }
    return recognitions;
  }
}
*/