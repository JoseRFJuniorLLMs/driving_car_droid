import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_vision/flutter_vision.dart';
import 'dart:typed_data';
import 'dart:async';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ObjectDetectionScreen(),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  CameraController? cameraController;
  FlutterVision vision = FlutterVision();
  List<CameraDescription>? cameras;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    initializeCamera();
  }

  Future<void> initializeCamera() async {
    cameras = await availableCameras();
    cameraController = CameraController(cameras![0], ResolutionPreset.high);
    await cameraController!.initialize();
    setState(() {});

    await vision.loadYoloModel(
      labels: 'assets/labels.txt',
      modelPath: 'assets/yolov8n.tflite',
      modelVersion: "yolov8",
      quantization: false,
      numThreads: 1,
      useGpu: false,
    );

    cameraController!.startImageStream((CameraImage image) {
      if (!isDetecting) {
        isDetecting = true;
        detectObjects(image);
      }
    });
  }

  Future<void> detectObjects(CameraImage image) async {
    try {
      final imageBytes = concatenatePlanes(image.planes);

      // Certifique-se de que imageHeight e imageWidth não sejam nulos
      final imageHeight = image.height;
      final imageWidth = image.width;

      final result = await vision.yoloOnImage(
        bytesList: imageBytes,
        imageHeight: imageHeight,
        imageWidth: imageWidth,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5,
      );

      print(result);
      isDetecting = false;
    } catch (e) {
      print("Error detecting objects: $e");
      isDetecting = false;
    }
  }

  Uint8List concatenatePlanes(List<Plane> planes) {
    int totalBytes = planes.fold(0, (sum, plane) => sum + plane.bytes.length);
    Uint8List allBytes = Uint8List(totalBytes);
    int offset = 0;

    for (Plane plane in planes) {
      allBytes.setRange(offset, offset + plane.bytes.length, plane.bytes);
      offset += plane.bytes.length;
    }
    return allBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Real-time Object Detection'),
      ),
      body: Column(
        children: [
          if (cameraController != null && cameraController!.value.isInitialized)
            AspectRatio(
              aspectRatio: cameraController!.value.aspectRatio,
              child: CameraPreview(cameraController!),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    cameraController?.dispose();
    vision.closeYoloModel();
    super.dispose();
  }
}
