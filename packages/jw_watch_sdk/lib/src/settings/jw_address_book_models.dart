/// One contact pushed to the watch (`JWFunctionManager.setAddressBook`).
final class JWAddressBookEntry {
  const JWAddressBookEntry({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Hard limit enforced by Android V2 `JWFunctionManagerImpl.setAddressBook`.
const int kJwMaxAddressBookEntries = 10;
