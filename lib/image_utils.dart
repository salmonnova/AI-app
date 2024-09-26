import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;
import 'dart:io';

 const IOS_BYTES_OFFSET = 28;
class ImageUtils {
 
  static img.Image? convertCameraImage(CameraImage cameraImage) {
   
    if (Platform.isAndroid) {
      return convertYUV420ToImage(cameraImage);
    } else if (Platform.isIOS) {
      return convertBGRA8888ToImage(cameraImage);
    } else {
      return null;
    }
  }
  //アンドロイドだとここでヌルエラーでリソースリリースができなくなる
   
     
    static img.Image convertBGRA8888ToImage(CameraImage cameraImage) {
    assert(!Platform.isAndroid, 'This method should not be called on Android.');
    
    final plane = cameraImage.planes[0];

    

    img.Image ans = img.Image.fromBytes(
        width: cameraImage.width,
        height: cameraImage.height,
        bytes: plane.bytes.buffer,
        rowStride: plane.bytesPerRow,
        bytesOffset: IOS_BYTES_OFFSET,
        //lengthInBytes:1474840
        order: img.ChannelOrder.bgra
    );
    return ans;
   }
   //bytes.buffer のサイズが、width × height × 4 （BGRA8888では1ピクセルが4バイト）に一致するか確認します。
   
    // Converts a CameraImage in YUV420 format to img.Image in RGB format
  static img.Image convertYUV420ToImage(CameraImage image) {
  final int width = image.width;
  final int height = image.height;

  // 空の img.Image オブジェクトを width と height を指定して生成
  final img.Image imgImage = img.Image(width:width, height:height);

  final int uvRowStride = image.planes[1].bytesPerRow;
  final int uvPixelStride = image.planes[1].bytesPerPixel!;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int uvIndex = uvPixelStride * (x ~/ 2) + uvRowStride * (y ~/ 2);
      final int index = y * width + x;

      final int yValue = image.planes[0].bytes[index];
      final int uValue = image.planes[1].bytes[uvIndex];
      final int vValue = image.planes[2].bytes[uvIndex];

      final int rgb = yuv2rgb(yValue, uValue, vValue);
      imgImage.setPixelRgba(x, y, (rgb >> 16) & 0xff, (rgb >> 8) & 0xff, rgb & 0xff,255);
    }
  }

  return imgImage;
}
  
  /// Convert a single YUV pixel to RGB
  /// YUV ピクセルを RGB に変換する関数
static int yuv2rgb(int y, int u, int v) {
  int r = (y + v * 1436 / 1024 - 179).round();
  int g = (y - u * 46549 / 131072 + 44 - v * 93604 / 131072 + 91).round();
  int b = (y + u * 1814 / 1024 - 227).round();

  r = r.clamp(0, 255);
  g = g.clamp(0, 255);
  b = b.clamp(0, 255);

  return 0xff000000 |
      ((r << 16) & 0xff0000) |
      ((g << 8) & 0xff00) |
      (b & 0xff);
  }
}
 