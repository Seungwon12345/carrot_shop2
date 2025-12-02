// lib/services/firebase_storage_service.dart

import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;
  static const String _itemsStoragePath = 'items';

  static Future<String> uploadImage(File imageFile, String itemId) async {
    // ... (업로드 로직)
    final String fileName = imageFile.path.split('/').last;
    final String path = '$_itemsStoragePath/$itemId/$fileName';
    final Reference ref = _storage.ref().child(path);

    try {
      final UploadTask uploadTask = ref.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      return await snapshot.ref.getDownloadURL();
    } on FirebaseException catch (e) {
      rethrow;
    }
  }

  static Future<List<String>> uploadMultipleImages(List<File> imageFiles, String itemId) async {
    List<Future<String>> uploadFutures = [];
    for (var imageFile in imageFiles) {
      uploadFutures.add(uploadImage(imageFile, itemId));
    }
    return await Future.wait(uploadFutures);
  }
}
