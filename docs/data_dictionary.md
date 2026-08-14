# Data Dictionary — Key Fields

| Field | Meaning |
|---|---|
| `fixture_id` | External fixture identifier |
| `fixture_date` | Date the match is played |
| `tracking_date` | Date the prediction snapshot was tracked |
| `league_name`, `country` | Competition context |
| `league_ranking_pct` | Numeric ScoreSync app league ranking percentage; NULL means not in app |
| `btts_yes`, `btts_no` | BTTS prediction percentages |
| `result_home`, `result_draw`, `result_away` | Match-result prediction percentages |
| `overall_home`, `overall_away` | Team-strength ratings |
| `btts_confidence_*` | BTTS confidence label/score/source |
| `team_strength_confidence_*` | Team Strength confidence label/score/source |
| `result_confidence_*` | Match Result confidence label/score/source |
| `score_home`, `score_away`, `result` | Settled match outcome |
| `prediction_engine_version` | Analytics/prediction engine version |
| `model_version` | Model identifier |
| `btts_actual` | Generated settled BTTS outcome |
| `prediction_correct` | Generated BTTS classification correctness |
