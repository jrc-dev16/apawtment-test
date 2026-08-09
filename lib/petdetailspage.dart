import 'package:flutter/material.dart';

class PetDetailPage extends StatelessWidget {
  final int petId;
  final String petName;
  final String petImage;

  const PetDetailPage({
    super.key,
    required this.petId,
    required this.petName,
    required this.petImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101510),
      appBar: AppBar(backgroundColor: Colors.black, title: Text(petName)),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(petImage, width: 200, height: 200),
            const SizedBox(height: 20),
            Text(
              "Pet ID: $petId",
              style: const TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              petName,
              style: const TextStyle(color: Colors.white, fontSize: 24),
            ),
          ],
        ),
      ),
    );
  }
}
