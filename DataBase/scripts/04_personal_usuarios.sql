-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 04: PERSONAL (HeadCount, Registro-Bajas) Y USUARIOS (Mantenimiento > Usuarios)
--   Tablas : columnas nuevas en TPLS_PERSONA y TMKK_PERSONAL; TMKK_PERSONAL_PERIODO
--            (historial laboral: ingresos, ceses y reingresos)
--   SPs    : listado/indicadores de HeadCount, registro de bajas, CRUD de usuarios
--
-- Estados de TMKK_PERSONAL.FPEl_ESTADO: V = activo, B = baja, I = inactivo
-- Estados de TMKK_USUARIO.FUSU_ESTADO : V = activo, I = inactivo
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

-- Datos de contacto que pide HeadCount > Datos personales
IF COL_LENGTH('dbo.TPLS_PERSONA', 'SPER_DIRECCION') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD SPER_DIRECCION VARCHAR(250) NULL;
IF COL_LENGTH('dbo.TPLS_PERSONA', 'CUBI_COD_UBIGEO') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD CUBI_COD_UBIGEO CHAR(6) NULL
        CONSTRAINT FK_TPLS_PERSONA_UBIGEO REFERENCES dbo.TMKK_UBIGEO (CUBI_COD_UBIGEO);
IF COL_LENGTH('dbo.TPLS_PERSONA', 'SPER_CONTACTO_EMERGENCIA') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD SPER_CONTACTO_EMERGENCIA VARCHAR(150) NULL;
IF COL_LENGTH('dbo.TPLS_PERSONA', 'SPER_TEL_EMERGENCIA') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD SPER_TEL_EMERGENCIA VARCHAR(16) NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TPLS_PERSONA_DOC')
    CREATE INDEX IX_TPLS_PERSONA_DOC ON dbo.TPLS_PERSONA (SPER_NRO_DOC_IDENTIDAD, FPER_TIP_DOC_IDENTIDAD);
GO

-- Datos laborales que piden HeadCount y Mantenimiento > Usuarios
--   CPEl_ID_HUELLERO = "ID Bio", CPEl_ID_VICIDIAL = "ID Vici" (ya existían)
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CCAM_ID_CAMPANIA') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CCAM_ID_CAMPANIA INT NULL
        CONSTRAINT FK_TMKK_PERSONAL_CAMPANIA REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA);
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CSED_ID_SEDE') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CSED_ID_SEDE INT NULL
        CONSTRAINT FK_TMKK_PERSONAL_SEDE REFERENCES dbo.TMKK_SEDE (CSED_ID_SEDE);
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CPEL_ID_SUPERVISOR') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CPEL_ID_SUPERVISOR INT NULL
        CONSTRAINT FK_TMKK_PERSONAL_SUPERVISOR REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL);
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CPEL_PUESTO') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CPEL_PUESTO VARCHAR(8) NULL;          -- TIP_VALOR 'PUESTO_TRABAJO'
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'FPEL_MODALIDAD') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD FPEL_MODALIDAD CHAR(1) NULL;          -- TIP_VALOR 'MODALIDAD_TRABAJO' (P/R)
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'HPEL_HORA_INICIO') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD HPEL_HORA_INICIO TIME(0) NULL;
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'HPEL_HORA_FIN') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD HPEL_HORA_FIN TIME(0) NULL;
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'SPEL_NUM_CUENTA') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD SPEL_NUM_CUENTA VARCHAR(30) NULL;
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CPEL_ID_VENTA') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CPEL_ID_VENTA VARCHAR(30) NULL;        -- "ID Venta"
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CPEL_ID_OVER') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CPEL_ID_OVER VARCHAR(16) NULL;         -- "ID Over"
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'SPEL_USUARIO_OCM') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD SPEL_USUARIO_OCM VARCHAR(50) NULL;     -- Registro-Bajas > Usuario OCM
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'DPEL_FEC_CESE') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD DPEL_FEC_CESE DATE NULL;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id = OBJECT_ID('dbo.TMKK_PERSONAL')
               AND parent_column_id = COLUMNPROPERTY(OBJECT_ID('dbo.TMKK_PERSONAL'), 'FPEl_ESTADO', 'ColumnId'))
    ALTER TABLE dbo.TMKK_PERSONAL ADD CONSTRAINT DF_TMKK_PERSONAL_ESTADO DEFAULT ('V') FOR FPEl_ESTADO;
GO

-- Un usuario pertenece a un solo registro de personal
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_PERSONAL_USUARIO')
   AND NOT EXISTS (SELECT CUSU_ID_USUARIO FROM dbo.TMKK_PERSONAL WHERE CUSU_ID_USUARIO IS NOT NULL
                   GROUP BY CUSU_ID_USUARIO HAVING COUNT(*) > 1)
    CREATE UNIQUE INDEX UX_TMKK_PERSONAL_USUARIO ON dbo.TMKK_PERSONAL (CUSU_ID_USUARIO) WHERE CUSU_ID_USUARIO IS NOT NULL;
GO

