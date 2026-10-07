-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 08: COMISIONES
--   La página comisiones.vue aún está en construcción; el dashboard ya muestra
--   "Comisiones del Mes". Este script deja la base:
--   Tablas : TMKK_COMISION_REGLA   (cuánto paga cada venta: monto fijo y/o % del plan)
--            TMKK_COMISION         (liquidación por asesor y periodo)
--            TMKK_COMISION_DETALLE (ventas que componen cada liquidación)
--   SPs    : CRUD de reglas, cálculo del periodo, consulta, detalle y aprobación.
--
-- Una venta comisiona cuando está ACTIVADA (CVEN_ESTADO_VENTA = '1') y su fecha
-- de activación cae en el periodo. Si varias reglas aplican, gana la más
-- específica (tipo + plan + campaña) y, a igualdad, la más reciente.
-- Estados de liquidación: P pendiente, A aprobada, G pagada, X anulada.
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_COMISION_REGLA') IS NULL
CREATE TABLE dbo.TMKK_COMISION_REGLA (
    CCRG_ID_REGLA        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_COMISION_REGLA PRIMARY KEY,
    SCRG_NOMBRE          VARCHAR(100) NOT NULL,
    SVEN_TIPO_VENTA      INT NULL,               -- NULL = cualquier tipo
    CPLN_ID_CODIGO       INT NULL,               -- NULL = cualquier plan
    CCAM_ID_CAMPANIA     INT NULL,               -- NULL = cualquier campaña
    NCRG_MONTO_FIJO      DECIMAL(14, 2) NULL,
    NCRG_PORCENTAJE      DECIMAL(5, 2) NULL,     -- % sobre el valor del plan
    DCRG_VIGENCIA_INICIO DATE NOT NULL,
    DCRG_VIGENCIA_FIN    DATE NULL,
    FCRG_ESTADO          CHAR(1) NOT NULL CONSTRAINT DF_TMKK_CRG_ESTADO DEFAULT 'V',
    AUD_INS_FEC          DATETIME NULL,
    AUD_INS_USER         VARCHAR(16) NULL,
    AUD_UPD_FEC          DATETIME NULL,
    AUD_UPD_USER         VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_CRG_PLAN FOREIGN KEY (CPLN_ID_CODIGO) REFERENCES dbo.TMKK_PLAN (CPLN_ID_CODIGO),
    CONSTRAINT FK_TMKK_CRG_CAMPANIA FOREIGN KEY (CCAM_ID_CAMPANIA) REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA),
    CONSTRAINT CK_TMKK_CRG_MONTO CHECK (NCRG_MONTO_FIJO IS NOT NULL OR NCRG_PORCENTAJE IS NOT NULL),
    CONSTRAINT CK_TMKK_CRG_VIGENCIA CHECK (DCRG_VIGENCIA_FIN IS NULL OR DCRG_VIGENCIA_FIN >= DCRG_VIGENCIA_INICIO)
);
GO

IF OBJECT_ID('dbo.TMKK_COMISION') IS NULL
CREATE TABLE dbo.TMKK_COMISION (
    CCOM_ID_COMISION     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_COMISION PRIMARY KEY,
    NCOM_PERIODO         INT NOT NULL,           -- AAAAMM
    CPEL_ID_PERSONAL     INT NOT NULL,
    NCOM_CANT_VENTAS     INT NOT NULL,
    NCOM_MONTO_VENTAS    DECIMAL(14, 2) NOT NULL,
    NCOM_MONTO_COMISION  DECIMAL(14, 2) NOT NULL,
    FCOM_ESTADO          CHAR(1) NOT NULL CONSTRAINT DF_TMKK_COM_ESTADO DEFAULT 'P',
    AUD_INS_FEC          DATETIME NULL,
    AUD_INS_USER         VARCHAR(16) NULL,
    AUD_UPD_FEC          DATETIME NULL,
    AUD_UPD_USER         VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_COM_PERSONAL FOREIGN KEY (CPEL_ID_PERSONAL) REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL),
    CONSTRAINT CK_TMKK_COM_ESTADO CHECK (FCOM_ESTADO IN ('P', 'A', 'G', 'X'))
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_COM_PERIODO_PERSONAL')
    CREATE UNIQUE INDEX UX_TMKK_COM_PERIODO_PERSONAL ON dbo.TMKK_COMISION (NCOM_PERIODO, CPEL_ID_PERSONAL) WHERE FCOM_ESTADO <> 'X';
