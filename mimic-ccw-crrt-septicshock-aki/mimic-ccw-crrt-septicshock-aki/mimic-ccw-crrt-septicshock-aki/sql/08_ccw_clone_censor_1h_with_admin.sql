-- ============================================================
-- 08) CCW clone-long with per-protocol + administrative censoring
-- Output:
--   data_extract_crrt.ccw_clone_long_0_24h_1h_v2
-- Input:
--   data_extract_crrt.ccw_long_0_24h_1h_v1
--   data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort"
-- ============================================================

CREATE SCHEMA IF NOT EXISTS data_extract_crrt;

DROP MATERIALIZED VIEW IF EXISTS data_extract_crrt.ccw_clone_long_0_24h_1h_v2 CASCADE;

CREATE MATERIALIZED VIEW data_extract_crrt.ccw_clone_long_0_24h_1h_v2 AS
WITH
long0 AS (
  SELECT
    l.*,
    c.outtime AS icu_outtime
  FROM data_extract_crrt.ccw_long_0_24h_1h_v1 l
  JOIN data_extract_crrt."301_ss_aki3_t0_no_rrt_cohort" c
    ON c.stay_id = l.stay_id
),

death_time AS (
  SELECT
    l.stay_id,
    a.deathtime AS death_time
  FROM long0 l
  JOIN mimiciv_hosp.admissions a
    ON a.hadm_id = l.hadm_id
  GROUP BY l.stay_id, a.deathtime
),

clones AS (
  SELECT
    l.*,
    d.death_time,
    s.strategy
  FROM long0 l
  LEFT JOIN death_time d
    ON d.stay_id = l.stay_id
  CROSS JOIN (VALUES ('A'), ('B')) AS s(strategy)
),

censor_times AS (
  SELECT
    c.*,
    (c.t0_time + interval '24 hour') AS grace_end,

    -- per-protocol censor time
    CASE
      WHEN c.strategy = 'A' THEN
        CASE
          WHEN c.crrt_start_time IS NULL OR c.crrt_start_time >= c.t0_time + interval '24 hour'
          THEN c.t0_time + interval '24 hour'
          ELSE NULL
        END
      WHEN c.strategy = 'B' THEN
        CASE
          WHEN c.crrt_start_time IS NOT NULL AND c.crrt_start_time < c.t0_time + interval '24 hour'
          THEN c.crrt_start_time
          ELSE NULL
        END
      ELSE NULL
    END AS proto_censor_time,

    -- administrative censor time (only if before grace_end)
    CASE
      WHEN c.death_time IS NOT NULL
       AND c.death_time > c.t0_time
       AND c.death_time < c.t0_time + interval '24 hour'
      THEN c.death_time
      WHEN c.icu_outtime IS NOT NULL
       AND c.icu_outtime > c.t0_time
       AND c.icu_outtime < c.t0_time + interval '24 hour'
      THEN c.icu_outtime
      ELSE NULL
    END AS admin_censor_time
  FROM clones c
),

total_censor AS (
  SELECT
    x.*,
    CASE
      WHEN x.proto_censor_time IS NULL THEN x.admin_censor_time
      WHEN x.admin_censor_time IS NULL THEN x.proto_censor_time
      WHEN x.proto_censor_time <= x.admin_censor_time THEN x.proto_censor_time
      ELSE x.admin_censor_time
    END AS total_censor_time
  FROM censor_times x
),

final AS (
  SELECT
    t.*,

    CASE
      WHEN t.admin_censor_time IS NOT NULL
       AND (t.proto_censor_time IS NULL OR t.admin_censor_time <= t.proto_censor_time)
      THEN 1 ELSE 0
    END AS admin_censor_driving,

    CASE
      WHEN t.proto_censor_time IS NOT NULL
       AND (t.admin_censor_time IS NULL OR t.proto_censor_time < t.admin_censor_time)
      THEN 1 ELSE 0
    END AS proto_censor_driving,

    -- discrete-time censor in (t_start, t_end]
    CASE
      WHEN t.total_censor_time IS NOT NULL
       AND t.total_censor_time >  t.t_start
       AND t.total_censor_time <= t.t_end
      THEN 1 ELSE 0
    END AS censor_k_total,

    CASE
      WHEN t.total_censor_time IS NULL THEN 1
      WHEN t.total_censor_time > t.t_end THEN 1
      ELSE 0
    END AS at_risk_after_k,

    CASE
      WHEN t.strategy='A' AND t.crrt_start_time IS NOT NULL AND t.crrt_start_time < t.grace_end THEN 1
      ELSE 0
    END AS task_completed_within_24h,

    CASE
      WHEN t.strategy='B' AND (t.crrt_start_time IS NULL OR t.crrt_start_time >= t.grace_end) THEN 1
      ELSE 0
    END AS task_maintained_no_early_24h

  FROM total_censor t
)

SELECT * FROM final
;

CREATE INDEX IF NOT EXISTS idx_ccw_clone_long_v2_stay_strategy_hour
  ON data_extract_crrt.ccw_clone_long_0_24h_1h_v2(stay_id, strategy, hour_index);

CREATE INDEX IF NOT EXISTS idx_ccw_clone_long_v2_censor
  ON data_extract_crrt.ccw_clone_long_0_24h_1h_v2(strategy, censor_k_total);

CREATE INDEX IF NOT EXISTS idx_ccw_clone_long_v2_atrisk
  ON data_extract_crrt.ccw_clone_long_0_24h_1h_v2(strategy, at_risk_after_k);

ANALYZE data_extract_crrt.ccw_clone_long_0_24h_1h_v2;