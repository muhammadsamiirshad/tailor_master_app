# Error Handling & Offline Sync — Implementation Guide

## Overview

The Tailor Master app now includes robust error handling and offline sync capabilities for Firebase services. This document explains the implementation and how to use it.

---

## 🔐 Security Service

**File**: [lib/services/security_service.dart](lib/services/security_service.dart)

### Changes
- **Hardcoded keys removed** ✅
- Keys now loaded from **environment variables**:
  - `ENCRYPTION_KEY` (32 characters)
  - `ENCRYPTION_IV` (16 characters)

### How to Use

1. Create `.env` file in project root:
```env
ENCRYPTION_KEY=YourSecure32CharacterKeyHere1234
ENCRYPTION_IV=YourSecure16CharIV123
```

2. Generate secure keys:
```bash
# macOS/Linux
openssl rand -base64 32 | tr -d '=' | cut -c1-32
openssl rand -base64 16 | tr -d '=' | cut -c1-16
```

3. **Never commit `.env` to git**—add to `.gitignore`:
```gitignore
.env
.env.local
*.env
```

### Error Handling
- Throws `Exception` if keys are missing or invalid
- Validates key length at runtime

---

## 🗄️ RTDB Service — Database Error Handling

**File**: [lib/services/rtdb_service.dart](lib/services/rtdb_service.dart)

### New Exception Class

```dart
class DatabaseFailure implements Exception {
  final String message;
  const DatabaseFailure(this.message);
}
```

All database operations now throw `DatabaseFailure` with user-friendly messages instead of generic exceptions.

### All CRUD Methods Now Include Error Handling

#### Customers

```dart
// Insert customer with error handling
try {
  final customerId = await RTDBService.instance.insertCustomer(customer);
  print('Customer saved: $customerId');
} on DatabaseFailure catch (e) {
  print('Error: ${e.message}'); // "Failed to save customer: ..."
}
```

**Error cases**:
- ❌ Network error → "Failed to save customer: network error. Data may be cached."
- ❌ Permission denied → "Failed to save customer: ..."
- ✅ Offline → Data queued for sync when online

#### Orders

```dart
// Get all orders with error handling
try {
  final orders = await RTDBService.instance.getAllOrders();
} on DatabaseFailure catch (e) {
  print('${e.message}'); // "Failed to load orders: ... Data may be cached."
}
```

#### Payment Recording

```dart
// Record payment with validation
try {
  await RTDBService.instance.recordAdvancePaid(orderId, 500);
} on DatabaseFailure catch (e) {
  // Handles: "Payment amount must be greater than 0"
  // Handles: "Order not found"
  // Handles: network errors
  print('Payment error: ${e.message}');
}
```

---

## 📡 Offline Persistence & Sync

### Automatic Persistence

Offline persistence is **enabled by default** in the constructor:

```dart
RTDBService._internal() {
  _initializeOfflinePersistence();
}

void _initializeOfflinePersistence() {
  try {
    _db.setPersistenceEnabled(true);
    _db.setLoggingEnabled(false);
  } catch (e) {
    print('Persistence already enabled or unavailable.');
  }
}
```

### How It Works

1. **Online**: Data reads/writes go directly to Firebase
2. **Offline**: 
   - Reads return cached data
   - Writes are queued locally
   - UI shows cached data with a loading/sync indicator
3. **Reconnects**: Queued writes automatically sync to Firebase

### Connection State Monitoring

Monitor connection status in your UI:

```dart
StreamBuilder<bool>(
  stream: RTDBService.instance.connectionStream,
  builder: (context, snapshot) {
    final isOnline = snapshot.data ?? false;
    return isOnline
        ? Text('🟢 Online')
        : Text('🔴 Offline — Changes will sync when online');
  },
)
```

### In DarziProvider

Update UI based on connection state:

```dart
// Example: Show sync indicator when offline
bool _isOnline = true;

Future<void> init() async {
  // Listen to connection state
  RTDBService.instance.connectionStream.listen((isOnline) {
    _isOnline = isOnline;
    notifyListeners();
  });
  
  // Reload data
  await _loadCustomers();
  await _loadOrders();
}
```

---

## 🎯 Error Messages - User Friendly

All errors are translated to user-friendly messages:

| Operation | Error Case | Message |
|---|---|---|
| Save Customer | Network error | "Failed to save customer: Network error. Data may be cached." |
| Load Orders | No permission | "Failed to load orders: Permission denied. Data may be cached." |
| Delete Customer | Not found | "Customer not found." |
| Record Payment | Invalid amount | "Payment amount must be greater than 0." |
| Record Payment | Order not found | "Order not found." |
| Update Order | Missing ID | "Order must have an ID to update." |

