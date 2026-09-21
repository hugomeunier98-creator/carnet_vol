class RunLocation {
  final String site;
  final String run;
  final double? takeoffLat;
  final double? takeoffLng;
  final double? landingLat;
  final double? landingLng;

  const RunLocation({
    required this.site,
    required this.run,
    this.takeoffLat,
    this.takeoffLng,
    this.landingLat,
    this.landingLng,
  });

  bool get hasTakeoff => takeoffLat != null && takeoffLng != null;
  bool get hasLanding => landingLat != null && landingLng != null;
  bool get hasAny => hasTakeoff || hasLanding;

  bool matches(String site, String run) => this.site == site && this.run == run;

  RunLocation copyWith({
    double? takeoffLat,
    double? takeoffLng,
    double? landingLat,
    double? landingLng,
  }) {
    return RunLocation(
      site: site,
      run: run,
      takeoffLat: takeoffLat ?? this.takeoffLat,
      takeoffLng: takeoffLng ?? this.takeoffLng,
      landingLat: landingLat ?? this.landingLat,
      landingLng: landingLng ?? this.landingLng,
    );
  }

  Map<String, dynamic> toJson() => {
        'site': site,
        'run': run,
        'takeoffLat': takeoffLat,
        'takeoffLng': takeoffLng,
        'landingLat': landingLat,
        'landingLng': landingLng,
      };

  factory RunLocation.fromJson(Map<String, dynamic> json) => RunLocation(
        site: json['site'] as String,
        run: json['run'] as String,
        takeoffLat: (json['takeoffLat'] as num?)?.toDouble(),
        takeoffLng: (json['takeoffLng'] as num?)?.toDouble(),
        landingLat: (json['landingLat'] as num?)?.toDouble(),
        landingLng: (json['landingLng'] as num?)?.toDouble(),
      );
}
