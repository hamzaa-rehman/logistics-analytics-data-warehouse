/*
===============================================================================
Gold Layer — Add ISO Week Year to dim_date
===============================================================================
Purpose:
    Add the ISO week-based year to the existing Gold date dimension.

Why:
    ISO week numbers can belong to a different year than the calendar date.
    For example, 2021-01-01 is in ISO week 53 of ISO year 2020.

Derivation:
    ISO week-year is the calendar year containing the Thursday of the date's
    ISO week. day_of_week uses Monday = 1 through Sunday = 7.

Run:
    Execute once against the LogisticsAnalytics database after reviewing the
    expected sample output at the end of this script.

This migration is safe to rerun: it recalculates the values and only adds the
column if it does not already exist.
===============================================================================
*/

USE LogisticsAnalytics;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;
GO

BEGIN TRY
    BEGIN TRANSACTION;

    IF COL_LENGTH('gold.dim_date', 'iso_week_year') IS NULL
    BEGIN
        ALTER TABLE gold.dim_date
            ADD iso_week_year SMALLINT NULL;
    END;

    UPDATE d
    SET iso_week_year =
        YEAR(DATEADD(DAY, 4 - d.day_of_week, d.full_date))
    FROM gold.dim_date AS d;

    IF EXISTS
    (
        SELECT 1
        FROM gold.dim_date
        WHERE iso_week_year IS NULL
    )
    BEGIN
        THROW 51001, 'ISO week-year population failed: NULL values remain.', 1;
    END;

    ALTER TABLE gold.dim_date
        ALTER COLUMN iso_week_year SMALLINT NOT NULL;

    COMMIT TRANSACTION;

    PRINT 'iso_week_year added and populated successfully.';
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0
        ROLLBACK TRANSACTION;

    THROW;
END CATCH;
GO

-- Expected boundary examples:
-- 2021-01-01 -> calendar year 2021, ISO week 53, ISO week-year 2020
-- 2021-01-04 -> calendar year 2021, ISO week  1, ISO week-year 2021
-- 2024-12-30 -> calendar year 2024, ISO week  1, ISO week-year 2025
SELECT
    full_date,
    year_number,
    week_of_year,
    iso_week_year
FROM gold.dim_date
WHERE full_date IN
(
    CONVERT(DATE, '20210101', 112),
    CONVERT(DATE, '20210104', 112),
    CONVERT(DATE, '20241230', 112),
    CONVERT(DATE, '20241231', 112),
    CONVERT(DATE, '20250101', 112)
)
ORDER BY full_date;
GO

-- Consistency check: zero rows should be returned.
SELECT
    COUNT(*) AS total_dates,
    SUM(CASE
        WHEN iso_week_year =
             YEAR(DATEADD(DAY, 4 - day_of_week, full_date))
        THEN 0 ELSE 1
    END) AS iso_week_year_mismatches,
    SUM(CASE WHEN iso_week_year IS NULL THEN 1 ELSE 0 END) AS null_iso_week_years
FROM gold.dim_date;
GO
