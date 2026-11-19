
USE LogisticsAnalytics;


-- =====================================================
-- Silver Schema Inspection
-- =====================================================
-- Purpose:
-- Inspect primary key and foreign key definitions
-- in the Silver layer, including FK column nullability.
-- =====================================================


-- =====================================================
-- 1. Primary Key Metadata
-- =====================================================

SELECT
    s.name AS SchemaName,
    t.name AS TableName,
    kc.name AS PrimaryKeyName,
    c.name AS ColumnName,
    ic.key_ordinal AS KeyOrdinal,
    c.is_nullable AS IsNullable,
    ty.name AS DataType,
    c.max_length AS MaxLength,
    c.precision AS Precision,
    c.scale AS Scale
FROM sys.key_constraints AS kc
INNER JOIN sys.tables AS t
    ON kc.parent_object_id = t.object_id
INNER JOIN sys.schemas AS s
    ON t.schema_id = s.schema_id
INNER JOIN sys.index_columns AS ic
    ON kc.parent_object_id = ic.object_id
    AND kc.unique_index_id = ic.index_id
INNER JOIN sys.columns AS c
    ON ic.object_id = c.object_id
    AND ic.column_id = c.column_id
INNER JOIN sys.types AS ty
    ON c.user_type_id = ty.user_type_id
WHERE
    kc.type = 'PK'
    AND s.name = 'silver'
ORDER BY
    t.name,
    ic.key_ordinal;


-- =====================================================
-- 2. Foreign Key Metadata
-- =====================================================

SELECT
    fk.name AS ForeignKeyName,
    OBJECT_SCHEMA_NAME(fk.parent_object_id) AS SchemaName,
    OBJECT_NAME(fk.parent_object_id) AS ChildTable,
    child_col.name AS ChildColumn,
    child_col.is_nullable AS IsNullable,
    OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
    parent_col.name AS ParentColumn,
    fkc.constraint_column_id AS KeyOrdinal,
    fk.is_disabled AS IsDisabled,
    fk.is_not_trusted AS IsNotTrusted
FROM sys.foreign_keys AS fk
INNER JOIN sys.foreign_key_columns AS fkc
    ON fk.object_id = fkc.constraint_object_id
INNER JOIN sys.columns AS child_col
    ON fkc.parent_object_id = child_col.object_id
    AND fkc.parent_column_id = child_col.column_id
INNER JOIN sys.columns AS parent_col
    ON fkc.referenced_object_id = parent_col.object_id
    AND fkc.referenced_column_id = parent_col.column_id
WHERE
    OBJECT_SCHEMA_NAME(fk.parent_object_id) = 'silver'
ORDER BY
    ChildTable,
    ForeignKeyName,
    KeyOrdinal;