-- Historial laboral (HeadCount > Histórico). Un periodo abierto (DPPE_FEC_FIN NULL) por persona.
IF OBJECT_ID('dbo.TMKK_PERSONAL_PERIODO') IS NULL
CREATE TABLE dbo.TMKK_PERSONAL_PERIODO (
    CPPE_ID_PERIODO     INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_PERSONAL_PERIODO PRIMARY KEY,
    CPEL_ID_PERSONAL    INT NOT NULL,
    DPPE_FEC_INICIO     DATE NOT NULL,
    DPPE_FEC_FIN        DATE NULL,
    CCAM_ID_CAMPANIA    INT NULL,
    CPEL_PUESTO         VARCHAR(8) NULL,        -- TIP_VALOR 'PUESTO_TRABAJO'
    CPPE_TIPO_BAJA      VARCHAR(8) NULL,        -- TIP_VALOR 'TIPO_BAJA'
    SPPE_MOTIVO_BAJA    VARCHAR(500) NULL,
    SPPE_OBSERVACION    VARCHAR(500) NULL,
    FPPE_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_PPE_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_PPE_PERSONAL FOREIGN KEY (CPEL_ID_PERSONAL) REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL),
    CONSTRAINT FK_TMKK_PPE_CAMPANIA FOREIGN KEY (CCAM_ID_CAMPANIA) REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA),
    CONSTRAINT CK_TMKK_PPE_FECHAS CHECK (DPPE_FEC_FIN IS NULL OR DPPE_FEC_FIN >= DPPE_FEC_INICIO)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_PPE_ABIERTO')
    CREATE UNIQUE INDEX UX_TMKK_PPE_ABIERTO ON dbo.TMKK_PERSONAL_PERIODO (CPEL_ID_PERSONAL) WHERE DPPE_FEC_FIN IS NULL AND FPPE_ESTADO = 'V';
GO

-- Periodo inicial para el personal que ya existía
INSERT INTO dbo.TMKK_PERSONAL_PERIODO (CPEL_ID_PERSONAL, DPPE_FEC_INICIO, DPPE_FEC_FIN, CCAM_ID_CAMPANIA, CPEL_PUESTO, AUD_INS_FEC, AUD_INS_USER)
SELECT pe.CPEL_ID_PERSONAL,
       CAST(COALESCE(pe.FPEl_INGRESO, pe.FPEl_INICIO_CONTRATO, pe.AUD_INS_FEC, GETDATE()) AS DATE),
       CASE WHEN pe.FPEl_ESTADO = 'B' THEN pe.DPEL_FEC_CESE END,
       pe.CCAM_ID_CAMPANIA, pe.CPEL_PUESTO, GETDATE(), 'AIW_SISTEMAS'
FROM dbo.TMKK_PERSONAL pe
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO x WHERE x.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL);
GO

-- ==============================================================================
-- 2. HEADCOUNT
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Listado de HeadCount (tabla "Resumen" + diálogo "Datos personales").
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERSONAL
    @i_CPEL_ID_PERSONAL INT          = NULL,
    @i_ESTADO           CHAR(1)      = NULL,   -- V = activo, B = baja, NULL = todos
    @i_CSED_ID_SEDE     INT          = NULL,
    @i_CCAM_ID_CAMPANIA INT          = NULL,
    @i_TEXTO            VARCHAR(100) = NULL    -- DNI o nombre
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        pe.CPEL_ID_PERSONAL,
        pe.CUSU_ID_USUARIO,
        p.CPER_ID_PERSONA,
        p.SPER_NRO_DOC_IDENTIDAD                    AS SNRO_DOCUMENTO,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
        pe.SPEL_NUM_CUENTA,
        pe.FPEL_MODALIDAD,
        mo.STPV_DES_TIP_VALOR_1                     AS SMODALIDAD,
        pe.FPEl_ESTADO,
        CASE pe.FPEl_ESTADO WHEN 'V' THEN 'ACTIVO' WHEN 'B' THEN 'BAJA' ELSE 'INACTIVO' END AS SESTADO_ASESOR,
        pe.CCAM_ID_CAMPANIA,
        c.SCAM_NOMBRE                               AS SCAMPANIA,
        c.SCAM_COLOR,
        pe.CPEL_PUESTO,
        pu.STPV_DES_TIP_VALOR_1                     AS SPUESTO,
        pe.CSED_ID_SEDE,
        s.SSED_NOMBRE                               AS SSEDE,
        pe.CPEL_ID_SUPERVISOR,
        COALESCE(ps.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(ps.SPER_APE_PATERNO, ' ', ps.SPER_APE_MATERNO, ' ', ps.SPER_NOMBRE)), '')) AS SSUPERVISOR,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_INICIO, 108) AS SHORA_INICIO,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_FIN, 108)    AS SHORA_FIN,
        p.SPER_FEC_NACIMIENTO,
        COALESCE(p.SPER_COR_LABORAL, p.SPER_COR_PERSONAL) AS SCORREO,
        p.SPER_CELULAR,
        p.SPER_CONTACTO_EMERGENCIA,
        p.SPER_TEL_EMERGENCIA,
        p.SPER_DIRECCION,
        p.FPER_TIP_SEXO,
        sx.STPV_DES_TIP_VALOR_1                     AS SGENERO,
        p.FPER_TIP_EST_CIVIL,
        ec.STPV_DES_TIP_VALOR_1                     AS SESTADO_CIVIL,
        pe.FPEl_INGRESO,
        pe.DPEL_FEC_CESE,
        ub.CPPE_TIPO_BAJA,
        tb.STPV_DES_TIP_VALOR_1                     AS SMOTIVO_BAJA
    FROM dbo.TMKK_PERSONAL pe
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_SEDE s ON s.CSED_ID_SEDE = pe.CSED_ID_SEDE
    LEFT JOIN dbo.TMKK_PERSONAL sup ON sup.CPEL_ID_PERSONAL = pe.CPEL_ID_SUPERVISOR
    LEFT JOIN dbo.TPLS_PERSONA ps ON ps.CPER_ID_PERSONA = sup.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_TIP_VALOR mo ON mo.CTPV_COD_TIP_VALOR = 'MODALIDAD_TRABAJO' AND mo.CTPV_TIP_VALOR = pe.FPEL_MODALIDAD
    LEFT JOIN dbo.TMKK_TIP_VALOR pu ON pu.CTPV_COD_TIP_VALOR = 'PUESTO_TRABAJO' AND pu.CTPV_TIP_VALOR = pe.CPEL_PUESTO
    LEFT JOIN dbo.TMKK_TIP_VALOR sx ON sx.CTPV_COD_TIP_VALOR = 'TIP_SEXO' AND sx.CTPV_TIP_VALOR = p.FPER_TIP_SEXO
    LEFT JOIN dbo.TMKK_TIP_VALOR ec ON ec.CTPV_COD_TIP_VALOR = 'TIP_EST_CIVIL' AND ec.CTPV_TIP_VALOR = p.FPER_TIP_EST_CIVIL
    -- Motivo de la última baja (solo para quien está de baja actualmente)
    OUTER APPLY (SELECT TOP (1) pp.CPPE_TIPO_BAJA
                 FROM dbo.TMKK_PERSONAL_PERIODO pp
                 WHERE pp.CPEL_ID_PERSONAL = pe.CPEL_ID_PERSONAL AND pp.FPPE_ESTADO = 'V' AND pp.DPPE_FEC_FIN IS NOT NULL
                   AND pe.FPEl_ESTADO = 'B'
                 ORDER BY pp.DPPE_FEC_FIN DESC) ub
    LEFT JOIN dbo.TMKK_TIP_VALOR tb ON tb.CTPV_COD_TIP_VALOR = 'TIPO_BAJA' AND tb.CTPV_TIP_VALOR = ub.CPPE_TIPO_BAJA
    WHERE (@i_CPEL_ID_PERSONAL IS NULL OR pe.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR pe.FPEl_ESTADO = @i_ESTADO)
      AND (@i_CSED_ID_SEDE IS NULL OR pe.CSED_ID_SEDE = @i_CSED_ID_SEDE)
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (NULLIF(@i_TEXTO, '') IS NULL
           OR p.SPER_NRO_DOC_IDENTIDAD LIKE @i_TEXTO + '%'
           OR COALESCE(p.SPER_NOM_COMPLETO, CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)) LIKE '%' + @i_TEXTO + '%')
    ORDER BY SNOMBRE_COMPLETO;
