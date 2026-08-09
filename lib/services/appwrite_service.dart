import 'package:appwrite/appwrite.dart';

class AppwriteService {
  late Client client;
  late Databases databases;
  late Storage storage;
  late Realtime realtime;

  static final AppwriteService _instance = AppwriteService._internal();

  static var db;
  factory AppwriteService() => _instance;

  AppwriteService._internal() {
    client = Client()
        .setEndpoint(
          'https://sgp.cloud.appwrite.io/v1',
        ) // replace with your Appwrite server
        .setProject('691b3640002b74888a02');

    databases = Databases(client);
    storage = Storage(client);
    realtime = Realtime(client);
  }
}
