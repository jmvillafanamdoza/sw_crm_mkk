-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 06: LLAMADAS (Dash Tipificaciones)
--   Tablas : TMKK_TIPIFICACION (catálogo con grupo CONTACTADO / NO_CONTACTADO)
--            columnas nuevas en TMKK_LLAMADA (tipificación, asesor, campaña, duración)
--   SPs    : registro y consulta de llamadas, catálogo de tipificaciones,
--            resumen por tipificación y matriz "Cantidad por Vendedor".
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_TIPIFICACION') IS NULL
CREATE TABLE dbo.TMKK_TIPIFICACION (
    CTIP_ID_TIPIFICACION INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_TIPIFICACION PRIMARY KEY,
    STIP_NOMBRE          VARCHAR(150) NOT NULL,
    STIP_GRUPO           VARCHAR(20) NOT NULL,       -- CONTACTADO / NO_CONTACTADO
    CTIP_ID_PADRE        INT NULL,                   -- para tipificación de nivel 2
    FTIP_VENTA           CHAR(1) NOT NULL CONSTRAINT DF_TMKK_TIP_VENTA DEFAULT 'N',  -- S = terminó en venta
    STIP_ID_EXTERNO      VARCHAR(30) NULL,           -- código de status en Vicidial
    NTIP_ORDEN           INT NOT NULL CONSTRAINT DF_TMKK_TIP_ORDEN DEFAULT 0,
    FTIP_ESTADO          CHAR(1) NOT NULL CONSTRAINT DF_TMKK_TIP_ESTADO DEFAULT 'V',
    AUD_INS_FEC          DATETIME NULL,
    AUD_INS_USER         VARCHAR(16) NULL,
    AUD_UPD_FEC          DATETIME NULL,
    AUD_UPD_USER         VARCHAR(16) NULL,
    CONSTRAINT UQ_TMKK_TIPIFICACION_NOMBRE UNIQUE (STIP_NOMBRE),
    CONSTRAINT CK_TMKK_TIPIFICACION_GRUPO CHECK (STIP_GRUPO IN ('CONTACTADO', 'NO_CONTACTADO')),
    CONSTRAINT FK_TMKK_TIPIFICACION_PADRE FOREIGN KEY (CTIP_ID_PADRE) REFERENCES dbo.TMKK_TIPIFICACION (CTIP_ID_TIPIFICACION)
);
GO

IF COL_LENGTH('dbo.TMKK_LLAMADA', 'CTIP_ID_TIPIFICACION') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD CTIP_ID_TIPIFICACION INT NULL
        CONSTRAINT FK_TMKK_LLAMADA_TIPIFICACION REFERENCES dbo.TMKK_TIPIFICACION (CTIP_ID_TIPIFICACION);
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'CPEL_ID_PERSONAL') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD CPEL_ID_PERSONAL INT NULL
        CONSTRAINT FK_TMKK_LLAMADA_PERSONAL REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL);
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'CCAM_ID_CAMPANIA') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD CCAM_ID_CAMPANIA INT NULL
        CONSTRAINT FK_TMKK_LLAMADA_CAMPANIA REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA);
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'DLLM_FEC_LLAMADA') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD DLLM_FEC_LLAMADA DATETIME NULL;
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'NLLM_DURACION_SEG') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD NLLM_DURACION_SEG INT NULL;
IF COL_LENGTH('dbo.TMKK_LLAMADA', 'SLLM_ID_EXTERNO') IS NULL
    ALTER TABLE dbo.TMKK_LLAMADA ADD SLLM_ID_EXTERNO VARCHAR(50) NULL;      -- id de la llamada en Vicidial
GO

-- Asesor de las llamadas existentes a partir de su usuario
UPDATE l
SET CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL
FROM dbo.TMKK_LLAMADA l
JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = l.CLLM_ID_USUARIO
WHERE l.CPEL_ID_PERSONAL IS NULL;

