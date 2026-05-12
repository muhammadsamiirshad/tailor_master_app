# Tailor Master — UI Documentation

This document describes the app's screens, layout structure (widget trees), and user flows.

---

## 📱 Screen Overview

| # | Screen | Purpose | Key Widgets |
|---|--------|---------|-------------|
| 1 | **Login** | User authentication | TextField (email, password), ElevatedButton |
| 2 | **Signup** | New account creation | TextField (email, password), Form validation |
| 3 | **Forgot Password** | Password recovery | TextField (email), SnackBar confirmation |
| 4 | **Dashboard** | Home screen, KPIs | SliverAppBar, Cards (pending, revenue, dues) |
| 5 | **Customers** | List & search customers | ListView, SearchBar, FAB (add customer) |
| 6 | **Orders** | All orders & filters | ListView, FilterChips, OrderCard |
| 7 | **Add/Edit Order** | Create/modify orders | Form, DatePicker, DropdownButton (customer) |
| 8 | **Settings** | User preferences & logout | SwitchListTile, TextButton (logout) |
| 9 | **Udhaar (Dues)** | Payment tracking | ListView (incomplete orders), PaymentDialog |

---

## 1️⃣ Login Screen Widget Tree

```
LoginScreen (StatefulWidget)
├── Scaffold
│   ├── body: SingleChildScrollView
│   │   └── Column
│   │       ├── SizedBox (top padding)
│   │       ├── Text ("Welcome Back")
│   │       ├── SizedBox
│   │       ├── Form
│   │       │   ├── TextFormField (email)
│   │       │   ├── SizedBox (spacing)
│   │       │   ├── TextFormField (password)
│   │       │   │   └── obscureText: true
│   │       │   ├── SizedBox
│   │       │   ├── TextButton ("Forgot Password?")
│   │       │   ├── SizedBox
│   │       │   ├── ElevatedButton ("Sign In")
│   │       │   │   └── isLoading ? CircularProgressIndicator : Text
│   │       │   └── Row
│   │       │       ├── Text ("Don't have an account?")
│   │       │       └── TextButton ("Sign Up")
│   │       └── SizedBox
│   └── BottomSheet (if hasError)
│       └── ErrorMessage
```

**Key Props**:
- `_formKey`: GlobalKey for validation
- `_isLoading`: Bool for button state
- `_obscurePassword`: Bool for visibility toggle
- Animation: FadeTransition + SlideTransition on screen enter

---

## 2️⃣ Dashboard Screen Widget Tree

```
DashboardScreen (StatelessWidget)
├── Scaffold
│   ├── floatingActionButton: FloatingActionButton.extended ("New Order")
│   ├── body: Consumer<DarziProvider>
│   │   └── RefreshIndicator
│   │       └── CustomScrollView (SliverList)
│   │           ├── SliverAppBar (expandedHeight: 130)
│   │           │   ├── flexibleSpace: FlexibleSpaceBar
│   │           │   │   └── gradient background
│   │           │   │       ├── Text ("Welcome, User")
│   │           │   │       └── SubtitleText
│   │           │   └── actions: [SettingsButton]
│   │           │
│   │           ├── SliverToBoxAdapter
│   │           │   └── GridView (2 columns)
│   │           │       ├── StatCard (pending orders)
│   │           │       ├── StatCard (total revenue)
│   │           │       ├── StatCard (total dues)
│   │           │       └── StatCard (this month collected)
│   │           │
│   │           ├── SliverToBoxAdapter
│   │           │   └── Padding
│   │           │       └── Text ("Urgent Orders")
│   │           │
│   │           ├── SliverList (urgent orders)
│   │           │   └── OrderCard (compact view)
│   │           │
│   │           ├── SliverToBoxAdapter
│   │           │   └── Text ("Upcoming (Next 5)")
│   │           │
│   │           └── SliverList (upcoming orders)
│   │               └── OrderCard
│   │
│   └── BottomNavigationBar
│       ├── NavBarItem (Dashboard)
│       ├── NavBarItem (Customers)
│       ├── NavBarItem (Orders)
│       └── NavBarItem (Udhaar)
```

