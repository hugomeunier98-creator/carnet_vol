/// Other spellings of a site, mapped to the name the app uses (that of the
/// preset sites, lib/data/preset_sites.dart). Matched without case.
const _siteAliases = {
  'col des frêtes': 'Col des Fretes',
  'fretes': 'Col des Fretes',
  'frêtes': 'Col des Fretes',
  'col de la forclaz': 'Forclaz',
};

/// The app's name for [site]: itself, unless it is a known other spelling.
String canonicalSite(String site) =>
    _siteAliases[site.trim().toLowerCase()] ?? site;
