/// One contact pushed to the watch (`WSFunctionManager.setAddressBook`).
final class WSAddressBookEntry {
  const WSAddressBookEntry({required this.name, required this.phone});

  final String name;
  final String phone;
}

/// Hard limit enforced by Android V2 `WSFunctionManagerImpl.setAddressBook`.
const int kJwMaxAddressBookEntries = 10;