GO

IF OBJECT_ID('dbo.TMKK_COMISION_DETALLE') IS NULL
CREATE TABLE dbo.TMKK_COMISION_DETALLE (
    CCOM_ID_COMISION     INT NOT NULL,
    CVEN_ID_VENTA        INT NOT NULL,
    CCRG_ID_REGLA        INT NULL,
    NCOD_VALOR_VENTA     DECIMAL(14, 2) NOT NULL,
    NCOD_MONTO           DECIMAL(14, 2) NOT NULL,
    CONSTRAINT PK_TMKK_COMISION_DETALLE PRIMARY KEY (CCOM_ID_COMISION, CVEN_ID_VENTA),
    CONSTRAINT FK_TMKK_COD_COMISION FOREIGN KEY (CCOM_ID_COMISION) REFERENCES dbo.TMKK_COMISION (CCOM_ID_COMISION) ON DELETE CASCADE,
    CONSTRAINT FK_TMKK_COD_VENTA FOREIGN KEY (CVEN_ID_VENTA) REFERENCES dbo.TMKK_VENTA (CVEN_ID_VENTA),
    CONSTRAINT FK_TMKK_COD_REGLA FOREIGN KEY (CCRG_ID_REGLA) REFERENCES dbo.TMKK_COMISION_REGLA (CCRG_ID_REGLA)
);
GO

-- ==============================================================================
-- 2. REGLAS
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_COMISION_REGLA
    @i_ESTADO CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT r.CCRG_ID_REGLA, r.SCRG_NOMBRE, r.SVEN_TIPO_VENTA, tv.STPV_DES_TIP_VALOR_1 AS STIPO_VENTA,
           r.CPLN_ID_CODIGO, pl.SPLN_NOMBRE AS SPLAN, r.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE AS SCAMPANIA,
           r.NCRG_MONTO_FIJO, r.NCRG_PORCENTAJE, r.DCRG_VIGENCIA_INICIO, r.DCRG_VIGENCIA_FIN, r.FCRG_ESTADO
    FROM dbo.TMKK_COMISION_REGLA r
    LEFT JOIN dbo.TMKK_TIP_VALOR tv ON tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.CTPV_TIP_VALOR = CAST(r.SVEN_TIPO_VENTA AS VARCHAR(8))
    LEFT JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = r.CPLN_ID_CODIGO
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = r.CCAM_ID_CAMPANIA
    WHERE NULLIF(@i_ESTADO, '') IS NULL OR r.FCRG_ESTADO = @i_ESTADO
    ORDER BY r.DCRG_VIGENCIA_INICIO DESC, r.SCRG_NOMBRE;
END
GO

