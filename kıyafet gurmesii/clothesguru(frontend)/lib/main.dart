import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';



void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const GenderSelectionPage(),
    );
  }
}

class GenderSelectionPage extends StatelessWidget {
  const GenderSelectionPage({super.key});

  void _navigateToSelectionPage(BuildContext context, String gender) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SelectionPage(gender: gender),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Cinsiyet Seçimi"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            
            const Text(
              "Cinsiyetinizi Seçiniz",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => _navigateToSelectionPage(context, "Kadın"),
              child: Image.asset(
                'assets/images/woman.png',
                width: 300,
                height: 150,
              ),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () => _navigateToSelectionPage(context, "Erkek"),
              child: Image.asset(
                'assets/images/man.png',
                width: 300,
                height: 150,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionPage extends StatelessWidget {
  final String gender;
  const SelectionPage({super.key, required this.gender});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Welcome"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Cinsiyet: $gender",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ImageUploadPage(gender: gender),
                  ),
                );
              },
              child: Image.asset(
                'assets/images/image_upload.png', 
                width: 150,
                height: 150,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              "OR",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TextInputPage(gender: gender), 
                  ),
                );
              },
              child: Image.asset(
                'assets/images/text_write.png', 
                width: 150,
                height: 150,
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ImageUploadPage extends StatefulWidget {
  final String gender; // Cinsiyet bilgisini almak için değişken

  const ImageUploadPage({super.key, required this.gender});

  @override
  State<ImageUploadPage> createState() => _ImageUploadPageState();
}

class _ImageUploadPageState extends State<ImageUploadPage> {
  XFile? _selectedImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _selectedImage = pickedFile;
    });
  }

  Future<void> _submitImage(BuildContext context) async {
    if (_selectedImage != null) {
      try {
        final file = File(_selectedImage!.path);

        
        final uri = Uri.parse('http://192.168.1.38:5000/upload_image');
        final request = http.MultipartRequest('POST', uri);
        request.files.add(await http.MultipartFile.fromPath('image', file.path));
        request.fields['gender'] = widget.gender;
        final streamedResponse = await request.send();
        final response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          final analysisResult = jsonResponse['image_analysis'];
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecommendationPage(
                recommendation: analysisResult,
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bir hata oluştu, lütfen tekrar deneyin.")),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Sunucuya bağlanırken bir hata oluştu.")),
        );
        print("Hata: $e");
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Lütfen bir resim seçiniz.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Görsel Yükle"),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                  image: _selectedImage != null
                      ? DecorationImage(
                          image: FileImage(File(_selectedImage!.path)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: _selectedImage == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add, size: 40, color: Colors.black),
                          SizedBox(height: 10),
                          Text(
                            "Resim Seç",
                            style: TextStyle(fontSize: 14, color: Colors.black54),
                          ),
                        ],
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_selectedImage != null)
              ElevatedButton(
                onPressed: () => _submitImage(context),
                child: const Text("Gönder"),
              ),
          ],
        ),
      ),
    );
  }
}


class TextInputPage extends StatefulWidget {
  final String gender;  

  const TextInputPage({super.key, required this.gender});

  @override
  State<TextInputPage> createState() => _TextInputPageState();
}

class _TextInputPageState extends State<TextInputPage> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false; 

  
  Future<void> _fetchRecommendation(String inputText) async {
    setState(() {
      _isLoading = true; 
    });

    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.38:5000/recommend'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'topic': inputText,
          'gender': widget.gender, 
          'location': 'İstanbul', 
        }),
      );

      if (response.statusCode == 200) {
          String decodedBody = utf8.decode(response.bodyBytes);
          print('Response Body (Decoded): $decodedBody');

          final Map<String, dynamic> parsedJson = json.decode(decodedBody);
          String finalAnswer = parsedJson['final_answer'] ?? '';

          
          String formattedText = finalAnswer.split('\n').map((line) {
            if (line.contains('**') && line.trim().startsWith('**') && line.trim().endsWith('**')) {
              return '\n${line.trim()}\n';
            } else {
              return line;
            }
          }).join('\n');

          
          formattedText = formattedText.replaceAll("\\n", "\n");

          print('Formatted Text: $formattedText');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecommendationPage(
              recommendation: formattedText.isNotEmpty ? formattedText : 'No recommendation available',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bir hata oluştu. Tekrar deneyin.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sunucuya bağlanırken bir hata oluştu.')),
      );
    } finally {
      setState(() {
        _isLoading = false; // Yükleme göstergesi kapanıyor
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Metin Yaz"),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 10),
                  Text(
                    "En iyi sonuçlar hazırlanıyor...",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Text(
                    "Cinsiyet: ${widget.gender}", // Cinsiyet bilgisini burada gösteriyoruz
                    style: const TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Lütfen metni giriniz:",
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _controller,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: "Metninizi buraya yazın...",
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      _fetchRecommendation(_controller.text);
                    },
                    child: const Text("Kaydet"),
                  ),
                ],
              ),
            ),
    );
  }
}



class RecommendationPage extends StatelessWidget {
  final String recommendation;

  const RecommendationPage({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Önerimiz"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Center(
            child: Text(
              recommendation,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
