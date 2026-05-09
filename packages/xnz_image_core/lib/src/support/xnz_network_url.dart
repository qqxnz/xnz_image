/// Normalizes network URLs before using them as cache/download keys.
///
/// Current policy trims leading and trailing whitespaces to avoid
/// duplicate cache entries for semantically identical URLs.
String xnzNormalizeNetworkUrl(String url) {
  return url.trim();
}