END
GO

-- Historial laboral de una persona (diálogo "Histórico")
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERSONAL_PERIODO
    @i_CPEL_ID_PERSONAL INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pp.CPPE_ID_PERIODO,
           COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
           pp.DPPE_FEC_INICIO, pp.DPPE_FEC_FIN,
           c.SCAM_NOMBRE AS SCAMPANIA, pu.STPV_DES_TIP_VALOR_1 AS SPUESTO,
           pp.CPPE_TIPO_BAJA, tb.STPV_DES_TIP_VALOR_1 AS STIPO_BAJA,
           pp.SPPE_MOTIVO_BAJA,
           COALESCE(pp.SPPE_OBSERVACION, pp.SPPE_MOTIVO_BAJA) AS SOBSERVACION
    FROM dbo.TMKK_PERSONAL_PERIODO pp
    JOIN dbo.TMKK_PERSONAL pe ON pe.CPEL_ID_PERSONAL = pp.CPEL_ID_PERSONAL
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pp.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_TIP_VALOR pu ON pu.CTPV_COD_TIP_VALOR = 'PUESTO_TRABAJO' AND pu.CTPV_TIP_VALOR = pp.CPEL_PUESTO
    LEFT JOIN dbo.TMKK_TIP_VALOR tb ON tb.CTPV_COD_TIP_VALOR = 'TIPO_BAJA' AND tb.CTPV_TIP_VALOR = pp.CPPE_TIPO_BAJA
    WHERE pp.CPEL_ID_PERSONAL = @i_CPEL_ID_PERSONAL AND pp.FPPE_ESTADO = 'V'
    ORDER BY pp.DPPE_FEC_INICIO;
END
GO

-- Tarjetas de indicadores de HeadCount (bajas del periodo y por tipo)
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERSONAL_INDICADORES
    @i_FEC_INICIO DATE = NULL,   -- por defecto, mes actual
    @i_FEC_FIN    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @i_FEC_INICIO = ISNULL(@i_FEC_INICIO, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1));
    SET @i_FEC_FIN    = ISNULL(@i_FEC_FIN, EOMONTH(@i_FEC_INICIO));

    SELECT
        (SELECT COUNT(*) FROM dbo.TMKK_PERSONAL WHERE FPEl_ESTADO = 'V')        AS NACTIVOS,
        COUNT(*)                                                                 AS NBAJAS,
        SUM(CASE WHEN pp.CPPE_TIPO_BAJA = '1' THEN 1 ELSE 0 END)                 AS NRENUNCIAS,
        SUM(CASE WHEN pp.CPPE_TIPO_BAJA = '2' THEN 1 ELSE 0 END)                 AS NABANDONOS,
        SUM(CASE WHEN pp.CPPE_TIPO_BAJA = '3' THEN 1 ELSE 0 END)                 AS NFIN_CONTRATO,
        SUM(CASE WHEN pp.CPPE_TIPO_BAJA = '4' THEN 1 ELSE 0 END)                 AS NRETIROS_DESEMPENIO
    FROM dbo.TMKK_PERSONAL_PERIODO pp
    WHERE pp.FPPE_ESTADO = 'V'
      AND pp.CPPE_TIPO_BAJA IS NOT NULL
      AND pp.DPPE_FEC_FIN BETWEEN @i_FEC_INICIO AND @i_FEC_FIN;
END
GO

