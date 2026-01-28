// App configuration for location-based attendance

const double kDefaultCampusLatitude = 0.0; // TODO: replace with campus latitude
const double kDefaultCampusLongitude =
    0.0; // TODO: replace with campus longitude
const double kDefaultCampusRadiusMeters = 150.0; // allowed radius in meters

const double kGpsAccuracyThresholdMeters =
    80.0; // accuracy worse than this is suspicious
const int kFakeGpsTimeDriftSeconds = 30; // large time drifts suspicious
