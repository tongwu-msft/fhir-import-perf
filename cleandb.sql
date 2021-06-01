DECLARE @TABLES TABLE
  (
     NAME         nvarchar(50)
     , ARRAYINDEX int IDENTITY(1, 1)
  );
DECLARE @INDEXVAR     int
        , @TOTALCOUNT int
        , @TABLE      nvarchar(50)
        , @message    [nvarchar](2047);

INSERT INTO @TABLES
VALUES      ('RESOURCE')

INSERT INTO @TABLES
VALUES      ('ResourceWriteClaim')

INSERT INTO @TABLES
VALUES      ('TokenText')

INSERT INTO @TABLES
VALUES      ('TaskInfo')

INSERT INTO @TABLES
VALUES      ('CompartmentAssignment')

INSERT INTO @TABLES
SELECT TABLE_NAME
FROM   INFORMATION_SCHEMA.TABLES
WHERE  TABLE_NAME LIKE '%Param'

SET @INDEXVAR = 0

SELECT @TOTALCOUNT = COUNT(*)
FROM   @TABLES

WHILE @INDEXVAR < @TOTALCOUNT
  BEGIN
      SELECT @INDEXVAR = @INDEXVAR + 1

      SELECT @TABLE = NAME
      FROM   @TABLES
      WHERE  ARRAYINDEX = @INDEXVAR

      SELECT @message = N'preparing to truncate table(' + @TABLE
                        + N').';

      RAISERROR(@message,0,1) WITH nowait;

      EXEC ('TRUNCATE TABLE ' + @TABLE);
  END 
