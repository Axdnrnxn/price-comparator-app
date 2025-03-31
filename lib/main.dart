import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('userBox');
  await Hive.openBox('wishlistBox');
  runApp(const PriceComparatorApp());
}

class PriceComparatorApp extends StatelessWidget {
  const PriceComparatorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[100],
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.deepPurple[600],
          elevation: 0,
          centerTitle: true,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),
      home: AuthScreen(),
    );
  }
}

class AuthService {
  final Box userBox = Hive.box('userBox');
  final Box wishlistBox = Hive.box('wishlistBox');

  Future<void> register(String username, String password) async {
    if (userBox.containsKey(username)) {
      throw Exception('Username already exists');
    }

    await userBox.put('current_user', username);
    await userBox.put('$username:password', password);
    await wishlistBox.put(username, []);
  }

  Future<bool> login(String username, String password) async {
    if (!userBox.containsKey('$username:password')) {
      return false;
    }

    String storedPassword = userBox.get('$username:password') ?? '';
    if (storedPassword == password) {
      await userBox.put('current_user', username);
      return true;
    }
    return false;
  }

  String? getCurrentUser() {
    return userBox.get('current_user');
  }

  void logout() {
    userBox.delete('current_user');
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final AuthService _authService = AuthService();
  String _errorMessage = '';

  void _register() async {
    try {
      await _authService.register(
        _usernameController.text,
        _passwordController.text,
      );
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => PriceComparisonScreen()),
      );
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _login() async {
    bool success = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );
    if (success) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => PriceComparisonScreen()),
      );
    } else {
      setState(() {
        _errorMessage = "Invalid credentials";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.deepPurple[300]!,
              Colors.deepPurple[600]!,
            ],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Card(
              margin: const EdgeInsets.all(20),
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Price Comparator',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    if (_errorMessage.isNotEmpty)
                      Text(
                        _errorMessage,
                        style: const TextStyle(color: Colors.red),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                            onPressed: _register,
                            child: const Text("Register")
                        ),
                        ElevatedButton(
                            onPressed: _login,
                            child: const Text("Login")
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PriceComparisonScreen extends StatefulWidget {
  @override
  _PriceComparisonScreenState createState() => _PriceComparisonScreenState();
}

class _PriceComparisonScreenState extends State<PriceComparisonScreen> {
  final TextEditingController _controller = TextEditingController();
  final AuthService _authService = AuthService();
  final Box wishlistBox = Hive.box('wishlistBox');

  bool _isLoading = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _products = [];
  List<Map<String, dynamic>> _wishlist = [];

  @override
  void initState() {
    super.initState();
    _loadWishlist();
  }

  void _loadWishlist() {
    String? currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _wishlist = List<Map<String, dynamic>>.from(
            wishlistBox.get(currentUser, defaultValue: [])
        );
      });
    }
  }

  void _saveWishlist() {
    String? currentUser = _authService.getCurrentUser();
    if (currentUser != null) {
      wishlistBox.put(currentUser, _wishlist);
    }
  }

  Future<void> _searchProduct() async {
    String query = _controller.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _products = [];
    });

    try {
      var response = await http.get(
        Uri.parse('https://pricer.p.rapidapi.com/str?q=$query'),
        headers: {
          'x-rapidapi-host': 'pricer.p.rapidapi.com',
          'x-rapidapi-key': 'PASTE YOUR API KEY HERE',
        },
      );

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        if (data is List) {
          setState(() {
            _products = List<Map<String, dynamic>>.from(data);
          });
        } else {
          setState(() {
            _errorMessage = "Unexpected data format.";
          });
        }
      } else {
        setState(() {
          _errorMessage = 'API error: ${response.statusCode}';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch prices: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Could not open link")),
      );
    }
  }

  void _toggleWishlist(Map<String, dynamic> product) {
    setState(() {
      bool isInWishlist = _wishlist.any((item) =>
      item['title'] == product['title'] && item['price'] == product['price']
      );

      if (isInWishlist) {
        _wishlist.removeWhere((item) =>
        item['title'] == product['title'] && item['price'] == product['price']
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Removed from wishlist")),
        );
      } else {
        _wishlist.add(product);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Added to wishlist")),
        );
      }

      _saveWishlist();
    });
  }

  void _logout() {
    _authService.logout();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => AuthScreen()),
    );
  }

  void _showWishlist() {
    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text("Wishlist"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: _wishlist.length,
                itemBuilder: (context, index) {
                  var product = _wishlist[index];
                  return ListTile(
                    title: Text(product['title'] ?? 'No Title'),
                    subtitle: Text('Price: ${product['price'] ?? 'N/A'}'),
                    onTap: () => _openLink(product['link'] ?? ''),
                    trailing: IconButton(
                      icon: Icon(Icons.remove_circle, color: Colors.red),
                      onPressed: () => _toggleWishlist(product),
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text("Close"),
              ),
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Price Comparator',
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white
            )
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.favorite, color: Colors.white),
            onPressed: _showWishlist,
            tooltip: 'Wishlist',
          ),
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.grey[100]!,
              Colors.grey[200]!,
            ],
          ),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: 'Search for products',
                  prefixIcon: Icon(Icons.search, color: Colors.deepPurple),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.clear, color: Colors.deepPurple),
                    onPressed: () => _controller.clear(),
                  ),
                ),
                onSubmitted: (_) => _searchProduct(),
              ),
            ),
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.deepPurple),
                ),
              ),
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage,
                  style: TextStyle(color: Colors.red, fontSize: 16),
                ),
              ),
            Expanded(
              child: _products.isEmpty
                  ? Center(
                child: Text(
                  'Search for products to compare prices',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              )
                  : ListView.builder(
                itemCount: _products.length,
                itemBuilder: (context, index) {
                  var product = _products[index];
                  bool isInWishlist = _wishlist.any((item) =>
                  item['title'] == product['title'] &&
                      item['price'] == product['price']);

                  return Card(
                    elevation: 4,
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(10),
                      title: Text(
                        product['title'] ?? 'No Title',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.deepPurple[700],
                        ),
                      ),
                      subtitle: Text(
                        'Price: ${product['price'] ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey[700]),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              Icons.favorite,
                              color: isInWishlist ? Colors.red : Colors.grey,
                            ),
                            onPressed: () => _toggleWishlist(product),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.open_in_new,
                              color: Colors.deepPurple,
                            ),
                            onPressed: () => _openLink(product['link'] ?? ''),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