---

## 🔧 Implementation in Screens

### Example: Add Customer With Error Handling

```dart
class AddCustomerDialog extends StatefulWidget {
  @override
  State<AddCustomerDialog> createState() => _AddCustomerDialogState();
}

class _AddCustomerDialogState extends State<AddCustomerDialog> {
  bool _isSaving = false;

  Future<void> _saveCustomer(DarziProvider provider) async {
    setState(() => _isSaving = true);
    try {
      final customer = Customer(
        name: _nameController.text,
        phone: _phoneController.text,
        // ... other fields
      );
      
      await provider.addCustomer(customer);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer saved successfully!')),
      );
      Navigator.pop(context);
    } on DatabaseFailure catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.message}')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
```

### Example: Display Connection Status

```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Connection indicator
          StreamBuilder<bool>(
            stream: RTDBService.instance.connectionStream,
            builder: (context, snapshot) {
              final isOnline = snapshot.data ?? true;
              return Container(
                color: isOnline ? Colors.green : Colors.orange,
                padding: const EdgeInsets.all(8),
                child: Text(
                  isOnline ? '🟢 Connected' : '🔴 Offline — Sync in progress',
                  style: const TextStyle(color: Colors.white),
                ),
              );
            },
          ),
          // Rest of dashboard
        ],
      ),
    );
  }
}
```

---

## 📱 Auth Service

**File**: [lib/services/auth_service.dart](lib/services/auth_service.dart)

Already includes comprehensive error handling with friendly messages for:
- Invalid email format
- User not found
- Wrong password
- Weak password
- Email already in use
- Network errors
- Firebase configuration errors

### Usage

```dart
try {
  await authService.signInWithEmailPassword(
    email: email,
    password: password,
  );
} on AuthFailure catch (e) {
  print('Auth error: ${e.message}'); // User-friendly message
  showErrorDialog(context, e.message);
}
```

---

## 🚀 Best Practices

1. **Always wrap database calls in try-catch**:
```dart
try {
  final customers = await RTDBService.instance.getAllCustomers();
} on DatabaseFailure catch (e) {
  // Handle error
}
```

2. **Show loading states**:
```dart
setState(() => _isLoading = true);
try {
  // operation
} finally {
  setState(() => _isLoading = false);
}
```

3. **Use Connection Stream**:
```dart
StreamBuilder<bool>(
  stream: RTDBService.instance.connectionStream,
  builder: (context, snapshot) {
    // Show indicator based on connection state
  },
)
```

4. **Test offline behavior**:
   - Enable Airplane Mode
   - Verify UI shows cached data
   - Verify writes are queued
   - Disable Airplane Mode
   - Verify data syncs

---

## 🧪 Testing Offline Sync

1. **Android Emulator**:
   - Open Android Studio → Extended Controls → Network
   - Set connection to "Disconnected"
   - Perform actions (add customer, create order)
   - Reconnect network
   - Verify data synced

2. **Physical Device**:
   - Enable Airplane Mode
   - Use app normally
   - Disable Airplane Mode
   - Observe sync

3. **Logcat Debugging**:
   - Enable logging: `_db.setLoggingEnabled(true)` in `_initializeOfflinePersistence()`
   - Watch for sync operations in Logcat

---

## 🐛 Debugging

### Enable Database Logging

In [lib/services/rtdb_service.dart](lib/services/rtdb_service.dart):

```dart
void _initializeOfflinePersistence() {
  try {
    _db.setPersistenceEnabled(true);
    _db.setLoggingEnabled(true); // Change to true for debugging
  } catch (e) {
    print('Note: Offline persistence may already be enabled.');
  }
}
```

### Monitor Errors

```dart
// In DarziProvider or provider
Future<void> _loadCustomers() async {
  try {
    _customers = await RTDBService.instance.getAllCustomers();
    notifyListeners();
  } on DatabaseFailure catch (e) {
    print('Database error: ${e.message}');
    // UI can react to this error
  }
}
```

---

## ✅ Checklist for Production

- [ ] `.env` file created with secure keys
- [ ] `.env` added to `.gitignore`
- [ ] Database logging disabled (`setLoggingEnabled(false)`)
- [ ] Error messages tested on all screens
- [ ] Offline sync tested with Airplane Mode
- [ ] Connection state indicator working
- [ ] Firebase permissions reviewed
- [ ] Security rules configured in Firebase Console

---

## 📚 References

- [Firebase Realtime Database - Offline Persistence](https://firebase.google.com/docs/database/flutter/offline-capabilities)
- [Firebase Realtime Database - Error Handling](https://firebase.google.com/docs/database/flutter/database-errors)
- [Dart encrypt package](https://pub.dev/packages/encrypt)
