import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

void main() => runApp(const MaterialApp(
  debugShowCheckedModeBanner: false,
  home: EggplantHome(),
));

class EggplantHome extends StatefulWidget {
  const EggplantHome({super.key});

  @override
  State<EggplantHome> createState() => _EggplantHomeState();
}

class _EggplantHomeState extends State<EggplantHome> {
  bool isBengali = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          TextButton.icon(
            onPressed: () => setState(() => isBengali = !isBengali),
            icon: const Icon(Icons.language, color: Colors.deepPurple),
            label: Text(isBengali ? "English" : "বাংলা",
                style: const TextStyle(
                    color: Colors.deepPurple, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.eco, size: 80, color: Colors.green),
          const SizedBox(height: 10),
          Text(
            isBengali ? "বেগুন সুরক্ষা" : "Eggplant Shield",
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.black87),
          ),
          Text(
            isBengali
                ? "আপনার ফসলের সঠিক যত্ন নিন"
                : "Smart Care for Your Crops",
            style: const TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const Spacer(),
          _buildActionButton(
            context,
            title: isBengali ? "ছবি তুলুন" : "Take a Photo",
            subtitle: isBengali ? "ক্যামেরা ব্যবহার করুন" : "Use camera to scan",
            icon: Icons.camera_alt_rounded,
            color: Colors.deepPurple,
            onTap: () => _openScanner(context, ImageSource.camera),
          ),
          const SizedBox(height: 15),
          _buildActionButton(
            context,
            title: isBengali ? "গ্যালারি থেকে নিন" : "Pick from Gallery",
            subtitle: isBengali ? "পুরানো ছবি চেক করুন" : "Select saved images",
            icon: Icons.photo_library_rounded,
            color: Colors.teal,
            onTap: () => _openScanner(context, ImageSource.gallery),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  void _openScanner(BuildContext context, ImageSource source) {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              EggplantScanner(source: source, isBengali: isBengali)),
    );
  }

  Widget _buildActionButton(BuildContext context,
      {required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 25),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 5))
          ],
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: Colors.white),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                Text(subtitle,
                    style:
                    const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}

class EggplantScanner extends StatefulWidget {
  final ImageSource source;
  final bool isBengali;
  const EggplantScanner(
      {super.key, required this.source, required this.isBengali});

  @override
  _EggplantScannerState createState() => _EggplantScannerState();
}

