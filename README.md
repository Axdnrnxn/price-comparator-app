# Price Comparator App

## Overview
Price Comparator App is an e-commerce application that allows users to compare product prices across multiple stores, including Lazada, Shopee, and Zalora. The app features user authentication, a wishlist system, and real-time product search functionality using an external API.

## Features
- **User Authentication**: Register and log in to save personal data securely.
- **Price Comparison**: Search and compare product prices from different e-commerce platforms.
- **Wishlist System**: Save favorite products in a wishlist tied to the logged-in user.
- **External API Integration**: Fetch product prices using a third-party API.
- **Secure Local Storage**: Stores user data and wishlist using the Hive database.

## Setup Instructions
### Prerequisites
Ensure you have Flutter installed. If not, follow the official Flutter installation guide:
[Flutter Installation](https://flutter.dev/docs/get-started/install)

### Clone the Repository
```sh
git clone https://github.com/yourusername/price_comparator_app.git
cd price_comparator_app
```

### Install Dependencies
```sh
flutter pub get
```

### API Subscription and Key Setup
This app requires an API key to fetch product prices. Follow these steps:
1. Subscribe to the product price comparison API: [Pricer API](https://rapidapi.com/animeslayerquiz/api/pricer/playground/apiendpoint_283e3f32-d4da-4444-b7c3-f13a77becadb).
2. Obtain an API key.
3. Insert the API key in the `main.dart` file inside the `headers` parameter of the `http.get()` request:

   ```dart
   headers: {
     'x-rapidapi-host': 'pricer.p.rapidapi.com',
     'x-rapidapi-key': 'YOUR_API_KEY_HERE',
   },
   ```

### Running the App
Run the following command to launch the application:
```sh
flutter run
```

## Database and Wishlist Functionality
### Hive Database
- The app uses **Hive** as a local NoSQL database to store user credentials and wishlist items.
- Upon user registration, a new entry is created in `userBox` with a password.
- When logging in, the app verifies the stored password before granting access.

### Wishlist System
- Each logged-in user has a unique wishlist stored in the `wishlistBox`.
- Products added to the wishlist are stored under the user's key.
- Users can remove products from their wishlist anytime.
- When a user logs out, the wishlist is saved and retrieved when they log in again.

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

