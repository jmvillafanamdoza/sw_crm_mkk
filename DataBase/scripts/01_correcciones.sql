-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 01: CORRECCIONES SOBRE EL ESQUEMA EXISTENTE
--   1. Stored procedures de TMKK_TIP_VALOR (bug en UPDATE, parámetros opcionales,
--      columnas que espera la API, SP de eliminación que la API ya invoca).
--   2. Inconsistencias de tipos y defaults entre tablas.
--   3. Datos de catálogo que no coinciden con lo que usa el frontend.
-- Es idempotente: puede ejecutarse más de una vez.
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TMKK_TIP_VALOR
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Consulta. Todos los filtros son opcionales (la API llama al SP enviando solo
-- algunos parámetros). Devuelve las columnas que mapea TipoValorSpResultDto.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[PRMKK_CON_BOF_TIP_VALOR]
    @i_TIP_ESTADO  VARCHAR(50)  = NULL,  -- código de grupo (CTPV_COD_TIP_VALOR)
    @i_TIP_VALOR   VARCHAR(8)   = NULL,  -- valor dentro del grupo (CTPV_TIP_VALOR)
    @i_DESCRIPCION VARCHAR(250) = NULL,
    @i_ESTADO      CHAR(1)      = NULL   -- 'V' / 'I'; NULL = todos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        CTPV_COD_TIP_VALOR,
        CTPV_TIP_VALOR,
        STPV_DES_TIP_VALOR_1,
        STPV_DES_TIP_VALOR_2,
        STPV_DES_TIP_VALOR_3,
        FTPV_ESTADO,
        AUD_INS_USER,
        AUD_INS_FEC AS AUD_INS_DATE,
        AUD_UPD_USER,
        AUD_UPD_FEC AS AUD_UPD_DATE,
        STPV_DES_TIP_VALOR_1 AS descripcion
    FROM TMKK_TIP_VALOR
    WHERE (NULLIF(@i_TIP_ESTADO, '') IS NULL OR CTPV_COD_TIP_VALOR = @i_TIP_ESTADO)
      AND (NULLIF(@i_TIP_VALOR, '') IS NULL OR CTPV_TIP_VALOR = @i_TIP_VALOR)
      AND (NULLIF(@i_DESCRIPCION, '') IS NULL OR STPV_DES_TIP_VALOR_1 LIKE '%' + @i_DESCRIPCION + '%')
      AND (NULLIF(@i_ESTADO, '') IS NULL OR FTPV_ESTADO = @i_ESTADO)
    ORDER BY CTPV_COD_TIP_VALOR, CTPV_TIP_VALOR;
END
GO

CREATE OR ALTER PROCEDURE [dbo].[PRMKK_INS_BOF_TIP_VALOR]
    @i_CTPV_COD_TIP_VALOR   VARCHAR(20),
    @i_CTPV_TIP_VALOR       VARCHAR(8),
    @i_STPV_DES_TIP_VALOR_1 VARCHAR(128),
    @i_STPV_DES_TIP_VALOR_2 VARCHAR(128) = NULL,
    @i_STPV_DES_TIP_VALOR_3 VARCHAR(128) = NULL,
    @i_AUD_INS_USER         VARCHAR(16),
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM TMKK_TIP_VALOR
                   WHERE CTPV_COD_TIP_VALOR = @i_CTPV_COD_TIP_VALOR
                     AND CTPV_TIP_VALOR = @i_CTPV_TIP_VALOR)
        BEGIN
            SET @o_resultMessage = '0|Ya existe el valor ' + @i_CTPV_TIP_VALOR + ' en el grupo ' + @i_CTPV_COD_TIP_VALOR;
            RETURN;
        END

        INSERT INTO TMKK_TIP_VALOR (
            CTPV_COD_TIP_VALOR, CTPV_TIP_VALOR,
            STPV_DES_TIP_VALOR_1, STPV_DES_TIP_VALOR_2, STPV_DES_TIP_VALOR_3,
            FTPV_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (
            @i_CTPV_COD_TIP_VALOR, @i_CTPV_TIP_VALOR,
            @i_STPV_DES_TIP_VALOR_1, NULLIF(@i_STPV_DES_TIP_VALOR_2, ''), NULLIF(@i_STPV_DES_TIP_VALOR_3, ''),
            'V', GETDATE(), @i_AUD_INS_USER);

        SET @o_resultMessage = '1|Registro correcto';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Actualización. Correcciones respecto a la versión anterior:
--   * El WHERE comparaba CTPV_COD_TIP_VALOR con @i_CTPV_TIP_VALOR (nunca actualizaba).
--   * Ya no modifica CTPV_TIP_VALOR (es parte de la PK).
--   * Registra AUD_UPD_USER / AUD_UPD_FEC en lugar de pisar AUD_INS_USER.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[PRMKK_UPD_BOF_TIP_VALOR]
    @i_CTPV_COD_TIP_VALOR   VARCHAR(20),
    @i_CTPV_TIP_VALOR       VARCHAR(8),
    @i_STPV_DES_TIP_VALOR_1 VARCHAR(128) = NULL,
    @i_STPV_DES_TIP_VALOR_2 VARCHAR(128) = NULL,
    @i_STPV_DES_TIP_VALOR_3 VARCHAR(128) = NULL,
    @i_AUD_UPD_USER         VARCHAR(16)  = NULL,
    @o_resultMessage        VARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE TMKK_TIP_VALOR
        SET STPV_DES_TIP_VALOR_1 = COALESCE(NULLIF(@i_STPV_DES_TIP_VALOR_1, ''), STPV_DES_TIP_VALOR_1),
            STPV_DES_TIP_VALOR_2 = NULLIF(@i_STPV_DES_TIP_VALOR_2, ''),
            STPV_DES_TIP_VALOR_3 = NULLIF(@i_STPV_DES_TIP_VALOR_3, ''),
            AUD_UPD_USER         = @i_AUD_UPD_USER,
            AUD_UPD_FEC          = GETDATE()
        WHERE CTPV_COD_TIP_VALOR = @i_CTPV_COD_TIP_VALOR
          AND CTPV_TIP_VALOR     = @i_CTPV_TIP_VALOR;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Registro no encontrado';
            RETURN;
        END

        SET @o_resultMessage = '1|Actualización correcta';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Cambio de estado. La API envía 'A'/'I'; la BD usa 'V' (vigente) / 'I'.
-- Se acepta 'A' como sinónimo de 'V'.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[PRMKK_UPD_BOF_EST_TIP_VALOR]
    @i_CTPV_COD_TIP_VALOR VARCHAR(20),
    @i_CTPV_TIP_VALOR     VARCHAR(8),
    @i_FTPV_ESTADO        VARCHAR(10),
    @i_AUD_UPD_USER       VARCHAR(16) = NULL,
    @o_resultMessage      VARCHAR(4000) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @estado CHAR(1) = CASE UPPER(@i_FTPV_ESTADO) WHEN 'A' THEN 'V' ELSE UPPER(LEFT(@i_FTPV_ESTADO, 1)) END;

    BEGIN TRY
        IF @estado NOT IN ('V', 'I')
        BEGIN
            SET @o_resultMessage = '0|Estado no válido. Use V/A (vigente) o I (inactivo)';
            RETURN;
        END

        UPDATE TMKK_TIP_VALOR
        SET FTPV_ESTADO  = @estado,
            AUD_UPD_USER = @i_AUD_UPD_USER,
            AUD_UPD_FEC  = GETDATE()
        WHERE CTPV_COD_TIP_VALOR = @i_CTPV_COD_TIP_VALOR
          AND CTPV_TIP_VALOR     = @i_CTPV_TIP_VALOR;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Registro no encontrado';
            RETURN;
        END

        SET @o_resultMessage = CASE @estado WHEN 'V' THEN '1|Activación correcta' ELSE '1|Anulación correcta' END;
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Eliminación lógica (la API ya invoca este SP y no existía).
-- Si no se envía @i_CTPV_TIP_VALOR se inactiva el grupo completo.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE [dbo].[PRMKK_DEL_BOF_TIP_VALOR]
    @i_CTPV_COD_TIP_VALOR VARCHAR(20),
    @i_CTPV_TIP_VALOR     VARCHAR(8)  = NULL,
    @i_AUD_UPD_USER       VARCHAR(16) = NULL,
    @o_resultMessage      VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE TMKK_TIP_VALOR
        SET FTPV_ESTADO  = 'I',
            AUD_UPD_USER = @i_AUD_UPD_USER,
            AUD_UPD_FEC  = GETDATE()
        WHERE CTPV_COD_TIP_VALOR = @i_CTPV_COD_TIP_VALOR
          AND (NULLIF(@i_CTPV_TIP_VALOR, '') IS NULL OR CTPV_TIP_VALOR = @i_CTPV_TIP_VALOR);

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Registro no encontrado';
            RETURN;
        END

        SET @o_resultMessage = '1|Eliminación correcta';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ==============================================================================
-- 2. INCONSISTENCIAS DE ESQUEMA
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 2.1 TMKK_SISTEMA: estado por defecto '1' -> 'V' (como el resto de tablas)
-- ------------------------------------------------------------------------------
DECLARE @df SYSNAME, @sql NVARCHAR(400);

SELECT @df = dc.name
FROM sys.default_constraints dc
JOIN sys.columns c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id
WHERE dc.parent_object_id = OBJECT_ID('dbo.TMKK_SISTEMA') AND c.name = 'SIT_ESTADO'
  AND dc.definition <> '(''V'')';

IF @df IS NOT NULL
BEGIN
    SET @sql = N'ALTER TABLE dbo.TMKK_SISTEMA DROP CONSTRAINT ' + QUOTENAME(@df);
    EXEC sp_executesql @sql;
    ALTER TABLE dbo.TMKK_SISTEMA ADD CONSTRAINT DF_TMKK_SISTEMA_ESTADO DEFAULT ('V') FOR SIT_ESTADO;
END

UPDATE dbo.TMKK_SISTEMA SET SIT_ESTADO = 'V' WHERE SIT_ESTADO = '1';
GO

-- ------------------------------------------------------------------------------
-- 2.2 TMKK_VENTA.SVEN_TIPO_VENTA: VARCHAR(50) -> INT, igual que en TMKK_LLAMADA
--     y TMKK_PERSONAL (código del grupo TIPO_VENTA en TMKK_TIP_VALOR).
--     Si hay ventas guardadas con la descripción ('PORTABILIDAD', ...) se
--     convierten a su código antes de cambiar el tipo.
-- ------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.TMKK_VENTA') AND c.name = 'SVEN_TIPO_VENTA' AND t.name = 'varchar')
BEGIN
    UPDATE v
    SET SVEN_TIPO_VENTA = tv.CTPV_TIP_VALOR
    FROM dbo.TMKK_VENTA v
    JOIN dbo.TMKK_TIP_VALOR tv
      ON tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA'
     AND tv.STPV_DES_TIP_VALOR_1 = LTRIM(RTRIM(v.SVEN_TIPO_VENTA))
    WHERE TRY_CONVERT(INT, v.SVEN_TIPO_VENTA) IS NULL;

    IF EXISTS (SELECT 1 FROM dbo.TMKK_VENTA
               WHERE SVEN_TIPO_VENTA IS NOT NULL AND TRY_CONVERT(INT, SVEN_TIPO_VENTA) IS NULL)
        RAISERROR('TMKK_VENTA.SVEN_TIPO_VENTA tiene valores que no corresponden a TIPO_VENTA. Corríjalos y vuelva a ejecutar.', 16, 1);
    ELSE
        ALTER TABLE dbo.TMKK_VENTA ALTER COLUMN SVEN_TIPO_VENTA INT NULL;
END
GO

-- ------------------------------------------------------------------------------
-- 2.3 TPLS_PERSONA.FPER_TIP_DOC_IDENTIDAD: CHAR(1) -> TINYINT + FK a
--     TMKK_TIP_DOC_IDENTIDAD (cuya PK es TINYINT).
-- ------------------------------------------------------------------------------
IF EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
           WHERE c.object_id = OBJECT_ID('dbo.TPLS_PERSONA') AND c.name = 'FPER_TIP_DOC_IDENTIDAD' AND t.name = 'char')
BEGIN
    IF EXISTS (SELECT 1 FROM dbo.TPLS_PERSONA
               WHERE FPER_TIP_DOC_IDENTIDAD IS NOT NULL
                 AND (TRY_CONVERT(TINYINT, FPER_TIP_DOC_IDENTIDAD) IS NULL
                      OR TRY_CONVERT(TINYINT, FPER_TIP_DOC_IDENTIDAD) NOT IN (SELECT CTDI_ID_DOCUMENTO FROM dbo.TMKK_TIP_DOC_IDENTIDAD)))
        RAISERROR('TPLS_PERSONA.FPER_TIP_DOC_IDENTIDAD tiene valores que no existen en TMKK_TIP_DOC_IDENTIDAD. Corríjalos y vuelva a ejecutar.', 16, 1);
    ELSE
        ALTER TABLE dbo.TPLS_PERSONA ALTER COLUMN FPER_TIP_DOC_IDENTIDAD TINYINT NULL;
END
GO

IF NOT EXISTS (SELECT 1 FROM sys.foreign_keys WHERE name = 'FK_TPLS_PERSONA_TIP_DOC')
   AND EXISTS (SELECT 1 FROM sys.columns c JOIN sys.types t ON t.user_type_id = c.user_type_id
               WHERE c.object_id = OBJECT_ID('dbo.TPLS_PERSONA') AND c.name = 'FPER_TIP_DOC_IDENTIDAD' AND t.name = 'tinyint')
    ALTER TABLE dbo.TPLS_PERSONA ADD CONSTRAINT FK_TPLS_PERSONA_TIP_DOC
        FOREIGN KEY (FPER_TIP_DOC_IDENTIDAD) REFERENCES dbo.TMKK_TIP_DOC_IDENTIDAD (CTDI_ID_DOCUMENTO);
