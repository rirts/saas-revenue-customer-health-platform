# Decisions

Full source snapshots use transactional DELETE + INSERT, preserving raw tables and views. All nine loads and audit rows commit together. The demo observation date is fixed for repeatability. Product usage covers a configurable 90-day window. Critical/high-priority ticket risk counts unresolved tickets. Health scoring is a rule-based prioritization policy, not a calibrated churn probability.