**Key Components**:
- `StatCard`: Reusable card showing metric
- `OrderCard`: Compact order preview
- Pull-to-refresh: Calls `provider.init()`

---

## 3️⃣ Customers Screen Widget Tree

```
CustomersScreen (StatefulWidget)
├── Scaffold
│   ├── appBar: AppBar
│   │   ├── SearchBar
│   │   │   ├── SearchController
│   │   │   └── onChanged: _onSearchChanged()
│   │   └── Actions: [MoreOptions]
│   │
│   ├── floatingActionButton: FAB ("Add Customer")
│   │   └── onPressed: _showAddCustomerDialog()
│   │
│   ├── body: Consumer<DarziProvider>
│   │   ├── if (isLoading)
│   │   │   └── Center(CircularProgressIndicator)
│   │   │
│   │   ├── else if (searchResults != null)
│   │   │   └── ListView.builder
│   │   │       ├── CustomerCard (name, phone, measurements)
│   │   │       └── onTap: _showEditCustomerDialog()
│   │   │       └── onLongPress: _confirmDeleteCustomer()
│   │   │
│   │   └── else (no search)
│   │       └── ListView.builder (all customers)
│   │           └── Same as search results
│   │
│   └── Dialog (AddCustomerDialog)
│       ├── TextField (name)
│       ├── TextField (phone)
│       ├── TextField (chest, collar, etc.)
│       ├── TextField (custom measurements)
│       └── ElevatedButton (Save)
```

**Key Props**:
- `_searchController`: TextEditingController
- `_searchResults`: List<Customer>? (null = show all)
- `_isSearching`: Bool for loading state

---

## 4️⃣ Orders Screen Widget Tree

```
OrdersScreen (StatefulWidget)
├── Scaffold
│   ├── appBar: AppBar
│   │   ├── TextField (search by order ID)
│   │   └── IconButton (filter)
│   │
│   ├── floatingActionButton: FAB ("New Order")
│   │   └── onPressed: Navigator.push(AddOrderScreen)
│   │
│   ├── body: Column
│   │   ├── SingleChildScrollView (horizontal)
│   │   │   └── Row (FilterChips)
│   │   │       ├── FilterChip ("Pending")
│   │   │       ├── FilterChip ("Completed")
│   │   │       ├── FilterChip ("Urgent")
│   │   │       └── FilterChip ("Dues Outstanding")
│   │   │
│   │   └── Expanded
│   │       └── Consumer<DarziProvider>
│   │           ├── if (filteredOrders.isEmpty)
│   │           │   └── Center(Text("No orders"))
│   │           │
│   │           └── else
│   │               └── ListView.builder
│   │                   ├── OrderCard (full view)
│   │                   │   ├── OrderID
│   │                   │   ├── CustomerName
│   │                   │   ├── DeliveryDate
│   │                   │   ├── Status (badge)
│   │                   │   ├── TotalCost / RemainingBalance
│   │                   │   └── Actions: [Edit, Delete]
│   │                   └── onTap: showOrderDetailsScreen()
```

---

## 5️⃣ Add/Edit Order Screen Widget Tree

```
AddOrderScreen (StatefulWidget)
├── Scaffold
│   ├── appBar: AppBar ("New Order" or "Edit Order")
│   │   └── actions: [SaveButton]
│   │
│   └── body: SingleChildScrollView
│       └── Form
│           ├── DropdownButton (Customer) [required]
│           ├── SizedBox
│           ├── TextField (Order Description)
│           ├── SizedBox
│           ├── DatePickerField (Delivery Date)
│           ├── SizedBox
│           ├── TextField (Total Cost)
│           ├── SizedBox
│           ├── TextField (Advance Paid)
│           ├── SizedBox
│           ├── TextField (Notes)
│           ├── SizedBox
│           ├── ElevatedButton ("Save Order")
│           │   └── onPressed: _saveOrder()
│           └── SizedBox
```

