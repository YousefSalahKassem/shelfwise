/// Built-in roles for the MVP (custom roles come with D7).
enum Role {
  owner,
  staff;

  static Role fromName(String name) =>
      Role.values.firstWhere((r) => r.name == name, orElse: () => Role.staff);
}

/// Every action a use case may check. Adding one is a contract change.
enum Permission {
  viewCatalogue,
  editCatalogue,
  editPrices,
  recordStock,
  adjustStock,
  setReorderPoints,
  manageProfiles,
  manageSettings,
  importExport,
  backupRestore,
}

/// TECHNICAL_STRUCTURE §10.
const Map<Role, Set<Permission>> defaultRolePermissions = {
  Role.owner: {...Permission.values},
  Role.staff: {
    Permission.viewCatalogue,
    Permission.recordStock,
    Permission.adjustStock, // business plan: staff can view, receive and adjust stock
  },
};
