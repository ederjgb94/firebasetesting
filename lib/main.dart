import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity/connectivity.dart';
import 'package:faker/faker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebasetesting/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:image_picker/image_picker.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();

  var db = FirebaseFirestore.instance;
  await db.waitForPendingWrites();
  db.settings = const Settings(
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  /** SETUP emulators */
  // FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);
  // FirebaseDatabase.instance.useDatabaseEmulator('10.0.2.2', 9000);
  // await FirebaseStorage.instance.useStorageEmulator('10.0.2.2', 9199);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var db = FirebaseFirestore.instance;
  var rl = FirebaseDatabase.instance.ref();

  Future<bool> isConnected() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _incrementCounter() async {
    var db = FirebaseFirestore.instance;
    var time = FieldValue.serverTimestamp();

    await db.collection('users').add(
      {
        'first': faker.person.firstName(),
        'last': faker.person.lastName(),
        'timestamp': time,
      },
    );
    await rlUpdate();
  }

  // Future obtener() async {
  //   Source CACHE = Source.cache;
  //   Source SERVER = Source.server;

  //   FirebaseFirestore db = FirebaseFirestore.instance;
  //   var userCache = await db
  //       .collection("users")
  //       .orderBy("timestamp", descending: true)
  //       .limit(1)
  //       .get(
  //         GetOptions(source: CACHE),
  //       );
  //   return userCache.docs;
  // }

  Future testobtener() async {
    Source cache = Source.cache;
    Source server = Source.server;

    FirebaseFirestore db = FirebaseFirestore.instance;

    var box = GetStorage();

    var cacheTime = box.read('cacheTime');

    if (cacheTime == null) {
      var profesoresServer = await db
          .collection("ciclos")
          .doc('2023 - 3 Otoño')
          .collection('profesores')
          .orderBy('lastUpdate', descending: true)
          .get(
            GetOptions(source: server),
          );
      await box.write('cacheTime',
          profesoresServer.docs.first.data()['lastUpdate'].toDate().toString());
      if (kDebugMode) {
        print('Mi cache es null, DateStart: ${box.read('cacheTime')}');
      }
      return profesoresServer.docs;
    } else {
      if (kDebugMode) {
        print('Mi cache actual: $cacheTime');
      }

      //actualiza mi cache
      //si no hay internet no se actualiza
      if (await isConnected()) {
        var profesoresLinea = await db
            .collection('ciclos')
            .doc('2023 - 3 Otoño')
            .collection('profesores')
            .where(
              'lastUpdate',
              isGreaterThan: cacheTime,
            )
            .get(
              GetOptions(source: server),
            );
        if (kDebugMode) {
          print('se trajeron de linea: ${profesoresLinea.docs.length}');
        }
        if (profesoresLinea.docs.isNotEmpty) {
          await box.write(
              'cacheTime',
              profesoresLinea.docs.first
                  .data()['lastUpdate']
                  .toDate()
                  .toString());
        }
      }

      //obtengo mi cache con datos actualizados
      var profesores = await db
          .collection('ciclos')
          .doc('2023 - 3 Otoño')
          .collection('profesores')
          .orderBy('lastUpdate', descending: true)
          .get(
            GetOptions(source: cache),
          );
      if (kDebugMode) {
        print('se trajeron del cache: ${profesores.docs.length}');
      }
      //actualizo cache

      return profesores.docs;
    }
  }

  Future<void> rlUpdate() async {
    if (await isConnected()) {
      await rl.set(
        {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
  }

  Future<XFile?> getPhoto() async {
    final ImagePicker picker = ImagePicker();

    final XFile? photo = await picker.pickImage(source: ImageSource.camera);

    if (photo != null) {
      return photo;
    }
    return null;
  }

  Widget listaUsers() {
    return FutureBuilder(
      future: testobtener(),
      builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
        if (snapshot.hasData) {
          return ListView.builder(
            itemCount: snapshot.data.length,
            itemBuilder: (BuildContext context, int index) {
              return ListTile(
                onTap: () async {
                  var profesor = snapshot.data[index];
                  await db
                      .collection('ciclos')
                      .doc('2023 - 3 Otoño')
                      .collection('profesores')
                      .doc(profesor.id)
                      .update(
                    {
                      'nombre': 'updated ${faker.person.firstName()}',
                      'lastUpdate': FieldValue.serverTimestamp(),
                    },
                  );
                  await rlUpdate();

                  //prueba de eliminar...
                  // var user = snapshot.data[index];
                  // await db.collection('users').doc(user.id).delete();
                  // setState(() {});
                },
                title: Text('$index ${snapshot.data[index].data()['nombre']}'),
                subtitle: Text(snapshot.data[index]
                    .data()['lastUpdate']
                    .toDate()
                    .toString()),
              );
            },
          );
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: isConnected(),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return StreamBuilder<DatabaseEvent>(
              stream: () {
                var ref = FirebaseDatabase.instance.ref();
                return ref.onChildChanged;
              }(),
              builder: (BuildContext context,
                  AsyncSnapshot<DatabaseEvent> snapshot) {
                if (snapshot.hasError) {
                  return const Text('Error al obtener los datos');
                }

                return listaUsers();
              },
            );
          } else if (snapshot.hasData && snapshot.data == false) {
            //no tengo internet y muestro mi cache lista
            return listaUsers();
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            onPressed: () async {
              var photo = await getPhoto();
              final storage = FirebaseStorage.instance.ref();
              if (photo != null) {
                await storage
                    .child(
                        'images/${DateTime.now().millisecondsSinceEpoch}.jpg')
                    .putFile(
                      File(photo.path),
                    );
              }
            },
            child: const Icon(
              Icons.image,
            ),
          ),
          const SizedBox(height: 15),
          FloatingActionButton(
            onPressed: _incrementCounter,
            tooltip: 'Increment',
            child: const Icon(Icons.add),
          ),
        ],
      ),
    );
  }
}