-- Alta (sin @i_CCRG_ID_REGLA) o edición (con @i_CCRG_ID_REGLA) de una regla
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_COMISION_REGLA
    @i_CCRG_ID_REGLA     INT            = NULL,
    @i_NOMBRE            VARCHAR(100),
    @i_TIPO_VENTA        INT            = NULL,
    @i_CPLN_ID_CODIGO    INT            = NULL,
    @i_CCAM_ID_CAMPANIA  INT            = NULL,
    @i_MONTO_FIJO        DECIMAL(14, 2) = NULL,
    @i_PORCENTAJE        DECIMAL(5, 2)  = NULL,
    @i_VIGENCIA_INICIO   DATE,
    @i_VIGENCIA_FIN      DATE           = NULL,
    @i_AUD_USER          VARCHAR(16),
    @o_CCRG_ID_REGLA     INT OUTPUT,
    @o_resultMessage     VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @o_CCRG_ID_REGLA = @i_CCRG_ID_REGLA;

        IF @i_MONTO_FIJO IS NULL AND @i_PORCENTAJE IS NULL
        BEGIN
            SET @o_resultMessage = '0|Indique un monto fijo o un porcentaje';
            RETURN;
        END

        IF @i_VIGENCIA_FIN IS NOT NULL AND @i_VIGENCIA_FIN < @i_VIGENCIA_INICIO
        BEGIN
            SET @o_resultMessage = '0|La vigencia final no puede ser menor a la inicial';
            RETURN;
        END

        IF @i_CCRG_ID_REGLA IS NULL
        BEGIN
            INSERT INTO dbo.TMKK_COMISION_REGLA (SCRG_NOMBRE, SVEN_TIPO_VENTA, CPLN_ID_CODIGO, CCAM_ID_CAMPANIA, NCRG_MONTO_FIJO, NCRG_PORCENTAJE,
                                                 DCRG_VIGENCIA_INICIO, DCRG_VIGENCIA_FIN, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@i_NOMBRE, @i_TIPO_VENTA, @i_CPLN_ID_CODIGO, @i_CCAM_ID_CAMPANIA, @i_MONTO_FIJO, @i_PORCENTAJE,
                    @i_VIGENCIA_INICIO, @i_VIGENCIA_FIN, GETDATE(), @i_AUD_USER);
            SET @o_CCRG_ID_REGLA = SCOPE_IDENTITY();
            SET @o_resultMessage = '1|Regla registrada';
        END
        ELSE
        BEGIN
            UPDATE dbo.TMKK_COMISION_REGLA
            SET SCRG_NOMBRE = @i_NOMBRE, SVEN_TIPO_VENTA = @i_TIPO_VENTA, CPLN_ID_CODIGO = @i_CPLN_ID_CODIGO,
                CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA, NCRG_MONTO_FIJO = @i_MONTO_FIJO, NCRG_PORCENTAJE = @i_PORCENTAJE,
                DCRG_VIGENCIA_INICIO = @i_VIGENCIA_INICIO, DCRG_VIGENCIA_FIN = @i_VIGENCIA_FIN,
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CCRG_ID_REGLA = @i_CCRG_ID_REGLA;

            IF @@ROWCOUNT = 0
            BEGIN
                SET @o_resultMessage = '0|Regla no encontrada';
                RETURN;
            END
            SET @o_resultMessage = '1|Regla actualizada';
        END
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_EST_COMISION_REGLA
    @i_CCRG_ID_REGLA INT,
    @i_ESTADO        CHAR(1),
    @i_AUD_USER      VARCHAR(16),
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_ESTADO NOT IN ('V', 'I')
        BEGIN
            SET @o_resultMessage = '0|Estado no válido. Use V (vigente) o I (inactivo)';
            RETURN;
        END

        UPDATE dbo.TMKK_COMISION_REGLA
        SET FCRG_ESTADO = @i_ESTADO, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE CCRG_ID_REGLA = @i_CCRG_ID_REGLA;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Regla no encontrada';
            RETURN;
        END

        SET @o_resultMessage = '1|Estado actualizado';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ==============================================================================
