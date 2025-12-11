import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const FlightTrackerApp());
}

class FlightTrackerApp extends StatelessWidget {
  const FlightTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flight Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightBlue),
        useMaterial3: true,
      ),
      home: const FlightTrackerHomePage(),
    );
  }
}

class FlightTrackerHomePage extends StatefulWidget {
  const FlightTrackerHomePage({super.key});

  @override
  State<FlightTrackerHomePage> createState() => _FlightTrackerHomePageState();
}

class _FlightTrackerHomePageState extends State<FlightTrackerHomePage> {
  final TextEditingController _minLatController =
      TextEditingController(text: '24.396308'); // US lower 48-ish min lat
  final TextEditingController _maxLatController =
      TextEditingController(text: '49.384358');
  final TextEditingController _minLonController =
      TextEditingController(text: '-124.848974');
  final TextEditingController _maxLonController =
      TextEditingController(text: '-66.93457');
  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _clientSecretController = TextEditingController();

  List<FlightState> _flights = [];
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _minLatController.dispose();
    _maxLatController.dispose();
    _minLonController.dispose();
    _maxLonController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    super.dispose();
  }

  Future<void> _fetchFlights() async {
    final lamin = double.tryParse(_minLatController.text.trim());
    final lamax = double.tryParse(_maxLatController.text.trim());
    final lomin = double.tryParse(_minLonController.text.trim());
    final lomax = double.tryParse(_maxLonController.text.trim());

    if ([lamin, lamax, lomin, lomax].contains(null)) {
      setState(() {
        _error = 'Please enter valid numeric bounds.';
      });
      return;
    }

    final clientId = _clientIdController.text.trim();
    final clientSecret = _clientSecretController.text.trim();
    if (clientId.isEmpty || clientSecret.isEmpty) {
      setState(() {
        _error = 'Client ID and secret are required.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final uri = Uri.https('opensky-network.org', '/api/states/all', {
      'lamin': lamin.toString(),
      'lomin': lomin.toString(),
      'lamax': lamax.toString(),
      'lomax': lomax.toString(),
    });

    final authHeader = base64Encode(utf8.encode('$clientId:$clientSecret'));

    try {
      final response = await http.get(
        uri,
        headers: {'Authorization': 'Basic $authHeader'},
      );

      if (response.statusCode == 200) {
        final decoded = json.decode(response.body) as Map<String, dynamic>;
        final List<dynamic> states = decoded['states'] ?? [];

        final flights = states
            .whereType<List<dynamic>>()
            .map(FlightState.fromList)
            .where((f) => f != null)
            .cast<FlightState>()
            .toList();

        setState(() {
          _flights = flights;
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        setState(() {
          _error = 'Authentication failed. Check client ID/secret.';
          _isLoading = false;
        });
      } else {
        setState(() {
          _error =
              'Request failed (${response.statusCode}). Try again in a moment.';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Network error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final skyBlue = Colors.lightBlue.shade50;
    return Scaffold(
      appBar: AppBar(
        title: const Text('OpenSky Flight Tracker'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bounding Box (lat/long)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildNumberField('Min Latitude', _minLatController),
                  _buildNumberField('Max Latitude', _maxLatController),
                  _buildNumberField('Min Longitude', _minLonController),
                  _buildNumberField('Max Longitude', _maxLonController),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'OpenSky Credentials',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildTextField('Client ID', _clientIdController),
                  _buildTextField('Client Secret', _clientSecretController,
                      obscureText: true),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isLoading ? null : _fetchFlights,
                icon: _isLoading
                    ? const SizedBox()
                    : const Icon(Icons.flight_takeoff),
                label: _isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Fetch Flights'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Results (${_flights.length})',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              _buildTable(skyBlue),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNumberField(
      String label, TextEditingController controller) {
    return SizedBox(
      width: 180,
      child: TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(
          signed: true,
          decimal: true,
        ),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    bool obscureText = false,
  }) {
    return SizedBox(
      width: 220,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTable(Color skyBlue) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_flights.isEmpty) {
      return const Text('No flights in this area right now.');
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor:
            MaterialStateProperty.resolveWith((_) => Colors.lightBlue.shade100),
        columns: const [
          DataColumn(label: Text('Callsign')),
          DataColumn(label: Text('Country')),
          DataColumn(label: Text('Lat')),
          DataColumn(label: Text('Lon')),
          DataColumn(label: Text('Alt (m)')),
          DataColumn(label: Text('Speed (m/s)')),
        ],
        rows: _flights.asMap().entries.map((entry) {
          final index = entry.key;
          final flight = entry.value;
          final rowColor = index.isEven ? skyBlue : Colors.white;
          return DataRow(
            color: MaterialStateProperty.resolveWith((_) => rowColor),
            cells: [
              DataCell(Text(flight.callsign ?? '—')),
              DataCell(Text(flight.originCountry ?? '—')),
              DataCell(Text(flight.latitude?.toStringAsFixed(3) ?? '—')),
              DataCell(Text(flight.longitude?.toStringAsFixed(3) ?? '—')),
              DataCell(Text(flight.baroAltitude?.toStringAsFixed(0) ?? '—')),
              DataCell(Text(flight.velocity?.toStringAsFixed(1) ?? '—')),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class FlightState {
  FlightState({
    required this.callsign,
    required this.originCountry,
    required this.latitude,
    required this.longitude,
    required this.baroAltitude,
    required this.velocity,
  });

  final String? callsign;
  final String? originCountry;
  final double? latitude;
  final double? longitude;
  final double? baroAltitude;
  final double? velocity;

  static FlightState? fromList(List<dynamic> state) {
    if (state.length < 9) return null;
    return FlightState(
      callsign: _sanitizeCallsign(state[1]),
      originCountry: state[2] as String?,
      longitude: _toDouble(state[5]),
      latitude: _toDouble(state[6]),
      baroAltitude: _toDouble(state[7]),
      velocity: _toDouble(state[9]),
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static String? _sanitizeCallsign(dynamic value) {
    if (value == null) return null;
    final trimmed = value.toString().trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
