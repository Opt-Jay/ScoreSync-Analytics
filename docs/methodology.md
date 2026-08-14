# Methodology

## Unit of evaluation

`mip_tracker` can contain multiple tracking snapshots for the same fixture. Model-performance queries therefore use `mip_evaluation_latest`, which keeps the latest tracked row for each `fixture_id`.

This avoids treating repeated snapshots of one football match as independent model outcomes.

## BTTS

BTTS classification accuracy is measured from `prediction_correct`. Probability calibration is assessed separately by comparing the mean predicted BTTS YES percentage with the observed BTTS rate.

## Team Strength

A Team Strength prediction is evaluable only when `overall_home <> overall_away`. Equal ratings do not define a stronger team and are excluded from the denominator.

## Match Result

A clear result prediction exists only when one of HOME, DRAW or AWAY is strictly greater than the other two probabilities. Two metrics are therefore reported:

- **Coverage:** percentage of completed fixtures with a unique predicted result.
- **Conditional accuracy:** percentage correct among those clear predictions.

## Confidence validation

Confidence labels are evaluated against observed fulfilment. Where a numerical confidence score exists, the report also shows the gap between average confidence and observed fulfilment.

## League decisions

League decisions use three safeguards:

- an absolute reliability floor;
- the league's percentile within the current population;
- a minimum evidence threshold.

This prevents a weak population from redefining weak performance as good, while still allowing thresholds to adapt as the model changes.

## Cross-market comparison

BTTS, Strength and Result have different prediction tasks and natural baselines. The advanced reliability report therefore keeps raw card metrics separate and uses within-card percentiles for relative comparison rather than treating identical raw percentages as equivalent.