UPDATE dbo.TMKK_LLAMADA SET DLLM_FEC_LLAMADA = AUD_INS_FEC WHERE DLLM_FEC_LLAMADA IS NULL AND AUD_INS_FEC IS NOT NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_LLAMADA_FECHA')
    CREATE INDEX IX_TMKK_LLAMADA_FECHA ON dbo.TMKK_LLAMADA (DLLM_FEC_LLAMADA)
        INCLUDE (CPEL_ID_PERSONAL, CTIP_ID_TIPIFICACION, CCAM_ID_CAMPANIA, NLLM_DURACION_SEG);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_LLAMADA_EXTERNO')
    CREATE UNIQUE INDEX UX_TMKK_LLAMADA_EXTERNO ON dbo.TMKK_LLAMADA (SLLM_ID_EXTERNO) WHERE SLLM_ID_EXTERNO IS NOT NULL;
GO

-- ==============================================================================
-- 2. DATOS INICIALES (src/composables/useTipificaciones.ts)
-- ==============================================================================
INSERT INTO dbo.TMKK_TIPIFICACION (STIP_NOMBRE, STIP_GRUPO, FTIP_VENTA, NTIP_ORDEN, AUD_INS_FEC, AUD_INS_USER)
SELECT t.nombre, t.grupo, t.venta, t.orden, GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('Escuchó Oferta, Venta Realizada',        'CONTACTADO',    'S', 1),
    ('Escuchó Oferta, Rechazó',                'CONTACTADO',    'N', 2),
    ('No es titular',                          'CONTACTADO',    'N', 3),
    ('Cortó Llamada Antes de Oferta',          'CONTACTADO',    'N', 4),
    ('No Aplica',                              'CONTACTADO',    'N', 5),
    ('Otras consultas',                        'CONTACTADO',    'N', 6),
    ('Responde llamada, pide volver a llamar', 'CONTACTADO',    'N', 7),
    ('Llamada Fallada',                        'CONTACTADO',    'N', 8),
    ('Escuchó Oferta, Solicitó Tiempo',        'CONTACTADO',    'N', 9),
    ('Llamada Fallida',                        'NO_CONTACTADO', 'N', 10)
) t (nombre, grupo, venta, orden)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIPIFICACION x WHERE x.STIP_NOMBRE = t.nombre);
GO

-- ==============================================================================
-- 3. STORED PROCEDURES
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_TIPIFICACION
    @i_GRUPO  VARCHAR(20) = NULL,
    @i_ESTADO CHAR(1)     = 'V'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CTIP_ID_TIPIFICACION, STIP_NOMBRE, STIP_GRUPO, CTIP_ID_PADRE, FTIP_VENTA, STIP_ID_EXTERNO, NTIP_ORDEN, FTIP_ESTADO
    FROM dbo.TMKK_TIPIFICACION
    WHERE (NULLIF(@i_GRUPO, '') IS NULL OR STIP_GRUPO = @i_GRUPO)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR FTIP_ESTADO = @i_ESTADO)
    ORDER BY NTIP_ORDEN, STIP_NOMBRE;
END
GO