-- 3. LIQUIDACIÓN
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Calcula (o recalcula) las comisiones del periodo. Solo reemplaza las
-- liquidaciones pendientes; las aprobadas o pagadas no se tocan y sus ventas
-- no vuelven a comisionar.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_PRC_BOF_CALCULAR_COMISION
    @i_PERIODO       INT,            -- AAAAMM
    @i_AUD_USER      VARCHAR(16),
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_PERIODO % 100 NOT BETWEEN 1 AND 12
        BEGIN
            SET @o_resultMessage = '0|Periodo no válido (AAAAMM)';
            RETURN;
        END

        DECLARE @ini DATE = DATEFROMPARTS(@i_PERIODO / 100, @i_PERIODO % 100, 1);
        DECLARE @fin DATE = DATEADD(MONTH, 1, @ini);

        BEGIN TRANSACTION;

        DELETE FROM dbo.TMKK_COMISION WHERE NCOM_PERIODO = @i_PERIODO AND FCOM_ESTADO = 'P';

        SELECT v.CVEN_ID_VENTA, v.CPEL_ID_ASESOR, v.NVEN_VALOR, r.CCRG_ID_REGLA,
               CAST(ISNULL(r.NCRG_MONTO_FIJO, 0) + ISNULL(v.NVEN_VALOR * r.NCRG_PORCENTAJE / 100, 0) AS DECIMAL(14, 2)) AS NMONTO
        INTO #det
        FROM dbo.TMKK_VENTA v
        OUTER APPLY (
            SELECT TOP (1) cr.CCRG_ID_REGLA, cr.NCRG_MONTO_FIJO, cr.NCRG_PORCENTAJE
            FROM dbo.TMKK_COMISION_REGLA cr
            WHERE cr.FCRG_ESTADO = 'V'
              AND cr.DCRG_VIGENCIA_INICIO <= CAST(v.DVEN_FEC_ACTIVACION AS DATE)
              AND (cr.DCRG_VIGENCIA_FIN IS NULL OR cr.DCRG_VIGENCIA_FIN >= CAST(v.DVEN_FEC_ACTIVACION AS DATE))
              AND (cr.SVEN_TIPO_VENTA IS NULL OR cr.SVEN_TIPO_VENTA = v.SVEN_TIPO_VENTA)
              AND (cr.CPLN_ID_CODIGO IS NULL OR cr.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO)
              AND (cr.CCAM_ID_CAMPANIA IS NULL OR cr.CCAM_ID_CAMPANIA = v.CCAM_ID_CAMPANIA)
            ORDER BY CASE WHEN cr.SVEN_TIPO_VENTA IS NULL THEN 0 ELSE 1 END
                   + CASE WHEN cr.CPLN_ID_CODIGO IS NULL THEN 0 ELSE 1 END
                   + CASE WHEN cr.CCAM_ID_CAMPANIA IS NULL THEN 0 ELSE 1 END DESC,
                     cr.DCRG_VIGENCIA_INICIO DESC, cr.CCRG_ID_REGLA DESC
        ) r
        WHERE v.FVEN_ESTADO = 'V'
          AND v.CVEN_ESTADO_VENTA = '1'
          AND v.CPEL_ID_ASESOR IS NOT NULL
          AND v.DVEN_FEC_ACTIVACION >= @ini AND v.DVEN_FEC_ACTIVACION < @fin
          AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_COMISION_DETALLE d
                          JOIN dbo.TMKK_COMISION c ON c.CCOM_ID_COMISION = d.CCOM_ID_COMISION AND c.FCOM_ESTADO IN ('A', 'G')
                          WHERE d.CVEN_ID_VENTA = v.CVEN_ID_VENTA)
          AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_COMISION c
                          WHERE c.NCOM_PERIODO = @i_PERIODO AND c.CPEL_ID_PERSONAL = v.CPEL_ID_ASESOR AND c.FCOM_ESTADO IN ('A', 'G'));

        INSERT INTO dbo.TMKK_COMISION (NCOM_PERIODO, CPEL_ID_PERSONAL, NCOM_CANT_VENTAS, NCOM_MONTO_VENTAS, NCOM_MONTO_COMISION, AUD_INS_FEC, AUD_INS_USER)
        SELECT @i_PERIODO, CPEL_ID_ASESOR, COUNT(*), ISNULL(SUM(NVEN_VALOR), 0), SUM(NMONTO), GETDATE(), @i_AUD_USER
        FROM #det
        GROUP BY CPEL_ID_ASESOR;

        DECLARE @n INT = @@ROWCOUNT;

        INSERT INTO dbo.TMKK_COMISION_DETALLE (CCOM_ID_COMISION, CVEN_ID_VENTA, CCRG_ID_REGLA, NCOD_VALOR_VENTA, NCOD_MONTO)
        SELECT c.CCOM_ID_COMISION, d.CVEN_ID_VENTA, d.CCRG_ID_REGLA, ISNULL(d.NVEN_VALOR, 0), d.NMONTO
        FROM #det d
        JOIN dbo.TMKK_COMISION c ON c.NCOM_PERIODO = @i_PERIODO AND c.CPEL_ID_PERSONAL = d.CPEL_ID_ASESOR AND c.FCOM_ESTADO = 'P';

        COMMIT TRANSACTION;

        SET @o_resultMessage = '1|Se calcularon ' + CAST(@n AS VARCHAR(10)) + ' liquidaciones'
            + CASE WHEN EXISTS (SELECT 1 FROM #det WHERE CCRG_ID_REGLA IS NULL)
                   THEN ' (hay ventas sin regla de comisión vigente; se registraron con monto 0)' ELSE '' END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_COMISION
    @i_PERIODO          INT,
    @i_CCAM_ID_CAMPANIA INT     = NULL,
    @i_CPEL_ID_PERSONAL INT     = NULL,
    @i_ESTADO           CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CCOM_ID_COMISION, c.NCOM_PERIODO, c.CPEL_ID_PERSONAL,
           COALESCE(p.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)), '')) AS SASESOR,
           cam.SCAM_NOMBRE AS SCAMPANIA,
           c.NCOM_CANT_VENTAS, c.NCOM_MONTO_VENTAS, c.NCOM_MONTO_COMISION,
           c.FCOM_ESTADO,
           CASE c.FCOM_ESTADO WHEN 'P' THEN 'PENDIENTE' WHEN 'A' THEN 'APROBADA' WHEN 'G' THEN 'PAGADA' ELSE 'ANULADA' END AS SESTADO,
           c.AUD_INS_FEC, c.AUD_UPD_FEC, c.AUD_UPD_USER
    FROM dbo.TMKK_COMISION c
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = c.CPEL_ID_PERSONAL
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA cam ON cam.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    WHERE c.NCOM_PERIODO = @i_PERIODO
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CPEL_ID_PERSONAL IS NULL OR c.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR c.FCOM_ESTADO = @i_ESTADO)
    ORDER BY c.NCOM_MONTO_COMISION DESC;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_COMISION_DETALLE
    @i_CCOM_ID_COMISION INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT d.CVEN_ID_VENTA, v.DVEN_FECHA_REGISTRO, v.DVEN_FEC_ACTIVACION, v.SVEN_CELULAR,
           tv.STPV_DES_TIP_VALOR_1 AS STIPO_VENTA, pl.SPLN_NOMBRE AS SPLAN,
           c.SPER_NOM_COMPLETO AS SCLIENTE, d.NCOD_VALOR_VENTA, d.NCOD_MONTO, r.SCRG_NOMBRE AS SREGLA
    FROM dbo.TMKK_COMISION_DETALLE d
    JOIN dbo.TMKK_VENTA v ON v.CVEN_ID_VENTA = d.CVEN_ID_VENTA
    LEFT JOIN dbo.TPLS_PERSONA c ON c.CPER_ID_PERSONA = v.CVEN_ID_CLIENTE
    LEFT JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO
    LEFT JOIN dbo.TMKK_COMISION_REGLA r ON r.CCRG_ID_REGLA = d.CCRG_ID_REGLA
    LEFT JOIN dbo.TMKK_TIP_VALOR tv ON tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.CTPV_TIP_VALOR = CAST(v.SVEN_TIPO_VENTA AS VARCHAR(8))
    WHERE d.CCOM_ID_COMISION = @i_CCOM_ID_COMISION
    ORDER BY v.DVEN_FEC_ACTIVACION;
END
GO

-- Flujo de estados: P -> A -> G; P o A -> X
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_COMISION_ESTADO
    @i_CCOM_ID_COMISION INT,
    @i_ESTADO           CHAR(1),
    @i_AUD_USER         VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @actual CHAR(1) = (SELECT FCOM_ESTADO FROM dbo.TMKK_COMISION WHERE CCOM_ID_COMISION = @i_CCOM_ID_COMISION);

        IF @actual IS NULL
        BEGIN
            SET @o_resultMessage = '0|Liquidación no encontrada';
            RETURN;
        END

        IF NOT ((@actual = 'P' AND @i_ESTADO IN ('A', 'X')) OR (@actual = 'A' AND @i_ESTADO IN ('G', 'X', 'P')))
        BEGIN
            SET @o_resultMessage = '0|Cambio de estado no permitido (' + @actual + ' -> ' + ISNULL(@i_ESTADO, '') + ')';
            RETURN;
        END

        UPDATE dbo.TMKK_COMISION
        SET FCOM_ESTADO = @i_ESTADO, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE CCOM_ID_COMISION = @i_CCOM_ID_COMISION;

        SET @o_resultMessage = '1|Estado actualizado';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO
