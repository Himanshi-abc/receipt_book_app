/// Converts a tax-inclusive price to its tax-exclusive basis.
/// Shared by Products (selling price toggle) and Bills (product-sourced
/// line items) so both stay consistent - never duplicate this math.
int exclusiveFromInclusive(int inclusivePaise, double ratePercent) =>
    (inclusivePaise / (1 + ratePercent / 100)).round();

/// Converts a tax-exclusive price to its tax-inclusive basis.
int inclusiveFromExclusive(int exclusivePaise, double ratePercent) =>
    (exclusivePaise * (1 + ratePercent / 100)).round();
