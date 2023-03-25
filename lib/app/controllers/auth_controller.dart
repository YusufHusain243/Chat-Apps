import 'package:chat_apps/app/data/models/user_model.dart';
import 'package:chat_apps/app/routes/app_pages.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthController extends GetxController {
  var isSkipIntro = false.obs;
  var isAuth = false.obs;

  final GoogleSignIn googleSignIn = GoogleSignIn();
  GoogleSignInAccount? currentUser;
  UserCredential? userCredential;

  UserModel user = UserModel();

  FirebaseFirestore firestore = FirebaseFirestore.instance;

  //fungsi ini dijalankan ketika di splash screen untuk melihat apakah sudah login & sudah intro atau belum
  Future<void> firstInitialized() async {
    await autoLogin().then((value) {
      if (value) {
        isAuth.value = true;
      }
    });
    await skipIntro().then((value) {
      if (value) {
        isSkipIntro.value = true;
      }
    });
  }

  Future<bool> skipIntro() async {
    final box = GetStorage();
    if (box.read("skipIntro") != null || box.read("skipIntro") == true) {
      return true;
    }
    return false;
  }

  Future<bool> autoLogin() async {
    try {
      final isSignIn = await googleSignIn.isSignedIn();
      if (isSignIn) {
        await googleSignIn
            .signInSilently()
            .then((value) => currentUser = value);
        final googleAuth = await currentUser!.authentication;

        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        await FirebaseAuth.instance
            .signInWithCredential(credential)
            .then((value) => userCredential = value);

        CollectionReference users = firestore.collection('users');

        users.doc(currentUser!.email).update({
          "lastSignInTime":
              userCredential!.user!.metadata.lastSignInTime!.toIso8601String(),
        });

        final currUser = await users.doc(currentUser!.email).get();
        final currUserData = currUser.data() as Map<String, dynamic>;

        user = UserModel(
          uid: currUserData["uid"],
          name: currUserData["name"],
          email: currUserData["email"],
          photoUrl: currUserData["photoUrl"],
          status: currUserData["status"],
          creationTime: currUserData["creationTime"],
          lastSignInTime: currUserData["lastSignInTime"],
          updatedTime: currUserData["updatedTime"],
        );
        return true;
      }
      return false;
    } catch (error) {
      return false;
    }
  }

  Future<void> login() async {
    try {
      //melakukan login
      await googleSignIn.signIn().then((value) => currentUser = value);

      //mengambil boolean apakah sudah login atau belum
      final isSignIn = await googleSignIn.isSignedIn();

      // jika sudah login
      if (isSignIn) {
        //simpan data auth ke google auth agar bisa diambil informasi didalamnya
        final googleAuth = await currentUser!.authentication;

        //set nilai credential dengan memberikan nilai idToken && access token dari google auth diatas
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
          accessToken: googleAuth.accessToken,
        );

        //masukkan data credential kedalam firebase auth
        await FirebaseAuth.instance
            .signInWithCredential(credential)
            .then((value) => userCredential = value);

        //init get storage
        final box = GetStorage();
        //jika storage skipintro sudah ada
        if (box.read("skipIntro") != null) {
          //maka remove datanya
          box.remove("skipIntro");
        }
        //dan lakukan set data ulang
        box.write("skipIntro", true);

        //masukkan data ke firestore
        CollectionReference users = firestore.collection('users');

        final checkUser = await users.doc(currentUser!.email).get();

        if (checkUser.data() == null) {
          users.doc(currentUser!.email).set({
            "uid": userCredential!.user!.uid,
            "name": currentUser!.displayName,
            "email": currentUser!.email,
            "photoUrl": currentUser!.photoUrl ?? "noimage",
            "status": "",
            "creationTime":
                userCredential!.user!.metadata.creationTime!.toIso8601String(),
            "lastSignInTime": userCredential!.user!.metadata.lastSignInTime!
                .toIso8601String(),
            "updatedTime": DateTime.now().toIso8601String(),
          });
        } else {
          users.doc(currentUser!.email).update({
            "lastSignInTime": userCredential!.user!.metadata.lastSignInTime!
                .toIso8601String(),
          });
        }

        final currUser = await users.doc(currentUser!.email).get();
        final currUserData = currUser.data() as Map<String, dynamic>;

        user = UserModel(
          uid: currUserData["uid"],
          name: currUserData["name"],
          email: currUserData["email"],
          photoUrl: currUserData["photoUrl"],
          status: currUserData["status"],
          creationTime: currUserData["creationTime"],
          lastSignInTime: currUserData["lastSignInTime"],
          updatedTime: currUserData["updatedTime"],
        );

        isAuth.value = true;
        Get.offAllNamed(Routes.HOME);
      }
    } catch (error) {
      print(error);
    }
  }

  Future<void> logout() async {
    await googleSignIn.disconnect();
    await googleSignIn.signOut();
    Get.offAllNamed(Routes.LOGIN);
  }
}