-- Autocompletado del formulario Registro-Bajas a partir del DNI
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERSONAL_POR_DOCUMENTO
    @i_NRO_DOC VARCHAR(16)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        pe.CPEL_ID_PERSONAL,
        p.SPER_NRO_DOC_IDENTIDAD AS SNRO_DOCUMENTO,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
        pe.SPEL_USUARIO_OCM,
        pe.FPEl_ESTADO,
        c.SCAM_NOMBRE AS SCAMPANIA
    FROM dbo.TMKK_PERSONAL pe
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    WHERE p.SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC
    ORDER BY CASE pe.FPEl_ESTADO WHEN 'V' THEN 0 ELSE 1 END, pe.CPEL_ID_PERSONAL DESC;
END
GO

-- ------------------------------------------------------------------------------
-- Registro-Bajas: cierra el periodo abierto, marca al personal como BAJA,
-- inactiva su usuario y cierra sus sesiones.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_PERSONAL_BAJA
    @i_NRO_DOC       VARCHAR(16),
    @i_FEC_BAJA      DATE,
    @i_TIPO_BAJA     VARCHAR(8),             -- TIP_VALOR 'TIPO_BAJA'
    @i_MOTIVO_BAJA   VARCHAR(500),
    @i_USUARIO_OCM   VARCHAR(50) = NULL,
    @i_AUD_INS_USER  VARCHAR(16),
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @personal INT, @usuario INT, @ingreso DATE;

        SELECT TOP (1) @personal = pe.CPEL_ID_PERSONAL, @usuario = pe.CUSU_ID_USUARIO,
                       @ingreso = CAST(COALESCE(pe.FPEl_INGRESO, pe.AUD_INS_FEC) AS DATE)
        FROM dbo.TMKK_PERSONAL pe
        JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
        WHERE p.SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC AND pe.FPEl_ESTADO <> 'B'
        ORDER BY pe.CPEL_ID_PERSONAL DESC;

        IF @personal IS NULL
        BEGIN
            SET @o_resultMessage = '0|No existe personal activo con el documento ' + @i_NRO_DOC;
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR WHERE CTPV_COD_TIP_VALOR = 'TIPO_BAJA' AND CTPV_TIP_VALOR = @i_TIPO_BAJA AND FTPV_ESTADO = 'V')
        BEGIN
            SET @o_resultMessage = '0|Tipo de baja no válido';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_PERSONAL_PERIODO
        SET DPPE_FEC_FIN = @i_FEC_BAJA, CPPE_TIPO_BAJA = @i_TIPO_BAJA, SPPE_MOTIVO_BAJA = @i_MOTIVO_BAJA,
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
        WHERE CPEL_ID_PERSONAL = @personal AND DPPE_FEC_FIN IS NULL AND FPPE_ESTADO = 'V';

        IF @@ROWCOUNT = 0
            INSERT INTO dbo.TMKK_PERSONAL_PERIODO
                (CPEL_ID_PERSONAL, DPPE_FEC_INICIO, DPPE_FEC_FIN, CCAM_ID_CAMPANIA, CPEL_PUESTO, CPPE_TIPO_BAJA, SPPE_MOTIVO_BAJA, AUD_INS_FEC, AUD_INS_USER)
            SELECT CPEL_ID_PERSONAL, CASE WHEN @ingreso > @i_FEC_BAJA THEN @i_FEC_BAJA ELSE ISNULL(@ingreso, @i_FEC_BAJA) END,
                   @i_FEC_BAJA, CCAM_ID_CAMPANIA, CPEL_PUESTO, @i_TIPO_BAJA, @i_MOTIVO_BAJA, GETDATE(), @i_AUD_INS_USER
            FROM dbo.TMKK_PERSONAL WHERE CPEL_ID_PERSONAL = @personal;

        UPDATE dbo.TMKK_PERSONAL
        SET FPEl_ESTADO = 'B', DPEL_FEC_CESE = @i_FEC_BAJA,
            SPEL_USUARIO_OCM = COALESCE(NULLIF(@i_USUARIO_OCM, ''), SPEL_USUARIO_OCM),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
        WHERE CPEL_ID_PERSONAL = @personal;

        IF @usuario IS NOT NULL
        BEGIN
            UPDATE dbo.TMKK_USUARIO
            SET FUSU_ESTADO = 'I', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
            WHERE CUSU_ID_USUARIO = @usuario;

            UPDATE dbo.TMKK_USUARIO_SESION
            SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
            WHERE CUSU_ID_USUARIO = @usuario AND FUSN_ESTADO = 'V';
        END

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Baja registrada correctamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Supervisores activos (filtros de Asistencia y Llamadas)
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_SUPERVISOR
    @i_CCAM_ID_CAMPANIA INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pe.CPEL_ID_PERSONAL,
           COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
           pe.CCAM_ID_CAMPANIA
    FROM dbo.TMKK_PERSONAL pe
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = pe.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_PERFIL pf ON pf.CPFL_ID_PERFIL = pe.CPFL_ID_PERFIL
    WHERE pe.FPEl_ESTADO = 'V'
      AND (pf.SPFL_NOMBRE = 'SUPERVISOR' OR pe.CPEL_PUESTO = '8'
           OR EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL a WHERE a.CPEL_ID_SUPERVISOR = pe.CPEL_ID_PERSONAL AND a.FPEl_ESTADO = 'V'))
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
    ORDER BY SNOMBRE_COMPLETO;
END
GO

