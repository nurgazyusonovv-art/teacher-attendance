/// Shared administration models and repositories.
///
/// School staff administer mostly from the phone, and from a desktop browser
/// when one is at hand. Both surfaces talk to the same API, so the mapping and
/// the request code live here once; only the UI differs per form factor.
library;

export 'src/api.dart';
export 'src/models/device.dart';
export 'src/models/teacher.dart';
export 'src/repositories/devices_repository.dart';
export 'src/repositories/teachers_repository.dart';
