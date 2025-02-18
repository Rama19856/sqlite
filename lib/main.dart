import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart' as path_provider;
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'sql_helper.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter SQLite Demo',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> _items = [];
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();
  List<String?> _images = [null, null, null]; // List untuk 3 gambar
  bool _isLoading = true;
  late Database _database;

  @override
  void initState() {
    super.initState();
    initializeDatabase().then((_) {
      _refreshItems();
    });
  }

  // Initialize the database
  Future<void> initializeDatabase() async {
    final databasesPath = await getDatabasesPath();
    final dbPath = path.join(databasesPath, 'kindacode.db');

    _database = await openDatabase(
      dbPath,
      version: 2, // Increment version untuk memicu onUpgrade
      onCreate: (Database db, int version) async {
        await db.execute("""
          CREATE TABLE items(
            id INTEGER PRIMARY KEY AUTOINCREMENT NOT NULL,
            title TEXT NOT NULL,
            description TEXT,
            image1 TEXT,
            image2 TEXT,
            image3 TEXT,
            link TEXT,
            createdAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
          )
        """);
      },
      onUpgrade: (Database db, int oldVersion, int newVersion) async {
        if (oldVersion < 2) {
          // Tambahkan kolom baru jika versi database lebih lama dari 2
          await db.execute('ALTER TABLE items ADD COLUMN image1 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN image2 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN image3 TEXT;');
          await db.execute('ALTER TABLE items ADD COLUMN link TEXT;');
        }
      },
    );
  }

  // Membaca semua data dari database
  void _refreshItems() async {
    final data = await SQLHelper.getItems();
    setState(() {
      _items = data;
      _isLoading = false;
    });
  }

  // Function to pick image
  Future<void> _pickImage(int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      File compressedImage = await compressImage(File(image.path));
      String permanentImagePath = await saveImageToPermanentDirectory(compressedImage.path);

      setState(() {
        _images[index] = permanentImagePath;
      });
    }
  }

  // Function to compress image
  Future<File> compressImage(File file) async {
    final dir = await path_provider.getTemporaryDirectory();
    final targetPath = path.join(dir.absolute.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    var result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 88, // adjust the quality as needed
    );

    print('Compressed image size: ${result!.lengthSync()} bytes');

    return result!;
  }

  // Function to save image to permanent directory
  Future<String> saveImageToPermanentDirectory(String imagePath) async {
    final directory = await path_provider.getApplicationDocumentsDirectory();
    final fileName = path.basename(imagePath);
    final newPath = path.join(directory.path, fileName);

    final imageFile = File(imagePath);
    final newImageFile = await imageFile.copy(newPath);

    return newImageFile.path;
  }

  // Show the form to add or edit item
  void _showForm(int? id) async {
    if (id != null) {
      final existingItem = _items.firstWhere((element) => element['id'] == id);
      _titleController.text = existingItem['title'];
      _descriptionController.text = existingItem['description'];
      _linkController.text = existingItem['link'] ?? '';
      _images = [
        existingItem['image1'],
        existingItem['image2'],
        existingItem['image3'],
      ];
    } else {
      _titleController.clear();
      _descriptionController.clear();
      _linkController.clear();
      _images = [null, null, null];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Penting untuk memungkinkan bottom sheet menyesuaikan tinggi
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom), // Hindari keyboard yang menutupi input
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                TextField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                TextField(
                  controller: _linkController,
                  decoration: const InputDecoration(labelText: 'Link (URL)'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 10),
                for (int i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ElevatedButton(
                          onPressed: () => _pickImage(i),
                          child: Text('Pilih Gambar ${i + 1}'),
                        ),
                        if (_images[i] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Image.file(
                              File(_images[i]!),
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    if (_titleController.text.isNotEmpty) {
                      try {
                        if (id == null) {
                          await SQLHelper.createItem(
                            _titleController.text,
                            _descriptionController.text,
                            _images[0],
                            _images[1],
                            _images[2],
                            _linkController.text,
                          );
                        } else {
                          await SQLHelper.updateItem(
                            id,
                            _titleController.text,
                            _descriptionController.text,
                            _images[0],
                            _images[1],
                            _images[2],
                            _linkController.text,
                          );
                        }
                        _refreshItems();
                        Navigator.of(context).pop();
                      } catch (e) {
                        print("Error saat menambah/memperbarui item: $e");
                      }
                    }
                  },
                  child: Text(id == null ? 'Add Item' : 'Update Item'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Delete an item
  void _deleteItem(int id) async {
    await SQLHelper.deleteItem(id);
    _refreshItems();
  }

  // Fungsi untuk membuka URL
  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SQLite CRUD Example')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _items.length,
              itemBuilder: (context, index) {
                final item = _items[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int i = 0; i < 3; i++)
                          if (item['image${i + 1}'] != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 4.0),
                              child: Image.file(
                                File(item['image${i + 1}']),
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                      ],
                    ),
                    title: Text(item['title']),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item['description']),
                        if (item['link'] != null && item['link'].isNotEmpty)
                          InkWell(
                            child: Text(
                              item['link'],
                              style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                            ),
                            onTap: () => _launchURL(item['link']),
                          ),
                        Text(
                          'Ditambahkan/Diubah: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.parse(item['createdAt']))}',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => _showForm(item['id']),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => _deleteItem(item['id']),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showForm(null),
        child: const Icon(Icons.add),
      ),
    );
  }
}