-- ==============================================================================
-- 3. MANTENIMIENTO > USUARIOS
--    Un "usuario" del front = TPLS_PERSONA + TMKK_USUARIO + TMKK_USUARIO_PERFIL + TMKK_PERSONAL
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_USUARIO
    @i_CUSU_ID_USUARIO  INT          = NULL,
    @i_CPFL_ID_PERFIL   INT          = NULL,
    @i_CCAM_ID_CAMPANIA INT          = NULL,   -- -1 = sin campaña
    @i_SOLO_VENCIDOS    CHAR(1)      = 'N',    -- S = solo contratos vencidos
    @i_ESTADO           CHAR(1)      = NULL,   -- V / I
    @i_TEXTO            VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    SELECT
        u.CUSU_ID_USUARIO,
        pe.CPEL_ID_PERSONAL,
        p.CPER_ID_PERSONA,
        p.FPER_TIP_DOC_IDENTIDAD,
        p.SPER_NRO_DOC_IDENTIDAD                    AS SNRO_DOCUMENTO,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
        COALESCE(p.SPER_COR_LABORAL, p.SPER_COR_PERSONAL) AS SCORREO,
        u.SUSU_USERNAME,
        pf.CPFL_ID_PERFIL,
        pf.SPFL_NOMBRE                              AS SPERFIL,
        pe.CCAM_ID_CAMPANIA,
        c.SCAM_NOMBRE                               AS SCAMPANIA,
        pe.CSED_ID_SEDE,
        pe.CPEL_PUESTO,
        pe.FPEL_MODALIDAD,
        pe.CPEL_ID_SUPERVISOR,
        pe.CPEl_ID_HUELLERO                         AS SID_BIO,
        pe.CPEL_ID_VENTA                            AS SID_VENTA,
        pe.CPEL_ID_OVER                             AS SID_OVER,
        pe.CPEl_ID_VICIDIAL                         AS SID_VICI,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_INICIO, 108) AS SHORA_INICIO,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_FIN, 108)    AS SHORA_FIN,
        CAST(pe.FPEl_INGRESO AS DATE)               AS DFEC_INGRESO,
        pe.DPEL_FEC_CESE                            AS DFEC_FIN,
        CAST(pe.FPEl_INICIO_CONTRATO AS DATE)       AS DCONTRATO_INICIO,
        CAST(pe.FPEl_FIN_CONTRATO AS DATE)          AS DCONTRATO_FIN,
        CASE WHEN pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy THEN 'S' ELSE 'N' END AS FCONTRATO_VENCIDO,
        u.FUSU_ESTADO,
        CASE u.FUSU_ESTADO WHEN 'V' THEN 'Activo' ELSE 'Inactivo' END AS SESTADO,
        u.DUSU_ULTIMO_LOGIN
    FROM dbo.TMKK_USUARIO u
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = u.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO
    OUTER APPLY (SELECT TOP (1) up.CPFL_ID_PERFIL FROM dbo.TMKK_USUARIO_PERFIL up
                 WHERE up.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO AND up.FUSR_ESTADO = 'V'
                 ORDER BY up.DUSR_FECHA_ASIGNACION DESC) upa
    LEFT JOIN dbo.TMKK_PERFIL pf ON pf.CPFL_ID_PERFIL = COALESCE(upa.CPFL_ID_PERFIL, pe.CPFL_ID_PERFIL)
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    WHERE (@i_CUSU_ID_USUARIO IS NULL OR u.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO)
      AND (@i_CPFL_ID_PERFIL IS NULL OR pf.CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL)
      AND (@i_CCAM_ID_CAMPANIA IS NULL
           OR (@i_CCAM_ID_CAMPANIA = -1 AND pe.CCAM_ID_CAMPANIA IS NULL)
           OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (ISNULL(@i_SOLO_VENCIDOS, 'N') <> 'S'
           OR (pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy))
      AND (NULLIF(@i_ESTADO, '') IS NULL OR u.FUSU_ESTADO = @i_ESTADO)
      AND (NULLIF(@i_TEXTO, '') IS NULL
           OR u.SUSU_USERNAME LIKE '%' + @i_TEXTO + '%'
           OR pf.SPFL_NOMBRE LIKE '%' + @i_TEXTO + '%'
           OR COALESCE(p.SPER_NOM_COMPLETO, CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)) LIKE '%' + @i_TEXTO + '%')
    ORDER BY u.CUSU_ID_USUARIO;
END
GO

-- Tarjetas de Mantenimiento > Usuarios. Result set 1: totales; 2: activos por campaña.
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_USUARIO_RESUMEN
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    SELECT
        SUM(CASE WHEN u.FUSU_ESTADO = 'V' THEN 1 ELSE 0 END) AS NACTIVOS,
        SUM(CASE WHEN pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy THEN 1 ELSE 0 END) AS NCONTRATOS_VENCIDOS
    FROM dbo.TMKK_USUARIO u
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO;

    SELECT c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE, COUNT(u.CUSU_ID_USUARIO) AS NUSUARIOS
    FROM dbo.TMKK_CAMPANIA c
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CCAM_ID_CAMPANIA = c.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = pe.CUSU_ID_USUARIO AND u.FUSU_ESTADO = 'V'
    WHERE c.FCAM_ESTADO = 'V'
    GROUP BY c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE
    ORDER BY c.SCAM_NOMBRE;
END
GO

