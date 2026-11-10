/*
    Investigation: truck_utilization_metrics maintenance zeros
    Project: Logistics Analytics Data Warehouse
    Layer: Bronze

    Objective
    ---------
    Investigate zero values in:
      - truck_utilization_metrics.maintenance_events
      - truck_utilization_metrics.maintenance_cost
      - truck_utilization_metrics.downtime_hours

    Compare the monthly summary metrics with detailed rows in
    bronze.maintenance_records at truck-month grain.

    Important
    ---------
    Bronze columns are VARCHAR. TRY_CONVERT is used for analysis only;
    this script does not modify Bronze data.

    The month column in truck_utilization_metrics contains complete
    date strings (for example, 2022-01-01). Convert it directly:
        TRY_CONVERT(DATE, u.month)
    Do not append '-01' to these existing complete dates.

    Execution note
    --------------
    The investigation queries were executed by the author in SQL Server
    and the outputs were supplied for review. This consolidated GitHub
    script has not been independently re-executed end-to-end after
    consolidation.
*/

USE LogisticsAnalytics;
GO

/*=====================================================================
  1. Check whether the three maintenance metrics share the same
     zero/non-zero pattern.
=====================================================================*/

SELECT
    CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END
        AS ZeroMaintenanceEvents,
    CASE WHEN TRY_CONVERT(DECIMAL(18,4), maintenance_cost) = 0 THEN 1 ELSE 0 END
        AS ZeroMaintenanceCost,
    CASE WHEN TRY_CONVERT(DECIMAL(18,4), downtime_hours) = 0 THEN 1 ELSE 0 END
        AS ZeroDowntime,
    COUNT(*) AS RecordCount
FROM bronze.truck_utilization_metrics
GROUP BY
    CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END,
    CASE WHEN TRY_CONVERT(DECIMAL(18,4), maintenance_cost) = 0 THEN 1 ELSE 0 END,
    CASE WHEN TRY_CONVERT(DECIMAL(18,4), downtime_hours) = 0 THEN 1 ELSE 0 END
ORDER BY
    ZeroMaintenanceEvents,
    ZeroMaintenanceCost,
    ZeroDowntime;
GO

/*=====================================================================
  2. Examine zero-maintenance records across reporting months.
     The source contains 36 months, with 92 truck-month rows per month.
=====================================================================*/

SELECT
    CONVERT(CHAR(7), TRY_CONVERT(DATE, [month]), 120) AS ReportingMonth,
    COUNT(*) AS TotalTruckRecords,
    SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END)
        AS ZeroMaintenanceRecords,
    SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) > 0 THEN 1 ELSE 0 END)
        AS PositiveMaintenanceRecords,
    CAST(
        100.0 * SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(6,2)
    ) AS ZeroMaintenancePercentage
FROM bronze.truck_utilization_metrics
GROUP BY CONVERT(CHAR(7), TRY_CONVERT(DATE, [month]), 120)
ORDER BY ReportingMonth;
GO

/*=====================================================================
  3. Examine zero-maintenance months by truck.
     This identifies trucks with only zero or only positive months.
=====================================================================*/

SELECT
    truck_id,
    COUNT(*) AS TotalMonths,
    SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END)
        AS ZeroMaintenanceMonths,
    SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) > 0 THEN 1 ELSE 0 END)
        AS PositiveMaintenanceMonths,
    CAST(
        100.0 * SUM(CASE WHEN TRY_CONVERT(INT, maintenance_events) = 0 THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0)
        AS DECIMAL(6,2)
    ) AS ZeroMaintenancePercentage
FROM bronze.truck_utilization_metrics
GROUP BY truck_id
ORDER BY ZeroMaintenancePercentage DESC, truck_id;
GO

/*=====================================================================
  4. Inspect the ranges of the three metrics when maintenance events
     are positive.
=====================================================================*/

SELECT
    COUNT(*) AS PositiveMaintenanceTruckMonths,
    MIN(TRY_CONVERT(INT, maintenance_events)) AS MinimumMaintenanceEvents,
    MAX(TRY_CONVERT(INT, maintenance_events)) AS MaximumMaintenanceEvents,
    MIN(TRY_CONVERT(DECIMAL(18,4), maintenance_cost)) AS MinimumMaintenanceCost,
    MAX(TRY_CONVERT(DECIMAL(18,4), maintenance_cost)) AS MaximumMaintenanceCost,
    MIN(TRY_CONVERT(DECIMAL(18,4), downtime_hours)) AS MinimumDowntimeHours,
    MAX(TRY_CONVERT(DECIMAL(18,4), downtime_hours)) AS MaximumDowntimeHours
FROM bronze.truck_utilization_metrics
WHERE TRY_CONVERT(INT, maintenance_events) > 0;
GO

/*=====================================================================
  5. Validate the detailed maintenance records used for comparison.
=====================================================================*/

SELECT
    COUNT(*) AS TotalMaintenanceRecords,
    SUM(CASE WHEN TRY_CONVERT(DATE, maintenance_date) IS NULL THEN 1 ELSE 0 END)
        AS InvalidMaintenanceDates,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(18,4), total_cost) IS NULL THEN 1 ELSE 0 END)
        AS InvalidTotalCosts,
    SUM(CASE WHEN TRY_CONVERT(DECIMAL(18,4), downtime_hours) IS NULL THEN 1 ELSE 0 END)
        AS InvalidDowntimeHours,
    SUM(CASE WHEN truck_id IS NULL OR LTRIM(RTRIM(truck_id)) = '' THEN 1 ELSE 0 END)
        AS MissingTruckIDs
FROM bronze.maintenance_records;
GO

/*=====================================================================
  6. Summarize detailed maintenance records by truck and calendar month.
     Each row in maintenance_records is counted as one maintenance
     record for comparison with the monthly maintenance_events metric.
=====================================================================*/

WITH MaintenanceMonthly AS
(
    SELECT
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceYear,
        MONTH(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceMonth,
        COUNT(*) AS MaintenanceRecordCount,
        SUM(TRY_CONVERT(DECIMAL(18,4), total_cost)) AS TotalMaintenanceCost,
        SUM(TRY_CONVERT(DECIMAL(18,4), downtime_hours)) AS TotalDowntimeHours
    FROM bronze.maintenance_records
    GROUP BY
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)),
        MONTH(TRY_CONVERT(DATE, maintenance_date))
)
SELECT
    COUNT(*) AS TruckMonthCombinations,
    COUNT(DISTINCT truck_id) AS TrucksWithMaintenance,
    SUM(MaintenanceRecordCount) AS TotalMaintenanceRecords,
    MIN(MaintenanceRecordCount) AS MinimumRecordsPerTruckMonth,
    MAX(MaintenanceRecordCount) AS MaximumRecordsPerTruckMonth
FROM MaintenanceMonthly;
GO

/*=====================================================================
  7. Reconcile maintenance record counts against maintenance_events.
     This classifies all 3,312 truck-month rows in the utilization table.
=====================================================================*/

WITH MaintenanceMonthly AS
(
    SELECT
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceYear,
        MONTH(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceMonth,
        COUNT(*) AS ActualMaintenanceEvents
    FROM bronze.maintenance_records
    GROUP BY
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)),
        MONTH(TRY_CONVERT(DATE, maintenance_date))
),
Reconciliation AS
(
    SELECT
        u.truck_id,
        YEAR(TRY_CONVERT(DATE, u.[month])) AS MetricYear,
        MONTH(TRY_CONVERT(DATE, u.[month])) AS MetricMonth,
        TRY_CONVERT(INT, u.maintenance_events) AS MetricMaintenanceEvents,
        ISNULL(m.ActualMaintenanceEvents, 0) AS ActualMaintenanceEvents
    FROM bronze.truck_utilization_metrics AS u
    LEFT JOIN MaintenanceMonthly AS m
        ON u.truck_id = m.truck_id
        AND YEAR(TRY_CONVERT(DATE, u.[month])) = m.MaintenanceYear
        AND MONTH(TRY_CONVERT(DATE, u.[month])) = m.MaintenanceMonth
)
SELECT
    CASE
        WHEN MetricMaintenanceEvents = 0 AND ActualMaintenanceEvents = 0
            THEN 'Both show zero'
        WHEN MetricMaintenanceEvents = 0 AND ActualMaintenanceEvents > 0
            THEN 'Metrics zero, records exist'
        WHEN MetricMaintenanceEvents > 0 AND ActualMaintenanceEvents = 0
            THEN 'Metrics positive, no records'
        WHEN MetricMaintenanceEvents = ActualMaintenanceEvents
            THEN 'Event counts match'
        ELSE 'Event counts differ'
    END AS ReconciliationStatus,
    COUNT(*) AS TruckMonthCount