-- ------------------------------------------------------------------------------
-- Registro de llamada (desde el CRM o importada de Vicidial con @i_ID_EXTERNO;
-- si el id externo ya existe, se actualiza en lugar de duplicarse).
-- El asesor puede venir por personal, por usuario o por "ID Vici".
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_LLAMADA
    @i_TELEFONO             VARCHAR(20),
    @i_CTIP_ID_TIPIFICACION INT          = NULL,
    @i_CPEL_ID_PERSONAL     INT          = NULL,
    @i_CUSU_ID_USUARIO      INT          = NULL,
    @i_ID_VICI              VARCHAR(16)  = NULL,
    @i_CCAM_ID_CAMPANIA     INT          = NULL,
    @i_TIPO_VENTA           INT          = NULL,
    @i_FEC_LLAMADA          DATETIME     = NULL,
    @i_DURACION_SEG         INT          = NULL,
    @i_OBSERVACIONES        VARCHAR(500) = NULL,
    @i_ID_EXTERNO           VARCHAR(50)  = NULL,
    @i_AUD_INS_USER         VARCHAR(16),
    @o_CLLM_ID_LLAMADA      INT OUTPUT,
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @personal INT = @i_CPEL_ID_PERSONAL, @usuario INT = @i_CUSU_ID_USUARIO, @campania INT = @i_CCAM_ID_CAMPANIA,
                @tip1 VARCHAR(100), @tip2 VARCHAR(100);

        SET @o_CLLM_ID_LLAMADA = NULL;  -- un OUTPUT también recibe el valor del llamador

        IF @personal IS NULL AND @usuario IS NOT NULL
            SELECT @personal = CPEL_ID_PERSONAL FROM dbo.TMKK_PERSONAL WHERE CUSU_ID_USUARIO = @usuario;
        IF @personal IS NULL AND NULLIF(@i_ID_VICI, '') IS NOT NULL
            SELECT TOP (1) @personal = CPEL_ID_PERSONAL FROM dbo.TMKK_PERSONAL
            WHERE CPEl_ID_VICIDIAL = @i_ID_VICI ORDER BY CASE FPEl_ESTADO WHEN 'V' THEN 0 ELSE 1 END;

        SELECT @usuario = COALESCE(@usuario, CUSU_ID_USUARIO), @campania = COALESCE(@campania, CCAM_ID_CAMPANIA)
        FROM dbo.TMKK_PERSONAL WHERE CPEL_ID_PERSONAL = @personal;

        -- Se conservan los textos de tipificación en las columnas originales
        SELECT @tip1 = COALESCE(pa.STIP_NOMBRE, t.STIP_NOMBRE), @tip2 = CASE WHEN pa.CTIP_ID_TIPIFICACION IS NOT NULL THEN t.STIP_NOMBRE END
        FROM dbo.TMKK_TIPIFICACION t
        LEFT JOIN dbo.TMKK_TIPIFICACION pa ON pa.CTIP_ID_TIPIFICACION = t.CTIP_ID_PADRE
        WHERE t.CTIP_ID_TIPIFICACION = @i_CTIP_ID_TIPIFICACION;

        IF @i_CTIP_ID_TIPIFICACION IS NOT NULL AND @tip1 IS NULL
        BEGIN
            SET @o_resultMessage = '0|Tipificación no válida';
            RETURN;
        END

        SELECT @o_CLLM_ID_LLAMADA = CLLM_ID_LLAMADA FROM dbo.TMKK_LLAMADA
        WHERE NULLIF(@i_ID_EXTERNO, '') IS NOT NULL AND SLLM_ID_EXTERNO = @i_ID_EXTERNO;

        IF @o_CLLM_ID_LLAMADA IS NOT NULL
        BEGIN
            UPDATE dbo.TMKK_LLAMADA
            SET SLLM_TELEFONO = @i_TELEFONO, CTIP_ID_TIPIFICACION = @i_CTIP_ID_TIPIFICACION,
                SLLM_TIPIFICACION_NIVEL_1 = @tip1, SLLM_TIPIFICACION_NIVEL_2 = @tip2,
                CPEL_ID_PERSONAL = @personal, CLLM_ID_USUARIO = @usuario, CCAM_ID_CAMPANIA = @campania,
                SVEN_TIPO_VENTA = @i_TIPO_VENTA, DLLM_FEC_LLAMADA = COALESCE(@i_FEC_LLAMADA, DLLM_FEC_LLAMADA),
                NLLM_DURACION_SEG = @i_DURACION_SEG, SLLM_OBSERVACIONES = NULLIF(@i_OBSERVACIONES, ''),
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
            WHERE CLLM_ID_LLAMADA = @o_CLLM_ID_LLAMADA;

            SET @o_resultMessage = '1|Llamada actualizada';
            RETURN;
        END

        INSERT INTO dbo.TMKK_LLAMADA
            (CLLM_ID_USUARIO, SLLM_TELEFONO, SVEN_TIPO_VENTA, SLLM_TIPIFICACION_NIVEL_1, SLLM_TIPIFICACION_NIVEL_2, SLLM_OBSERVACIONES,
             FLLM_ESTADO, CTIP_ID_TIPIFICACION, CPEL_ID_PERSONAL, CCAM_ID_CAMPANIA, DLLM_FEC_LLAMADA, NLLM_DURACION_SEG, SLLM_ID_EXTERNO,
             AUD_INS_FEC, AUD_INS_USER)
        VALUES
            (@usuario, @i_TELEFONO, @i_TIPO_VENTA, @tip1, @tip2, NULLIF(@i_OBSERVACIONES, ''),
             'V', @i_CTIP_ID_TIPIFICACION, @personal, @campania, ISNULL(@i_FEC_LLAMADA, GETDATE()), @i_DURACION_SEG, NULLIF(@i_ID_EXTERNO, ''),
             GETDATE(), @i_AUD_INS_USER);

        SET @o_CLLM_ID_LLAMADA = SCOPE_IDENTITY();
        SET @o_resultMessage = '1|Llamada registrada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_LLAMADA
    @i_FEC_INICIO         DATE,
    @i_FEC_FIN            DATE,
    @i_CCAM_ID_CAMPANIA   INT          = NULL,
    @i_CPEL_ID_SUPERVISOR INT          = NULL,
    @i_CPEL_ID_PERSONAL   INT          = NULL,
    @i_CTIP_ID_TIPIFICACION INT        = NULL,
    @i_TELEFONO           VARCHAR(20)  = NULL,
    @i_PAGINA             INT          = 1,
    @i_TAMANIO_PAGINA     INT          = 50     -- -1 = todos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        l.CLLM_ID_LLAMADA,
        l.DLLM_FEC_LLAMADA,
        l.SLLM_TELEFONO,
        l.CPEL_ID_PERSONAL,
        COALESCE(p.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)), '')) AS SVENDEDOR,
        c.SCAM_NOMBRE AS SCAMPANIA,
        l.CTIP_ID_TIPIFICACION,
        COALESCE(t.STIP_NOMBRE, l.SLLM_TIPIFICACION_NIVEL_1) AS STIPIFICACION,
        t.STIP_GRUPO,
        l.NLLM_DURACION_SEG,
        l.SVEN_TIPO_VENTA,
        l.SLLM_OBSERVACIONES,
        COUNT(*) OVER () AS NTOTAL_REGISTROS
    FROM dbo.TMKK_LLAMADA l
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = l.CPEL_ID_PERSONAL
    LEFT JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = l.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_TIPIFICACION t ON t.CTIP_ID_TIPIFICACION = l.CTIP_ID_TIPIFICACION
    WHERE l.FLLM_ESTADO = 'V'
      AND l.DLLM_FEC_LLAMADA >= @i_FEC_INICIO AND l.DLLM_FEC_LLAMADA < DATEADD(DAY, 1, @i_FEC_FIN)
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR l.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_SUPERVISOR IS NULL OR pe.CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR)
      AND (@i_CPEL_ID_PERSONAL IS NULL OR l.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL)
      AND (@i_CTIP_ID_TIPIFICACION IS NULL OR l.CTIP_ID_TIPIFICACION = @i_CTIP_ID_TIPIFICACION)
      AND (NULLIF(@i_TELEFONO, '') IS NULL OR l.SLLM_TELEFONO LIKE '%' + @i_TELEFONO + '%')
    ORDER BY l.DLLM_FEC_LLAMADA DESC
    OFFSET CASE WHEN @i_TAMANIO_PAGINA = -1 THEN 0 ELSE (ISNULL(@i_PAGINA, 1) - 1) * @i_TAMANIO_PAGINA END ROWS
    FETCH NEXT CASE WHEN @i_TAMANIO_PAGINA = -1 THEN 2147483647 ELSE @i_TAMANIO_PAGINA END ROWS ONLY;
END
GO

-- ------------------------------------------------------------------------------
-- Dash Tipificaciones. Dos result sets (QueryMultiple):
--   1. Resumen por tipificación: cantidad, % y tiempo promedio (mm:ss)
--   2. "Cantidad por Vendedor" en formato largo (vendedor x tipificación);
--      el front arma la matriz con columnasVendedor.
-- Ambos salen de las mismas llamadas, así los totales siempre cuadran.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_LLAMADA_DASH_TIPIFICACION
    @i_FEC_INICIO         DATE,
    @i_FEC_FIN            DATE,
    @i_CCAM_ID_CAMPANIA   INT = NULL,
    @i_CPEL_ID_SUPERVISOR INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT l.CPEL_ID_PERSONAL, l.CTIP_ID_TIPIFICACION, l.NLLM_DURACION_SEG
    INTO #ll
    FROM dbo.TMKK_LLAMADA l
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = l.CPEL_ID_PERSONAL
    WHERE l.FLLM_ESTADO = 'V'
      AND l.CTIP_ID_TIPIFICACION IS NOT NULL
      AND l.DLLM_FEC_LLAMADA >= @i_FEC_INICIO AND l.DLLM_FEC_LLAMADA < DATEADD(DAY, 1, @i_FEC_FIN)
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR l.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_SUPERVISOR IS NULL OR pe.CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR);

    DECLARE @total INT = (SELECT COUNT(*) FROM #ll);

    -- 1
    SELECT t.CTIP_ID_TIPIFICACION, t.STIP_NOMBRE AS STIPIFICACION, t.STIP_GRUPO,
           COUNT(l.CTIP_ID_TIPIFICACION) AS NCANTIDAD,
           CAST(CASE WHEN @total = 0 THEN 0 ELSE 100.0 * COUNT(l.CTIP_ID_TIPIFICACION) / @total END AS DECIMAL(5, 2)) AS NPORCENTAJE,
           ISNULL(AVG(l.NLLM_DURACION_SEG), 0) AS NTIEMPO_PROMEDIO_SEG,
           RIGHT('0' + CAST(ISNULL(AVG(l.NLLM_DURACION_SEG), 0) / 60 AS VARCHAR(5)), 2) + ':' +
           RIGHT('0' + CAST(ISNULL(AVG(l.NLLM_DURACION_SEG), 0) % 60 AS VARCHAR(2)), 2) AS STIEMPO_PROMEDIO
    FROM dbo.TMKK_TIPIFICACION t
    LEFT JOIN #ll l ON l.CTIP_ID_TIPIFICACION = t.CTIP_ID_TIPIFICACION
    WHERE t.FTIP_ESTADO = 'V'
    GROUP BY t.CTIP_ID_TIPIFICACION, t.STIP_NOMBRE, t.STIP_GRUPO, t.NTIP_ORDEN
    ORDER BY t.NTIP_ORDEN;

    -- 2
    SELECT l.CPEL_ID_PERSONAL,
           COALESCE(p.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)), ''), 'SIN ASESOR') AS SVENDEDOR,
           t.STIP_NOMBRE AS STIPIFICACION,
           COUNT(*) AS NCANTIDAD
    FROM #ll l
    JOIN dbo.TMKK_TIPIFICACION t ON t.CTIP_ID_TIPIFICACION = l.CTIP_ID_TIPIFICACION
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = l.CPEL_ID_PERSONAL
    LEFT JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    GROUP BY l.CPEL_ID_PERSONAL, p.SPER_NOM_COMPLETO, p.SPER_APE_PATERNO, p.SPER_APE_MATERNO, p.SPER_NOMBRE, t.STIP_NOMBRE
    ORDER BY SVENDEDOR, t.STIP_NOMBRE;
END
GO