-- ------------------------------------------------------------------------------
-- Alta de usuario (drawer "Nuevo Usuario"). Crea o reutiliza la persona (por
-- tipo y número de documento), el usuario, su perfil, el personal y el primer
-- periodo laboral. La contraseña inicial la genera la API (hash) y queda
-- marcada para cambio obligatorio.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_USUARIO
    @i_NOMBRE_COMPLETO  VARCHAR(200),
    @i_TIP_DOC          TINYINT      = 1,       -- TMKK_TIP_DOC_IDENTIDAD (1 = DNI)
    @i_NRO_DOC          VARCHAR(16)  = NULL,
    @i_CORREO           VARCHAR(100) = NULL,
    @i_CELULAR          VARCHAR(16)  = NULL,
    @i_USERNAME         VARCHAR(50),
    @i_PASSWORD_HASH    VARCHAR(255),
    @i_CPFL_ID_PERFIL   INT,
    @i_CCAM_ID_CAMPANIA INT          = NULL,
    @i_CSED_ID_SEDE     INT          = NULL,
    @i_CPEL_PUESTO      VARCHAR(8)   = NULL,
    @i_FPEL_MODALIDAD   CHAR(1)      = NULL,
    @i_CPEL_ID_SUPERVISOR INT        = NULL,
    @i_ID_BIO           VARCHAR(16)  = NULL,
    @i_ID_VENTA         VARCHAR(30)  = NULL,
    @i_ID_OVER          VARCHAR(16)  = NULL,
    @i_ID_VICI          VARCHAR(16)  = NULL,
    @i_HORA_INICIO      TIME(0)      = NULL,
    @i_HORA_FIN         TIME(0)      = NULL,
    @i_FEC_INGRESO      DATE         = NULL,
    @i_CONTRATO_INICIO  DATE         = NULL,
    @i_CONTRATO_FIN     DATE         = NULL,
    @i_NUM_CUENTA       VARCHAR(30)  = NULL,
    @i_ESTADO           CHAR(1)      = 'V',
    @i_AUD_INS_USER     VARCHAR(16),
    @o_CUSU_ID_USUARIO  INT OUTPUT,
    @o_CPEL_ID_PERSONAL INT OUTPUT,
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @persona INT, @ingreso DATE = ISNULL(@i_FEC_INGRESO, CAST(GETDATE() AS DATE));

        IF EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO WHERE SUSU_USERNAME = @i_USERNAME)
        BEGIN
            SET @o_resultMessage = '0|El nombre de usuario ya está en uso';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERFIL WHERE CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL AND FPFL_ESTADO = 'V')
        BEGIN
            SET @o_resultMessage = '0|Perfil no válido';
            RETURN;
        END

        IF @i_CONTRATO_INICIO IS NOT NULL AND @i_CONTRATO_FIN IS NOT NULL AND @i_CONTRATO_FIN < @i_CONTRATO_INICIO
        BEGIN
            SET @o_resultMessage = '0|La fecha fin de contrato no puede ser menor a la de inicio';
            RETURN;
        END

        IF NULLIF(@i_NRO_DOC, '') IS NOT NULL
            SELECT TOP (1) @persona = CPER_ID_PERSONA FROM dbo.TPLS_PERSONA
            WHERE SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC AND FPER_TIP_DOC_IDENTIDAD = @i_TIP_DOC;

        IF @persona IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO WHERE CPER_ID_PERSONA = @persona)
        BEGIN
            SET @o_resultMessage = '0|La persona con documento ' + @i_NRO_DOC + ' ya tiene un usuario';
            RETURN;
        END

        BEGIN TRANSACTION;

        IF @persona IS NULL
        BEGIN
            INSERT INTO dbo.TPLS_PERSONA (FPER_TIP_PERSONA, FPER_TIP_DOC_IDENTIDAD, SPER_NRO_DOC_IDENTIDAD, SPER_NOM_COMPLETO,
                                          SPER_COR_LABORAL, SPER_CELULAR, FPER_ESTADO, AUD_INS_FEC, AUD_INS_USER)
            VALUES ('1', CASE WHEN NULLIF(@i_NRO_DOC, '') IS NULL THEN NULL ELSE @i_TIP_DOC END, NULLIF(@i_NRO_DOC, ''),
                    @i_NOMBRE_COMPLETO, NULLIF(@i_CORREO, ''), NULLIF(@i_CELULAR, ''), 'V', GETDATE(), @i_AUD_INS_USER);
            SET @persona = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE dbo.TPLS_PERSONA
            SET SPER_NOM_COMPLETO = @i_NOMBRE_COMPLETO,
                SPER_COR_LABORAL  = COALESCE(NULLIF(@i_CORREO, ''), SPER_COR_LABORAL),
                SPER_CELULAR      = COALESCE(NULLIF(@i_CELULAR, ''), SPER_CELULAR),
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_INS_USER
            WHERE CPER_ID_PERSONA = @persona;

        INSERT INTO dbo.TMKK_USUARIO (CPER_ID_PERSONA, SUSU_USERNAME, SUSU_PASSWORD_HASH, FUSU_ESTADO, FUSU_CAMBIAR_PASSWORD, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@persona, @i_USERNAME, @i_PASSWORD_HASH, ISNULL(@i_ESTADO, 'V'), 'S', GETDATE(), @i_AUD_INS_USER);
        SET @o_CUSU_ID_USUARIO = SCOPE_IDENTITY();

        INSERT INTO dbo.TMKK_USUARIO_PERFIL (CUSU_ID_USUARIO, CPFL_ID_PERFIL, DUSR_FECHA_ASIGNACION, FUSR_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@o_CUSU_ID_USUARIO, @i_CPFL_ID_PERFIL, GETDATE(), 'V', GETDATE(), @i_AUD_INS_USER);

        INSERT INTO dbo.TMKK_PERSONAL (CPER_ID_PERSONA, CUSU_ID_USUARIO, CPFL_ID_PERFIL, CCAM_ID_CAMPANIA, CSED_ID_SEDE, CPEL_PUESTO,
                                       FPEL_MODALIDAD, CPEL_ID_SUPERVISOR, CPEl_ID_HUELLERO, CPEL_ID_VENTA, CPEL_ID_OVER, CPEl_ID_VICIDIAL,
                                       HPEL_HORA_INICIO, HPEL_HORA_FIN, FPEl_INGRESO, FPEl_INICIO_CONTRATO, FPEl_FIN_CONTRATO,
                                       SPEL_NUM_CUENTA, FPEl_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@persona, @o_CUSU_ID_USUARIO, @i_CPFL_ID_PERFIL, @i_CCAM_ID_CAMPANIA, @i_CSED_ID_SEDE, NULLIF(@i_CPEL_PUESTO, ''),
                NULLIF(@i_FPEL_MODALIDAD, ''), @i_CPEL_ID_SUPERVISOR, NULLIF(@i_ID_BIO, ''), NULLIF(@i_ID_VENTA, ''), NULLIF(@i_ID_OVER, ''), NULLIF(@i_ID_VICI, ''),
                @i_HORA_INICIO, @i_HORA_FIN, @ingreso, @i_CONTRATO_INICIO, @i_CONTRATO_FIN,
                NULLIF(@i_NUM_CUENTA, ''), 'V', GETDATE(), @i_AUD_INS_USER);
        SET @o_CPEL_ID_PERSONAL = SCOPE_IDENTITY();

        INSERT INTO dbo.TMKK_PERSONAL_PERIODO (CPEL_ID_PERSONAL, DPPE_FEC_INICIO, CCAM_ID_CAMPANIA, CPEL_PUESTO, SPPE_OBSERVACION, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@o_CPEL_ID_PERSONAL, @ingreso, @i_CCAM_ID_CAMPANIA, NULLIF(@i_CPEL_PUESTO, ''), 'Ingreso', GETDATE(), @i_AUD_INS_USER);

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Usuario registrado correctamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Edición de usuario (drawer "Editar Usuario"). Si el personal estaba de baja y
-- se reactiva, se abre un nuevo periodo laboral (reingreso).
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_USUARIO
    @i_CUSU_ID_USUARIO  INT,
    @i_NOMBRE_COMPLETO  VARCHAR(200),
    @i_TIP_DOC          TINYINT      = 1,
    @i_NRO_DOC          VARCHAR(16)  = NULL,
    @i_CORREO           VARCHAR(100) = NULL,
    @i_CELULAR          VARCHAR(16)  = NULL,
    @i_USERNAME         VARCHAR(50),
    @i_CPFL_ID_PERFIL   INT,
    @i_CCAM_ID_CAMPANIA INT          = NULL,
    @i_CSED_ID_SEDE     INT          = NULL,
    @i_CPEL_PUESTO      VARCHAR(8)   = NULL,
    @i_FPEL_MODALIDAD   CHAR(1)      = NULL,
    @i_CPEL_ID_SUPERVISOR INT        = NULL,
    @i_ID_BIO           VARCHAR(16)  = NULL,
    @i_ID_VENTA         VARCHAR(30)  = NULL,
    @i_ID_OVER          VARCHAR(16)  = NULL,
    @i_ID_VICI          VARCHAR(16)  = NULL,
    @i_HORA_INICIO      TIME(0)      = NULL,
    @i_HORA_FIN         TIME(0)      = NULL,
    @i_FEC_INGRESO      DATE         = NULL,
    @i_CONTRATO_INICIO  DATE         = NULL,
    @i_CONTRATO_FIN     DATE         = NULL,
    @i_NUM_CUENTA       VARCHAR(30)  = NULL,
    @i_ESTADO           CHAR(1)      = 'V',
    @i_AUD_UPD_USER     VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @persona INT, @personal INT, @estadoPersonal CHAR(1);

        SELECT @persona = u.CPER_ID_PERSONA, @personal = pe.CPEL_ID_PERSONAL, @estadoPersonal = pe.FPEl_ESTADO
        FROM dbo.TMKK_USUARIO u
        LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO
        WHERE u.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @persona IS NULL
        BEGIN
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        IF EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO WHERE SUSU_USERNAME = @i_USERNAME AND CUSU_ID_USUARIO <> @i_CUSU_ID_USUARIO)
        BEGIN
            SET @o_resultMessage = '0|El nombre de usuario ya está en uso';
            RETURN;
        END

        IF NULLIF(@i_NRO_DOC, '') IS NOT NULL AND EXISTS (
            SELECT 1 FROM dbo.TPLS_PERSONA p JOIN dbo.TMKK_USUARIO u ON u.CPER_ID_PERSONA = p.CPER_ID_PERSONA
            WHERE p.SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC AND p.FPER_TIP_DOC_IDENTIDAD = @i_TIP_DOC AND p.CPER_ID_PERSONA <> @persona)
        BEGIN
            SET @o_resultMessage = '0|Otro usuario ya tiene el documento ' + @i_NRO_DOC;
            RETURN;
        END

        IF @i_CONTRATO_INICIO IS NOT NULL AND @i_CONTRATO_FIN IS NOT NULL AND @i_CONTRATO_FIN < @i_CONTRATO_INICIO
        BEGIN
            SET @o_resultMessage = '0|La fecha fin de contrato no puede ser menor a la de inicio';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.TPLS_PERSONA
        SET SPER_NOM_COMPLETO      = @i_NOMBRE_COMPLETO,
            FPER_TIP_DOC_IDENTIDAD = CASE WHEN NULLIF(@i_NRO_DOC, '') IS NULL THEN FPER_TIP_DOC_IDENTIDAD ELSE @i_TIP_DOC END,
            SPER_NRO_DOC_IDENTIDAD = COALESCE(NULLIF(@i_NRO_DOC, ''), SPER_NRO_DOC_IDENTIDAD),
            SPER_COR_LABORAL       = COALESCE(NULLIF(@i_CORREO, ''), SPER_COR_LABORAL),
            SPER_CELULAR           = COALESCE(NULLIF(@i_CELULAR, ''), SPER_CELULAR),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CPER_ID_PERSONA = @persona;

        UPDATE dbo.TMKK_USUARIO
        SET SUSU_USERNAME = @i_USERNAME, FUSU_ESTADO = ISNULL(@i_ESTADO, FUSU_ESTADO),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        -- Perfil: se inactivan los anteriores y se activa/crea el nuevo
        UPDATE dbo.TMKK_USUARIO_PERFIL
        SET FUSR_ESTADO = CASE WHEN CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL THEN 'V' ELSE 'I' END,
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO_PERFIL WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL)
            INSERT INTO dbo.TMKK_USUARIO_PERFIL (CUSU_ID_USUARIO, CPFL_ID_PERFIL, DUSR_FECHA_ASIGNACION, FUSR_ESTADO, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@i_CUSU_ID_USUARIO, @i_CPFL_ID_PERFIL, GETDATE(), 'V', GETDATE(), @i_AUD_UPD_USER);

        IF @personal IS NULL
        BEGIN
            INSERT INTO dbo.TMKK_PERSONAL (CPER_ID_PERSONA, CUSU_ID_USUARIO, CPFL_ID_PERFIL, FPEl_ESTADO, FPEl_INGRESO, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@persona, @i_CUSU_ID_USUARIO, @i_CPFL_ID_PERFIL, 'V', ISNULL(@i_FEC_INGRESO, CAST(GETDATE() AS DATE)), GETDATE(), @i_AUD_UPD_USER);
            SET @personal = SCOPE_IDENTITY();
            SET @estadoPersonal = 'B';  -- fuerza la apertura del primer periodo
        END

        UPDATE dbo.TMKK_PERSONAL
        SET CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL, CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA, CSED_ID_SEDE = @i_CSED_ID_SEDE,
            CPEL_PUESTO = NULLIF(@i_CPEL_PUESTO, ''), FPEL_MODALIDAD = NULLIF(@i_FPEL_MODALIDAD, ''),
            CPEL_ID_SUPERVISOR = @i_CPEL_ID_SUPERVISOR,
            CPEl_ID_HUELLERO = NULLIF(@i_ID_BIO, ''), CPEL_ID_VENTA = NULLIF(@i_ID_VENTA, ''),
            CPEL_ID_OVER = NULLIF(@i_ID_OVER, ''), CPEl_ID_VICIDIAL = NULLIF(@i_ID_VICI, ''),
            HPEL_HORA_INICIO = @i_HORA_INICIO, HPEL_HORA_FIN = @i_HORA_FIN,
            FPEl_INGRESO = COALESCE(@i_FEC_INGRESO, FPEl_INGRESO),
            FPEl_INICIO_CONTRATO = @i_CONTRATO_INICIO, FPEl_FIN_CONTRATO = @i_CONTRATO_FIN,
            SPEL_NUM_CUENTA = NULLIF(@i_NUM_CUENTA, ''),
            FPEl_ESTADO = CASE WHEN @i_ESTADO = 'V' THEN 'V' ELSE FPEl_ESTADO END,
            DPEL_FEC_CESE = CASE WHEN @i_ESTADO = 'V' THEN NULL ELSE DPEL_FEC_CESE END,
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CPEL_ID_PERSONAL = @personal;

        -- Reingreso: estaba de baja y se reactiva
        IF @i_ESTADO = 'V' AND ISNULL(@estadoPersonal, 'B') <> 'V'
           AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO WHERE CPEL_ID_PERSONAL = @personal AND DPPE_FEC_FIN IS NULL AND FPPE_ESTADO = 'V')
            INSERT INTO dbo.TMKK_PERSONAL_PERIODO (CPEL_ID_PERSONAL, DPPE_FEC_INICIO, CCAM_ID_CAMPANIA, CPEL_PUESTO, SPPE_OBSERVACION, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@personal, ISNULL(@i_FEC_INGRESO, CAST(GETDATE() AS DATE)), @i_CCAM_ID_CAMPANIA, NULLIF(@i_CPEL_PUESTO, ''),
                    CASE WHEN @estadoPersonal = 'B' AND EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL_PERIODO WHERE CPEL_ID_PERSONAL = @personal)
                         THEN 'Reingreso' ELSE 'Ingreso' END,
                    GETDATE(), @i_AUD_UPD_USER);
        ELSE
            -- Mantiene campaña/puesto del periodo abierto al día
            UPDATE dbo.TMKK_PERSONAL_PERIODO
            SET CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA, CPEL_PUESTO = NULLIF(@i_CPEL_PUESTO, ''),
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
            WHERE CPEL_ID_PERSONAL = @personal AND DPPE_FEC_FIN IS NULL AND FPPE_ESTADO = 'V';

        IF @i_ESTADO = 'I'
            UPDATE dbo.TMKK_USUARIO_SESION
            SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
            WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUSN_ESTADO = 'V';

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Usuario actualizado correctamente';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_EST_USUARIO
    @i_CUSU_ID_USUARIO INT,
    @i_ESTADO          CHAR(1),     -- V / I
    @i_AUD_UPD_USER    VARCHAR(16),
    @o_resultMessage   VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_ESTADO NOT IN ('V', 'I')
        BEGIN
            SET @o_resultMessage = '0|Estado no válido. Use V (activo) o I (inactivo)';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_USUARIO
        SET FUSU_ESTADO = @i_ESTADO, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        IF @i_ESTADO = 'I'
            UPDATE dbo.TMKK_USUARIO_SESION
            SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
            WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUSN_ESTADO = 'V';

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Estado actualizado';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO
