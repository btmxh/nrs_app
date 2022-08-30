String? getIdFromAODByURLPrefix(List<String> sources, String prefix) {
  for (final source in sources) {
    final idx = source.indexOf(prefix);
    if (idx >= 0) {
      return source.substring(idx + prefix.length);
    }
  }
}

String? getIdFromEntryByDAHAdditionalSources(nrsEntry, String key) {
  final additionalSources = nrsEntry["DAH_meta"]["DAH_additional_sources"];
  if (additionalSources == null) {
    return null;
  }

  return additionalSources[key]?.toString();
}
