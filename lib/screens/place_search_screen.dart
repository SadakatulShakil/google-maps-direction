import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;

class PlaceSearchScreen extends StatefulWidget {
  @override
  _PlaceSearchScreenState createState() => _PlaceSearchScreenState();
}

class _PlaceSearchScreenState extends State<PlaceSearchScreen> {
  TextEditingController _searchController = TextEditingController();
  String sessionId = '123456';
  List<dynamic> placesList =[];
  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      onChanged();
    });
  }

  void onChanged(){

    if(sessionId == null){
      setState(() {
        int id = new Random().nextInt(900000)+100000;
        sessionId = id.toString();
      });
    }
    getSuggesions(_searchController.text);
  }

  void getSuggesions(String input) async {
    String apiKey = 'AIzaSyCGA0CAQ2Z_LvRGT34jxE1Ob3wZJ-BcGUc';
    String baseUrl = 'https://maps.googleapis.com/maps/api/place/autocomplete/json';
    String request = '$baseUrl?input=$input&key=$apiKey&sessiontoken=$sessionId';

    try {
      var response = await http.get(Uri.parse(request));

      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('predictions')) {
          setState(() {
            placesList = responseData['predictions'];
          });
        } else {
          print('Error: Predictions key not found in response');
        }
      } else {
        print('Failed to load: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception during API request: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Place Search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                onChanged();
              },
              decoration: InputDecoration(
                hintText: 'Search for a place...',
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      placesList.clear();
                    });
                  },
                )
                    : null,
              ),
            ),
          ),
          Expanded(
              child: ListView.builder(
                itemCount: placesList.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    title: Text(placesList[index]['description']),
                    onTap: () {
                      Navigator.pop(context, placesList[index]['description']);
                    },
                  );
                },
              )
          ),
        ],
      ),
    );
  }

  Future<List<Location>> _searchPlaces() async {
    if (_searchController.text.isEmpty) {
      return [];
    }

    try {
      List<Location> locations = await locationFromAddress(_searchController.text);
      return locations;
    } catch (e) {
      print('Error searching places: $e');
      return [];
    }
  }

  @override
  void dispose() {
    // Dispose resources here
    super.dispose();
  }
}


