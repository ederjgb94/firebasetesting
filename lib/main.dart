import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:faker/faker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebasetesting/firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await GetStorage.init();

  // var db = FirebaseFirestore.instance;
  // await db.waitForPendingWrites();
  // db.settings = const Settings(
  //   persistenceEnabled: true,
  //   cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  //   host: '10.0.2.2:8080',
  // );

  FirebaseFirestore.instance.useFirestoreEmulator('10.0.2.2', 8080);

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
  final int _counter = 0;
  var db = FirebaseFirestore.instance;

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
    setState(() {});
  }

  Future obtener() async {
    Source CACHE = Source.cache;
    Source SERVER = Source.server;

    FirebaseFirestore db = FirebaseFirestore.instance;
    var userCache = await db
        .collection("users")
        .orderBy("timestamp", descending: true)
        .limit(1)
        .get(
          GetOptions(source: CACHE),
        );
    return userCache.docs;
  }

  Future testobtener() async {
    Source CACHE = Source.cache;
    Source SERVER = Source.server;

    FirebaseFirestore db = FirebaseFirestore.instance;

    var box = GetStorage();

    var cacheTime = box.read('cacheTime');

    if (cacheTime == null) {
      var usersServer = await db
          .collection("users")
          .orderBy("timestamp", descending: true)
          .get(
            GetOptions(source: SERVER),
          );
      await box.write('cacheTime',
          usersServer.docs.first.data()['timestamp'].toDate().toString());
      print(box.read('cacheTime').toString());
      return usersServer.docs;
    } else {
      var cacheTime = box.read('cacheTime');
      print(cacheTime.toString());
      await db
          .collection('users')
          .where(
            'timestamp',
            isGreaterThan: Timestamp.fromDate(DateTime.parse(cacheTime)),
          )
          .get(
            GetOptions(source: SERVER),
          )
          .then(
              (value) => print('se trajeron del server: ${value.docs.length}'));

      var users = await db
          .collection('users')
          .orderBy('timestamp', descending: true)
          .get(
            GetOptions(source: CACHE),
          );
      await box.write('cacheTime',
          users.docs.first.data()['timestamp'].toDate().toString());
      return users.docs;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: FutureBuilder(
        future: testobtener(),
        builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
          if (snapshot.hasData) {
            return ListView.builder(
              itemCount: snapshot.data.length,
              itemBuilder: (BuildContext context, int index) {
                return ListTile(
                  onTap: () async {
                    var user = snapshot.data[index];
                    await db.collection('users').doc(user.id).update(
                      {
                        'first': 'updated ${faker.person.firstName()}',
                      },
                    );
                    // var user = snapshot.data[index];
                    // await db.collection('users').doc(user.id).delete();
                    setState(() {});
                  },
                  title: Text(snapshot.data[index].data()['first']),
                  subtitle: Text(snapshot.data[index]
                      .data()['timestamp']
                      .toDate()
                      .toString()),
                );
              },
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