**Key Props**:
- `_formKey`: GlobalKey<FormState>
- `_customerController`: TextEditingController
- `_deliveryDate`: DateTime
- Validation: All fields required except notes

---

## 6️⃣ Settings Screen Widget Tree

```
SettingsScreen (StatelessWidget)
├── Scaffold
│   ├── appBar: AppBar ("Settings")
│   │
│   └── body: ListView
│       ├── ListTile (header: "App Settings")
│       ├── SwitchListTile
│       │   ├── title: "Dark Mode"
│       │   └── onChanged: toggleTheme()
│       │
│       ├── SwitchListTile
│       │   ├── title: "Notifications"
│       │   └── onChanged: toggleNotifications()
│       │
│       ├── Divider
│       ├── ListTile (header: "Account")
│       ├── ListTile
│       │   ├── title: "Current User"
│       │   ├── subtitle: currentUser.email
│       │   └── trailing: Chip
│       │
│       ├── ElevatedButton ("Sign Out")
│       │   └── onPressed: _signOut()
│       │
│       └── Divider
│           └── Text ("v1.0.0")
```

---

## 7️⃣ Udhaar (Dues) Screen Widget Tree

```
UdhaarScreen (StatelessWidget)
├── Scaffold
│   ├── appBar: AppBar ("Outstanding Dues")
│   │
│   └── body: Consumer<DarziProvider>
│       ├── if (udhaarOrders.isEmpty)
│       │   └── Center(Text("No pending dues 🎉"))
│       │
│       └── else
│           ├── Column
│           │   ├── Card (Summary)
│           │   │   ├── Text ("Total Outstanding: PKR X")
│           │   │   ├── Text ("Customers: Y")
│           │   │   └── ProgressBar (collection progress)
│           │   │
│           │   └── ListView.builder
│           │       ├── UdhaarCard
│           │       │   ├── CustomerName
│           │       │   ├── OutstandingAmount
│           │       │   ├── DueDate
│           │       │   └── ElevatedButton ("Record Payment")
│           │       │       └── onPressed: _showPaymentDialog()
│           │       │
│           │       └── Dialog (PaymentDialog)
│           │           ├── TextField (Payment Amount)
│           │           ├── ElevatedButton ("Confirm")
│           │           └── onPressed: provider.recordAdvancePaid()
```

---

## Color Scheme

**Primary Emerald Green**:
- Dark: `#065F46` (used for AppBar, FAB, buttons)
- Light: `#10B981` (accent)
- Surface: `#F5F5F5` (background)

**Status Badges**:
- Pending: Yellow (`#FFC107`)
- Completed: Green (`#4CAF50`)
- Urgent: Red (`#F44336`)
- Archived: Gray (`#9E9E9E`)

---

## Navigation Flow

```
Login/Signup → Dashboard (if authenticated) → [Bottom Tab Navigation]
              ↓
              ├── Customers → CustomerDetails → EditCustomer
              ├── Orders → OrderDetails → EditOrder
              ├── Dashboard → [FAB] → AddOrder
              ├── Udhaar → RecordPayment
              └── Settings → Logout → [Back to Login]
```

---

## Responsive Design

- **Mobile**: Single column, full-width cards
- **Tablet**: 2-column grid for stats, larger input fields
- **Desktop**: 3-column grid, side navigation (not yet implemented)

---

## Accessibility Features

- ✅ Large touch targets (48x48 minimum)
- ✅ High contrast text (AA compliance)
- ⚠️ TODO: Semantic labels for screen readers
- ⚠️ TODO: Keyboard navigation support

---

## Future UI Improvements

1. Add dark mode support
2. Implement animations for list items
3. Add swipe gestures (delete, archive)
4. Responsive tablet/desktop layout
5. Add image picker for order photos
6. Print receipt/invoice feature
