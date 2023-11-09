import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/directions.dart' as direction;
import 'package:location/location.dart' as loc;
import 'dart:math' show cos, sqrt, asin;

import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Maps',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MapView(),
    );
  }
}

class MapView extends StatefulWidget {
  @override
  _MapViewState createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final loc.Location location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  CameraPosition _initialLocation = CameraPosition(target: LatLng(0.0, 0.0));
  late GoogleMapController mapController;

  late Position _currentPosition;
  String _currentAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  String _startAddress = '';
  String _destinationAddress = '';
  String? _placeDistance;
  String? _estimatedTime ;
  double destinationLatitude = 0.0;
  double destinationLongitude = 0.0;
  Set<Marker> markers = {};
  late PolylinePoints polylinePoints;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  List<PolylineWayPoint> polylineWaypoints = [];

  final _scaffoldKey = GlobalKey<ScaffoldState>();

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        decoration: new InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          contentPadding: EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  // Method for retrieving the current location
  _getCurrentLocation() async {
    LocationPermission permission;
    permission = await Geolocator.requestPermission();
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        _currentPosition = position;
        print('CURRENT POS: $_currentPosition');
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      await _getAddress();
    }).catchError((e) {
      print(e);
    });
  }

  // Method for retrieving the address
  _getAddress() async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition.latitude, _currentPosition.longitude);

      Placemark place = p[0];

      setState(() {
        _currentAddress =
        "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
        startAddressController.text = _currentAddress;
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print('Error during geocoding: $e');
    }
  }

  // Method for calculating the distance between two places

  // Future<bool> _calculateDistance() async {
  //   try {
  //         // Retrieving placemarks from addresses
  //     print('Destination Address: $_destinationAddress');
  //         List<Location> startPlacemark = await locationFromAddress(_startAddress);
  //         List<Location> destinationPlacemark =
  //         await locationFromAddress(_destinationAddress);
  //
  //         // Use the retrieved coordinates of the current position,
  //         // instead of the address if the start position is user's
  //         // current position, as it results in better accuracy.
  //         double startLatitude = _startAddress == _currentAddress
  //             ? _currentPosition.latitude
  //             : startPlacemark[0].latitude;
  //
  //         double startLongitude = _startAddress == _currentAddress
  //             ? _currentPosition.longitude
  //             : startPlacemark[0].longitude;
  //
  //          destinationLatitude = destinationPlacemark[0].latitude;
  //          destinationLongitude = destinationPlacemark[0].longitude;
  //          print("ffff: "+ destinationLatitude.toString()+".........."+"gggg: "+destinationLongitude.toString());
  //
  //         String startCoordinatesString = '($startLatitude, $startLongitude)';
  //         String destinationCoordinatesString =
  //             '($destinationLatitude, $destinationLongitude)';
  //
  //         // Start Location Marker
  //         Marker startMarker = Marker(
  //           markerId: MarkerId(startCoordinatesString),
  //           position: LatLng(startLatitude, startLongitude),
  //           infoWindow: InfoWindow(
  //             title: 'Start $startCoordinatesString',
  //             snippet: _startAddress,
  //           ),
  //           icon: BitmapDescriptor.defaultMarker,
  //         );
  //
  //         // Destination Location Marker
  //         Marker destinationMarker = Marker(
  //           markerId: MarkerId(destinationCoordinatesString),
  //           position: LatLng(destinationLatitude, destinationLongitude),
  //           infoWindow: InfoWindow(
  //             title: 'Destination $destinationCoordinatesString',
  //             snippet: _destinationAddress,
  //           ),
  //           icon: BitmapDescriptor.defaultMarker,
  //         );
  //
  //         // Adding the markers to the list
  //         markers.add(startMarker);
  //         markers.add(destinationMarker);
  //
  //         print(
  //           'START COORDINATES: ($startLatitude, $startLongitude)',
  //         );
  //         print(
  //           'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
  //         );
  //
  //         // Calculating to check that the position relative
  //         // to the frame, and pan & zoom the camera accordingly.
  //         double miny = (startLatitude <= destinationLatitude)
  //             ? startLatitude
  //             : destinationLatitude;
  //         double minx = (startLongitude <= destinationLongitude)
  //             ? startLongitude
  //             : destinationLongitude;
  //         double maxy = (startLatitude <= destinationLatitude)
  //             ? destinationLatitude
  //             : startLatitude;
  //         double maxx = (startLongitude <= destinationLongitude)
  //             ? destinationLongitude
  //             : startLongitude;
  //
  //         double southWestLatitude = miny;
  //         double southWestLongitude = minx;
  //
  //         double northEastLatitude = maxy;
  //         double northEastLongitude = maxx;
  //
  //         // Accommodate the two locations within the
  //         // camera view of the map
  //         mapController.animateCamera(
  //           CameraUpdate.newLatLngBounds(
  //             LatLngBounds(
  //               northeast: LatLng(northEastLatitude, northEastLongitude),
  //               southwest: LatLng(southWestLatitude, southWestLongitude),
  //             ),
  //             100.0,
  //           ),
  //         );
  //
  //         await _createPolylines(startLatitude, startLongitude, destinationLatitude,
  //             destinationLongitude);
  //
  //     direction.DirectionsResponse result = await directionsApi.directionsWithLocation(
  //       direction.Location(lat: startLatitude, lng: startLongitude),
  //       direction.Location(lat: destinationLatitude, lng: destinationLongitude),
  //       travelMode: direction.TravelMode.driving,
  //       trafficModel: direction.TrafficModel.bestGuess, // Use bestGuess for estimated traffic conditions
  //     );
  //
  //     double totalDistance = 0.0;
  //     num estimatedTimeInSeconds = result.routes[0].legs[0].duration.value;
  //
  //     if (polylineCoordinates.length >= 2) {
  //       for (int i = 0; i < polylineCoordinates.length - 1; i++) {
  //         totalDistance += _coordinateDistance(
  //           polylineCoordinates[i].latitude,
  //           polylineCoordinates[i].longitude,
  //           polylineCoordinates[i + 1].latitude,
  //           polylineCoordinates[i + 1].longitude,
  //         );
  //       }
  //     }
  //
  //
  //     const double averageSpeed = 12.0; // in meters per second
  //     int estimatedTimeWithoutTraffic =
  //     ((totalDistance * 1000) / averageSpeed).round();
  //
  //     // Format the duration
  //     Duration duration = Duration(seconds: estimatedTimeInSeconds.toInt());
  //
  //     setState(() {
  //       _placeDistance = totalDistance.toStringAsFixed(2);
  //       _estimatedTime = formatDuration(duration);
  //       print('DISTANCE: $_placeDistance km');
  //     });
  //
  //     return true;
  //   } catch (e) {
  //     print('Error during geocoding: $e');
  //   }
  //   return false;
  // }


  Future<bool> _calculateDistance() async {
    try {
      final directionsApi = direction.GoogleMapsDirections(apiKey: 'AIzaSyCGA0CAQ2Z_LvRGT34jxE1Ob3wZJ-BcGUc');
      // Retrieving placemarks from addresses
      List<Location> startPlacemark = await locationFromAddress(_startAddress);
      List<Location> destinationPlacemark =
      await locationFromAddress(_destinationAddress);

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition.longitude
          : startPlacemark[0].longitude;

       destinationLatitude = destinationPlacemark[0].latitude;
       destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      // Start Location Marker
      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(
          title: 'Start $startCoordinatesString',
          snippet: _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Destination Location Marker
      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Adding the markers to the list
      markers.add(startMarker);
      markers.add(destinationMarker);

      print(
        'START COORDINATES: ($startLatitude, $startLongitude)',
      );
      print(
        'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
      );

      // Calculating to check that the position relative
      // to the frame, and pan & zoom the camera accordingly.
      double miny = (startLatitude <= destinationLatitude)
          ? startLatitude
          : destinationLatitude;
      double minx = (startLongitude <= destinationLongitude)
          ? startLongitude
          : destinationLongitude;
      double maxy = (startLatitude <= destinationLatitude)
          ? destinationLatitude
          : startLatitude;
      double maxx = (startLongitude <= destinationLongitude)
          ? destinationLongitude
          : startLongitude;

      double southWestLatitude = miny;
      double southWestLongitude = minx;

      double northEastLatitude = maxy;
      double northEastLongitude = maxx;

      // Accommodate the two locations within the
      // camera view of the map
      mapController.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            northeast: LatLng(northEastLatitude, northEastLongitude),
            southwest: LatLng(southWestLatitude, southWestLongitude),
          ),
          100.0,
        ),
      );

      await _createPolylines(startLatitude, startLongitude, destinationLatitude,
          destinationLongitude);

      direction.DirectionsResponse result = await directionsApi.directionsWithLocation(
              direction.Location(lat: startLatitude, lng: startLongitude),
              direction.Location(lat: destinationLatitude, lng: destinationLongitude),
              travelMode: direction.TravelMode.driving,
              trafficModel: direction.TrafficModel.bestGuess, // Use bestGuess for estimated traffic conditions
            );
      //int estimatedTimeInSeconds = result.routes[0].legs[0].duration.value.toInt();
      print("kkkk: "+ result.status);
      double totalDistance = 0.0;

      // Calculating the total distance by adding the distance
      // between small segments
      for (int i = 0; i < polylineCoordinates.length - 1; i++) {
        totalDistance += _coordinateDistance(
          polylineCoordinates[i].latitude,
          polylineCoordinates[i].longitude,
          polylineCoordinates[i + 1].latitude,
          polylineCoordinates[i + 1].longitude,
        );
      }
      const double averageSpeed = 15.0; // in meters per second
      int estimatedTimeWithoutTraffic =
         ((totalDistance * 1000) / averageSpeed).round();

      // Format the duration
      Duration duration = Duration(seconds: estimatedTimeWithoutTraffic);

      setState(() {
        _placeDistance = totalDistance.toStringAsFixed(2);
        _estimatedTime = formatDuration(duration);
        print('DISTANCE: $_placeDistance km');
        //print('timeWithTraffic: $estimatedTimeInSeconds');
        print('timeWithOutTraffic: $estimatedTimeWithoutTraffic');
      });

      return true;
    } catch (e) {
      print(e);
    }
    return false;
  }

  // Helper method to format duration as HH:MM:SS
  String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '${twoDigits(duration.inHours)}:$twoDigitMinutes:$twoDigitSeconds';
  }

  // Formula for calculating distance between two coordinates
  // https://stackoverflow.com/a/54138876/11910277
  double _coordinateDistance(lat1, lon1, lat2, lon2) {
    var p = 0.017453292519943295;
    var c = cos;
    var a = 0.5 -
        c((lat2 - lat1) * p) / 2 +
        c(lat1 * p) * c(lat2 * p) * (1 - c((lon2 - lon1) * p)) / 2;
    return 12742 * asin(sqrt(a));
  }

  // Create the polylines for showing the route between two places
  _createPolylines(
      double startLatitude,
      double startLongitude,
      double destinationLatitude,
      double destinationLongitude,
      ) async {
    polylinePoints = PolylinePoints();
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      'AIzaSyCGA0CAQ2Z_LvRGT34jxE1Ob3wZJ-BcGUc', // Google Maps API Key
      PointLatLng(startLatitude, startLongitude),
      PointLatLng(destinationLatitude, destinationLongitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('poly');
    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;
    return Container(
      height: height,
      width: width,
      child: Scaffold(
        key: _scaffoldKey,
        body: Stack(
          children: <Widget>[
            // Map View
            GoogleMap(
              markers: Set<Marker>.from(markers),
              initialCameraPosition: _initialLocation,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              zoomGesturesEnabled: true,
              zoomControlsEnabled: false,
              polylines: Set<Polyline>.of(polylines.values),
              onMapCreated: (GoogleMapController controller) {
                mapController = controller;
              },
            ),
            // Show zoom buttons
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    ClipOval(
                      child: Material(
                        color: Colors.blue.shade100, // button color
                        child: InkWell(
                          splashColor: Colors.blue, // inkwell color
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Icon(Icons.add),
                          ),
                          onTap: () {
                            mapController.animateCamera(
                              CameraUpdate.zoomIn(),
                            );
                          },
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    ClipOval(
                      child: Material(
                        color: Colors.blue.shade100, // button color
                        child: InkWell(
                          splashColor: Colors.blue, // inkwell color
                          child: SizedBox(
                            width: 50,
                            height: 50,
                            child: Icon(Icons.remove),
                          ),
                          onTap: () {
                            mapController.animateCamera(
                              CameraUpdate.zoomOut(),
                            );
                          },
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
            // Show the place input fields & button for
            // showing the route
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.all(
                        Radius.circular(20.0),
                      ),
                    ),
                    width: width * 0.9,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'Places',
                            style: TextStyle(fontSize: 20.0),
                          ),
                          SizedBox(height: 10),
                          _textField(
                              label: 'Start',
                              hint: 'Choose starting point',
                              prefixIcon: Icon(Icons.looks_one),
                              suffixIcon: IconButton(
                                icon: Icon(Icons.my_location),
                                onPressed: () {
                                  startAddressController.text = _currentAddress;
                                  _startAddress = _currentAddress;
                                },
                              ),
                              controller: startAddressController,
                              focusNode: startAddressFocusNode,
                              width: width,
                              locationCallback: (String value) {
                                setState(() {
                                  _startAddress = value;
                                });
                              }),
                          SizedBox(height: 10),
                          _textField(
                              label: 'Destination',
                              hint: 'Choose destination',
                              prefixIcon: Icon(Icons.looks_two),
                              controller: destinationAddressController,
                              focusNode: desrinationAddressFocusNode,
                              width: width,
                              locationCallback: (String value) {
                                setState(() {
                                  _destinationAddress = value;
                                });
                              }),
                          SizedBox(height: 10),
                          Visibility(
                            visible: _placeDistance == null ? false : true,
                            child: Text(
                              'DISTANCE: $_placeDistance km',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Visibility(
                            visible: _placeDistance == null ? false : true,
                            child: Text(
                              'Time to complete: $_estimatedTime',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(height: 5),
                          ElevatedButton(
                            onPressed: (_startAddress != '' &&
                                _destinationAddress != '')
                                ? () async {
                              startAddressFocusNode.unfocus();
                              desrinationAddressFocusNode.unfocus();
                              setState(() {
                                if (markers.isNotEmpty) markers.clear();
                                if (polylines.isNotEmpty)
                                  polylines.clear();
                                if (polylineCoordinates.isNotEmpty)
                                  polylineCoordinates.clear();
                                _placeDistance = null;
                              });

                              _calculateDistance().then((isCalculated) {
                                if (isCalculated) {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Distance Calculated Sucessfully'),
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Error Calculating Distance'),
                                    ),
                                  );
                                }
                              });
                            }
                                : null,
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                'Show Route'.toUpperCase(),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 20.0,
                                ),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              primary: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20.0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Show current location button
            //journey start and stop button
            SafeArea(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.all(
                        Radius.circular(20.0),
                      ),
                    ),
                    width: width * 0.9,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0, bottom: 10.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: ElevatedButton(onPressed: (){
                              _getLiveLocation();
                            },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Start Journey',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.0,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                primary: Colors.green,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10.0),
                            child: ElevatedButton(onPressed: (){
                              _cancelLiveLocation();
                            },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(
                                  'Stop Journey',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20.0,
                                  ),
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                primary: Colors.red,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20.0),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                  child: ClipOval(
                    child: Material(
                      color: Colors.orange.shade100, // button color
                      child: InkWell(
                        splashColor: Colors.orange, // inkwell color
                        child: SizedBox(
                          width: 56,
                          height: 56,
                          child: Icon(Icons.my_location),
                        ),
                        onTap: () {
                          mapController.animateCamera(
                            CameraUpdate.newCameraPosition(
                              CameraPosition(
                                target: LatLng(
                                  _currentPosition.latitude,
                                  _currentPosition.longitude,
                                ),
                                zoom: 18.0,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

// Modify the _getLiveLocation method
  Future<void> _getLiveLocation() async {
    // Launch navigation
    launchNavigation();

    _locationSubscription = location.onLocationChanged.handleError((onError) {
      print(onError);
      _locationSubscription?.cancel();
      setState(() {
        _locationSubscription = null;
      });
    }).listen((loc.LocationData currentLocation) async {
      print(
          'live update ==>' + currentLocation.latitude.toString() + ' || ' + currentLocation.longitude.toString());

      // Check if the destination is reached
      double distance = _coordinateDistance(
        currentLocation.latitude,
        currentLocation.longitude,
        destinationLatitude,
        destinationLongitude,
      );

      if (distance < 0.1) {
        // Stop location updates
        _cancelLiveLocation();
        Navigator.of(context).pop();
      }
    });
  }

// Method to launch navigation
  void launchNavigation() async {
    final url = 'google.navigation:q=$_destinationAddress';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      throw 'Could not launch $url';
    }
  }
  Future<void> _cancelLiveLocation() async{
      _locationSubscription?.cancel();
      setState(() {
        _locationSubscription = null;
      });
  }

}