GO

-- ------------------------------------------------------------------------------
-- 2.4 TMKK_LLAMADA.SLLM_OBSERVACIONES: VARCHAR(100) se queda corto
-- ------------------------------------------------------------------------------
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'SLLM_OBSERVACIONES') < 500
    ALTER TABLE dbo.TMKK_LLAMADA ALTER COLUMN SLLM_OBSERVACIONES VARCHAR(500) NULL;
GO

-- ==============================================================================
-- 3. DATOS DE CATÁLOGO ALINEADOS CON EL FRONTEND
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 3.1 TMKK_ASISTENCIA: SASI_VISTA y SASI_COLOR repetían el nombre.
--     SASI_VISTA = código que usa el front (src/composables/useAsistencia.ts)
--     SASI_COLOR = color de Vuetify que usa el front para chips y gráficos
-- ------------------------------------------------------------------------------
UPDATE a
SET SASI_VISTA   = x.vista,
    SASI_COLOR   = x.color,
    AUD_UPD_USER = 'AIW_SISTEMAS',
    AUD_UPD_FEC  = GETDATE()
FROM dbo.TMKK_ASISTENCIA a
JOIN (VALUES
    ('P',  'PUNTUAL',             'success'),
    ('T',  'TARDANZA',            'warning'),
    ('FI', 'FALTA_INJUSTIFICADA', 'error'),
    ('FJ', 'FALTA_JUSTIFICADA',   'info'),
    ('LM', 'LICENCIA_MATERNIDAD', 'secondary'),
    ('LP', 'LICENCIA_PATERNIDAD', 'secondary'),
    ('DM', 'DESCANSO_MEDICO',     'primary'),
    ('DS', 'DESCANSO_SEMANAL',    'secondary'),
    ('OB', 'OBSERVADO',           'secondary'),
    ('V',  'VACACIONES',          'secondary')
) x (abrev, vista, color) ON x.abrev = a.SASI_ABREVIATURA
WHERE ISNULL(a.SASI_VISTA, '') <> x.vista OR ISNULL(a.SASI_COLOR, '') <> x.color;
GO

-- ------------------------------------------------------------------------------
-- 3.2 Estado de venta INGRESADO (lo usa la Lista de Ventas y no existía)
-- ------------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR WHERE CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND STPV_DES_TIP_VALOR_1 = 'INGRESADO')
    INSERT INTO dbo.TMKK_TIP_VALOR (CTPV_COD_TIP_VALOR, CTPV_TIP_VALOR, STPV_DES_TIP_VALOR_1, FTPV_ESTADO, AUD_INS_FEC, AUD_INS_USER)
    VALUES ('TIP_ESTADO_VENTA', '8', 'INGRESADO', 'V', GETDATE(), 'AIW_SISTEMAS');
GO