class _EggplantScannerState extends State<EggplantScanner> {
  File? _image;
  String result = "";
  String description = "";
  String accuracyLabel = "0.0%";
  bool _loading = true;
  Interpreter? _interpreter;
  List<String>? _labels;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  // Initializing Model and Labels
  Future _initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/eggplant_disease_model.tflite');
      final labelsData = await DefaultAssetBundle.of(context).loadString('assets/labels.txt');
      _labels = labelsData.split('\n').where((s) => s.isNotEmpty).toList();
      _pickImage();
    } catch (e) {
      debugPrint("Initialization error: $e");
    }
  }

  Future _pickImage() async {
    final XFile? image = await ImagePicker().pickImage(source: widget.source);
    if (image == null) {
      if (mounted) Navigator.pop(context);
      return;
    }
    setState(() {
      _image = File(image.path);
    });
    _classify(File(image.path));
  }

  // Core Classification Logic
  Future _classify(File imageFile) async {
    if (_interpreter == null || _labels == null) return;

    try {
      var imageBytes = await imageFile.readAsBytes();
      img.Image? oriImage = img.decodeImage(imageBytes);
      if (oriImage == null) return;

      // Resizing to 224x224 as required by the model
      img.Image resizedImage = img.copyResize(oriImage, width: 224, height: 224);

      // Pre-processing Image: Normalizing pixel values to [-1, 1]
      var input = Float32List(1 * 224 * 224 * 3);
      int pixelIndex = 0;
      for (var y = 0; y < 224; y++) {
        for (var x = 0; x < 224; x++) {
          final pixel = resizedImage.getPixel(x, y);
          input[pixelIndex++] = (pixel.r / 127.5) - 1.0;
          input[pixelIndex++] = (pixel.g / 127.5) - 1.0;
          input[pixelIndex++] = (pixel.b / 127.5) - 1.0;
        }
      }

      var output = List<double>.filled(1 * _labels!.length, 0.0).reshape([1, _labels!.length]);

      // Running Inference
      _interpreter!.run(input.reshape([1, 224, 224, 3]), output);

      double maxScore = -1.0;
      int maxIndex = -1;
      for (var i = 0; i < _labels!.length; i++) {
        if (output[0][i] > maxScore) {
          maxScore = output[0][i];
          maxIndex = i;
        }
      }

      if (mounted) {
        setState(() {
          // Setting Confidence Threshold to 0.50 for better accuracy
          if (maxScore < 0.50) {
            result = widget.isBengali ? "শনাক্ত করা যায়নি" : "Unclear Image";
            accuracyLabel = "${(maxScore * 100).toStringAsFixed(1)}%";
            description = widget.isBengali
                ? "মডেলটি নিশ্চিত হতে পারছে না। পাতাটি পরিষ্কারভাবে ক্যামেরার সামনে ধরুন।"
                : "The model is unsure. Please capture the leaf clearly.";
          } else {
            result = _labels![maxIndex].trim();
            accuracyLabel = "${(maxScore * 100).toStringAsFixed(1)}%";

            // Disease mapping and treatments
            String normalizedLabel = result.toLowerCase();

            if (normalizedLabel.contains("healthy")) {
              description = widget.isBengali
                  ? "আপনার গাছটি সুস্থ আছে। নিয়মিত তদারকি চালিয়ে যান।"
                  : "Your plant is healthy. Keep up the regular maintenance.";
            } else if (normalizedLabel.contains("cercospora")) {
              description = widget.isBengali
                  ? "এটি সারকোস্পোরা লিফ স্পট (Cercospora Melongenae)। আক্রান্ত পাতা পুড়িয়ে ফেলুন এবং ছত্রাকনাশক স্প্রে করুন।"
                  : "Detected: Cercospora Leaf Spot. Prune and burn infected leaves; use appropriate fungicides.";
            } else if (normalizedLabel.contains("phomopsis")) {
              description = widget.isBengali
                  ? "এটি ফোমোপসিস ব্লাইট। গাছের গোড়ায় অতিরিক্ত পানি জমতে দেবেন না।"
                  : "Detected: Phomopsis Blight. Ensure proper drainage and avoid waterlogging.";
            } else if (normalizedLabel.contains("leucinodes")) {
              description = widget.isBengali
                  ? "এটি ডগা ও ফল ছিদ্রকারী পোকা। পোকা ধরা অংশ কেটে ফেলুন এবং কীটনাশক দিন।"
                  : "Detected: Fruit and Shoot Borer. Remove damaged parts and apply insecticides.";
            } else {
              description = widget.isBengali
                  ? "আক্রান্ত অবস্থা শনাক্ত হয়েছে। দ্রুত কৃষি কর্মকর্তার পরামর্শ নিন।"
                  : "Infection detected. Consult an agricultural specialist soon.";
            }
          }
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint("Classification error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
          title: Text(widget.isBengali ? "শনাক্তকরণ ফলাফল" : "Analysis Result"),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Colors.deepPurple))
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 300,
              decoration: BoxDecoration(
                image: DecorationImage(image: FileImage(_image!), fit: BoxFit.cover),
              ),
            ),
            Container(
              transform: Matrix4.translationValues(0, -30, 0),
              padding: const EdgeInsets.all(25),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(widget.isBengali ? "শনাক্তকৃত অবস্থা:" : "Condition:",
                          style: const TextStyle(fontSize: 16, color: Colors.grey)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20)),
                        child: Text("$accuracyLabel Confidence",
                            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(result,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
                  const Divider(height: 30),
                  Text(widget.isBengali ? "বিবরণ ও প্রতিকার:" : "Treatment:",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(description,
                      style: const TextStyle(fontSize: 16, color: Colors.black54, height: 1.5)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepPurple,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                      onPressed: () => Navigator.pop(context),
                      child: Text(widget.isBengali ? "আবার চেষ্টা করুন" : "Scan Another",
                          style: const TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}