FROM Reconciliation
GROUP BY
    CASE
        WHEN MetricMaintenanceEvents = 0 AND ActualMaintenanceEvents = 0
            THEN 'Both show zero'
        WHEN MetricMaintenanceEvents = 0 AND ActualMaintenanceEvents > 0
            THEN 'Metrics zero, records exist'
        WHEN MetricMaintenanceEvents > 0 AND ActualMaintenanceEvents = 0
            THEN 'Metrics positive, no records'
        WHEN MetricMaintenanceEvents = ActualMaintenanceEvents
            THEN 'Event counts match'
        ELSE 'Event counts differ'
    END
ORDER BY TruckMonthCount DESC;
GO

/*=====================================================================
  8. Reconcile event counts, maintenance costs, and downtime hours
     across every truck-month. Exact equality is used because both
     source summaries were compared after DECIMAL(18,4) conversion.
=====================================================================*/

WITH MaintenanceMonthly AS
(
    SELECT
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceYear,
        MONTH(TRY_CONVERT(DATE, maintenance_date)) AS MaintenanceMonth,
        COUNT(*) AS ActualMaintenanceEvents,
        SUM(TRY_CONVERT(DECIMAL(18,4), total_cost)) AS ActualMaintenanceCost,
        SUM(TRY_CONVERT(DECIMAL(18,4), downtime_hours)) AS ActualDowntimeHours
    FROM bronze.maintenance_records
    GROUP BY
        truck_id,
        YEAR(TRY_CONVERT(DATE, maintenance_date)),
        MONTH(TRY_CONVERT(DATE, maintenance_date))
),
Reconciliation AS
(
    SELECT
        u.truck_id,
        YEAR(TRY_CONVERT(DATE, u.[month])) AS MetricYear,
        MONTH(TRY_CONVERT(DATE, u.[month])) AS MetricMonth,
        TRY_CONVERT(INT, u.maintenance_events) AS MetricMaintenanceEvents,
        TRY_CONVERT(DECIMAL(18,4), u.maintenance_cost) AS MetricMaintenanceCost,
        TRY_CONVERT(DECIMAL(18,4), u.downtime_hours) AS MetricDowntimeHours,
        ISNULL(m.ActualMaintenanceEvents, 0) AS ActualMaintenanceEvents,
        ISNULL(m.ActualMaintenanceCost, 0) AS ActualMaintenanceCost,
        ISNULL(m.ActualDowntimeHours, 0) AS ActualDowntimeHours
    FROM bronze.truck_utilization_metrics AS u
    LEFT JOIN MaintenanceMonthly AS m
        ON u.truck_id = m.truck_id
        AND YEAR(TRY_CONVERT(DATE, u.[month])) = m.MaintenanceYear
        AND MONTH(TRY_CONVERT(DATE, u.[month])) = m.MaintenanceMonth
)
SELECT
    COUNT(*) AS TotalTruckMonths,
    SUM(CASE WHEN MetricMaintenanceEvents = ActualMaintenanceEvents THEN 1 ELSE 0 END)
        AS MatchingEventCounts,
    SUM(CASE WHEN MetricMaintenanceCost = ActualMaintenanceCost THEN 1 ELSE 0 END)
        AS MatchingMaintenanceCosts,
    SUM(CASE WHEN MetricDowntimeHours = ActualDowntimeHours THEN 1 ELSE 0 END)
        AS MatchingDowntimeHours,
    SUM(
        CASE
            WHEN MetricMaintenanceEvents = ActualMaintenanceEvents
             AND MetricMaintenanceCost = ActualMaintenanceCost
             AND MetricDowntimeHours = ActualDowntimeHours
            THEN 1 ELSE 0
        END
    ) AS FullyMatchingTruckMonths
FROM Reconciliation;
GO
