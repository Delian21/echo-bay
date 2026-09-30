/// Non-web stub for [VersionChecker]'s platform seam. Native builds
/// have no redeploys to catch: the checker never starts, and these
/// exist only to satisfy the conditional import.
library;

Future<String?> fetchVersionJsonBody() async => null;

void clearCachesAndWorkers() {}

void reloadPage() {}
