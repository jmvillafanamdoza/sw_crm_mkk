-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- MANTENIMIENTO > USUARIOS + SEDE (script único, autocontenido)
--
-- Se ejecuta directo sobre el esquema de producción (db_ac5777_mkkprod1), sin
-- depender de otros scripts. Es idempotente: puede ejecutarse varias veces.
--
--   Tablas  : TMKK_SEDE, TMKK_CAMPANIA (nuevas)
--   Columnas: TPLS_PERSONA.SPER_NOM_COMPLETO; TMKK_USUARIO.FUSU_CAMBIAR_PASSWORD;
--             datos laborales en TMKK_PERSONAL (sede, campaña, supervisor, puesto,
--             modalidad, horario, IDs y n° de cuenta)
--   Datos   : sedes (LOS OLIVOS, SAN JUAN DE LURIGANCHO, SURCO), campañas,
--             sistema y perfiles, grupos PUESTO_TRABAJO y MODALIDAD_TRABAJO
--   SPs     : CRUD de usuarios, resumen, restablecer contraseña y combos
--
-- Estados: V = activo/vigente, I = inactivo.
-- Un "usuario" del front = TPLS_PERSONA + TMKK_USUARIO + TMKK_USUARIO_PERFIL + TMKK_PERSONAL.
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS Y COLUMNAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_SEDE') IS NULL
CREATE TABLE dbo.TMKK_SEDE (
    CSED_ID_SEDE        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_SEDE PRIMARY KEY,
    SSED_NOMBRE         VARCHAR(100) NOT NULL CONSTRAINT UQ_TMKK_SEDE_NOMBRE UNIQUE,
    SSED_DIRECCION      VARCHAR(250) NULL,
    CUBI_COD_UBIGEO     CHAR(6) NULL,
    FSED_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_SEDE_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL
);
GO

IF OBJECT_ID('dbo.TMKK_CAMPANIA') IS NULL
CREATE TABLE dbo.TMKK_CAMPANIA (
    CCAM_ID_CAMPANIA    INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_CAMPANIA PRIMARY KEY,
    SCAM_NOMBRE         VARCHAR(100) NOT NULL CONSTRAINT UQ_TMKK_CAMPANIA_NOMBRE UNIQUE,
    SCAM_DESCRIPCION    VARCHAR(255) NULL,
    COPE_ID_OPERADOR    SMALLINT NULL,
    SCAM_COLOR          VARCHAR(20) NULL,
    FCAM_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_CAMPANIA_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_CAMPANIA_OPERADOR FOREIGN KEY (COPE_ID_OPERADOR) REFERENCES dbo.TMKK_OPERADOR (COPE_ID_OPERADOR)
);
GO

-- Nombre completo tal como lo captura el formulario ("Nombres y Apellidos")
IF COL_LENGTH('dbo.TPLS_PERSONA', 'SPER_NOM_COMPLETO') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD SPER_NOM_COMPLETO VARCHAR(200) NULL;
GO

-- 'S' obliga a cambiar la contraseña en el siguiente login (usuario nuevo o contraseña restablecida)
IF COL_LENGTH('dbo.TMKK_USUARIO', 'FUSU_CAMBIAR_PASSWORD') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD FUSU_CAMBIAR_PASSWORD CHAR(1) NOT NULL CONSTRAINT DF_TMKK_USUARIO_CAMBIAR_PWD DEFAULT 'N';
GO

-- Datos laborales del usuario. CPEl_ID_HUELLERO = "ID Bio", CPEl_ID_VICIDIAL = "ID Vici" (ya existían)
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CSED_ID_SEDE') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CSED_ID_SEDE INT NULL
        CONSTRAINT FK_TMKK_PERSONAL_SEDE REFERENCES dbo.TMKK_SEDE (CSED_ID_SEDE);
IF COL_LENGTH('dbo.TMKK_PERSONAL', 'CCAM_ID_CAMPANIA') IS NULL
    ALTER TABLE dbo.TMKK_PERSONAL ADD CCAM_ID_CAMPANIA INT NULL
        CONSTRAINT FK_TMKK_PERSONAL_CAMPANIA REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA);
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
GO

-- ==============================================================================
-- 2. DATOS INICIALES
-- ==============================================================================

-- Sedes de la operación
INSERT INTO dbo.TMKK_SEDE (SSED_NOMBRE, FSED_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT s.nombre, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES ('LOS OLIVOS'), ('SAN JUAN DE LURIGANCHO'), ('SURCO')) s (nombre)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_SEDE x WHERE x.SSED_NOMBRE = s.nombre);

-- Campañas (ajustar a la lista real del negocio desde Mantenimiento > Campañas)
INSERT INTO dbo.TMKK_CAMPANIA (SCAM_NOMBRE, SCAM_COLOR, FCAM_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT c.nombre, c.color, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('PORTABILIDAD',     'primary'),
    ('MIGRACIÓN',        'info'),
    ('MANTRA',           'success'),
    ('OUT',              'warning'),
    ('IVR PORTABILIDAD', 'secondary')
) c (nombre, color)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_CAMPANIA x WHERE x.SCAM_NOMBRE = c.nombre);

-- Sistema y perfiles (pestañas de la pantalla)
IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_SISTEMA WHERE SSIT_NOMBRE = 'CRM MAKOKOS')
    INSERT INTO dbo.TMKK_SISTEMA (SSIT_NOMBRE, SSIT_DESCRIPCION, SIT_ESTADO, AUD_INS_FEC, AUD_INS_USER)
    VALUES ('CRM MAKOKOS', 'CRM de ventas, asistencia y llamadas', 'V', GETDATE(), 'AIW_SISTEMAS');

DECLARE @sis INT = (SELECT CSIT_ID_SISTEMA FROM dbo.TMKK_SISTEMA WHERE SSIT_NOMBRE = 'CRM MAKOKOS');

INSERT INTO dbo.TMKK_PERFIL (CSIT_ID_SISTEMA, SPFL_NOMBRE, SPFL_DESCRIPCION, FPFL_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT @sis, p.nombre, p.descr, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('ADMINISTRADOR', 'Acceso total al sistema'),
    ('SUPERVISOR',    'Supervisión de asesores, asistencia y llamadas'),
    ('ASESOR',        'Registro y consulta de sus ventas'),
    ('BACKOFFICE',    'Gestión y validación de ventas')
) p (nombre, descr)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERFIL x WHERE x.CSIT_ID_SISTEMA = @sis AND x.SPFL_NOMBRE = p.nombre);

-- Combos del formulario: puesto y modalidad
INSERT INTO dbo.TMKK_TIP_VALOR (CTPV_COD_TIP_VALOR, CTPV_TIP_VALOR, STPV_DES_TIP_VALOR_1, FTPV_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT t.grupo, t.valor, t.descr, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('MODALIDAD_TRABAJO', 'P', 'Presencial'),
    ('MODALIDAD_TRABAJO', 'R', 'Remoto'),
    ('PUESTO_TRABAJO',    '1', 'Administración'),
    ('PUESTO_TRABAJO',    '2', 'Administrativo'),
    ('PUESTO_TRABAJO',    '3', 'Asesor(a)'),
    ('PUESTO_TRABAJO',    '4', 'Back Office'),
    ('PUESTO_TRABAJO',    '5', 'Marketing'),
    ('PUESTO_TRABAJO',    '6', 'Personal de limpieza'),
    ('PUESTO_TRABAJO',    '7', 'RRHH'),
    ('PUESTO_TRABAJO',    '8', 'Supervisor(a)')
) t (grupo, valor, descr)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR x WHERE x.CTPV_COD_TIP_VALOR = t.grupo AND x.CTPV_TIP_VALOR = t.valor);
GO

-- ==============================================================================
-- 3. COMBOS
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PERFIL
    @i_ESTADO CHAR(1) = 'V'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT pf.CPFL_ID_PERFIL, pf.SPFL_NOMBRE, pf.SPFL_DESCRIPCION, pf.FPFL_ESTADO
    FROM dbo.TMKK_PERFIL pf
    JOIN dbo.TMKK_SISTEMA s ON s.CSIT_ID_SISTEMA = pf.CSIT_ID_SISTEMA AND s.SSIT_NOMBRE = 'CRM MAKOKOS'
    WHERE NULLIF(@i_ESTADO, '') IS NULL OR pf.FPFL_ESTADO = @i_ESTADO
    ORDER BY pf.CPFL_ID_PERFIL;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_SEDE
    @i_CSED_ID_SEDE INT     = NULL,
    @i_ESTADO       CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.CSED_ID_SEDE, s.SSED_NOMBRE, s.SSED_DIRECCION, s.FSED_ESTADO
    FROM dbo.TMKK_SEDE s
    WHERE (@i_CSED_ID_SEDE IS NULL OR s.CSED_ID_SEDE = @i_CSED_ID_SEDE)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR s.FSED_ESTADO = @i_ESTADO)
    ORDER BY s.SSED_NOMBRE;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_CAMPANIA
    @i_CCAM_ID_CAMPANIA INT          = NULL,
    @i_NOMBRE           VARCHAR(100) = NULL,
    @i_ESTADO           CHAR(1)      = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE, c.SCAM_DESCRIPCION, c.SCAM_COLOR, c.FCAM_ESTADO
    FROM dbo.TMKK_CAMPANIA c
    WHERE (@i_CCAM_ID_CAMPANIA IS NULL OR c.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (NULLIF(@i_NOMBRE, '') IS NULL OR c.SCAM_NOMBRE LIKE '%' + @i_NOMBRE + '%')
      AND (NULLIF(@i_ESTADO, '') IS NULL OR c.FCAM_ESTADO = @i_ESTADO)
    ORDER BY c.SCAM_NOMBRE;
END
GO

-- Supervisores activos: perfil SUPERVISOR, puesto Supervisor(a) o con asesores a cargo
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
    WHERE ISNULL(pe.FPEl_ESTADO, 'V') = 'V'
      AND (pf.SPFL_NOMBRE = 'SUPERVISOR' OR pe.CPEL_PUESTO = '8'
           OR EXISTS (SELECT 1 FROM dbo.TMKK_PERSONAL a WHERE a.CPEL_ID_SUPERVISOR = pe.CPEL_ID_PERSONAL AND ISNULL(a.FPEl_ESTADO, 'V') = 'V'))
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
    ORDER BY SNOMBRE_COMPLETO;
END
GO

-- Valores vigentes de un grupo de TMKK_TIP_VALOR (combos de puesto y modalidad)
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_TIP_VALOR_VIGENTE
    @i_COD_TIP_VALOR VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CTPV_TIP_VALOR, STPV_DES_TIP_VALOR_1
    FROM dbo.TMKK_TIP_VALOR
    WHERE CTPV_COD_TIP_VALOR = @i_COD_TIP_VALOR
      AND ISNULL(FTPV_ESTADO, 'V') = 'V'
    ORDER BY CTPV_TIP_VALOR;
END
GO

-- ==============================================================================
-- 4. MANTENIMIENTO > USUARIOS
-- ==============================================================================

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_USUARIO
    @i_CUSU_ID_USUARIO  INT          = NULL,
    @i_CPFL_ID_PERFIL   INT          = NULL,
    @i_CCAM_ID_CAMPANIA INT          = NULL,   -- -1 = sin campaña
    @i_CSED_ID_SEDE     INT          = NULL,   -- -1 = sin sede
    @i_SOLO_VENCIDOS    CHAR(1)      = 'N',    -- S = solo contratos vencidos
    @i_ESTADO           CHAR(1)      = NULL,   -- V / I
    @i_TEXTO            VARCHAR(100) = NULL    -- nombre, usuario, perfil o DNI
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    SELECT
        u.CUSU_ID_USUARIO,
        pe.CPEL_ID_PERSONAL,
        p.CPER_ID_PERSONA,
        TRY_CAST(p.FPER_TIP_DOC_IDENTIDAD AS TINYINT) AS FPER_TIP_DOC_IDENTIDAD,
        p.SPER_NRO_DOC_IDENTIDAD                    AS SNRO_DOCUMENTO,
        COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
        COALESCE(p.SPER_COR_LABORAL, p.SPER_COR_PERSONAL) AS SCORREO,
        p.SPER_CELULAR                              AS SCELULAR,
        u.SUSU_USERNAME,
        pf.CPFL_ID_PERFIL,
        pf.SPFL_NOMBRE                              AS SPERFIL,
        pe.CCAM_ID_CAMPANIA,
        c.SCAM_NOMBRE                               AS SCAMPANIA,
        pe.CSED_ID_SEDE,
        s.SSED_NOMBRE                               AS SSEDE,
        pe.CPEL_PUESTO,
        pe.FPEL_MODALIDAD,
        pe.CPEL_ID_SUPERVISOR,
        pe.CPEl_ID_HUELLERO                         AS SID_BIO,
        pe.CPEL_ID_VENTA                            AS SID_VENTA,
        pe.CPEL_ID_OVER                             AS SID_OVER,
        pe.CPEl_ID_VICIDIAL                         AS SID_VICI,
        pe.SPEL_NUM_CUENTA                          AS SNUM_CUENTA,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_INICIO, 108) AS SHORA_INICIO,
        CONVERT(VARCHAR(5), pe.HPEL_HORA_FIN, 108)    AS SHORA_FIN,
        CAST(pe.FPEl_INGRESO AS DATE)               AS DFEC_INGRESO,
        CAST(pe.FPEl_INICIO_CONTRATO AS DATE)       AS DCONTRATO_INICIO,
        CAST(pe.FPEl_FIN_CONTRATO AS DATE)          AS DCONTRATO_FIN,
        CASE WHEN pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy THEN 'S' ELSE 'N' END AS FCONTRATO_VENCIDO,
        ISNULL(u.FUSU_ESTADO, 'V')                  AS FUSU_ESTADO
    FROM dbo.TMKK_USUARIO u
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = u.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO
    OUTER APPLY (SELECT TOP (1) up.CPFL_ID_PERFIL FROM dbo.TMKK_USUARIO_PERFIL up
                 WHERE up.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO AND ISNULL(up.FUSR_ESTADO, 'V') = 'V'
                 ORDER BY up.DUSR_FECHA_ASIGNACION DESC) upa
    LEFT JOIN dbo.TMKK_PERFIL pf ON pf.CPFL_ID_PERFIL = COALESCE(upa.CPFL_ID_PERFIL, pe.CPFL_ID_PERFIL)
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = pe.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_SEDE s ON s.CSED_ID_SEDE = pe.CSED_ID_SEDE
    WHERE (@i_CUSU_ID_USUARIO IS NULL OR u.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO)
      AND (@i_CPFL_ID_PERFIL IS NULL OR pf.CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL)
      AND (@i_CCAM_ID_CAMPANIA IS NULL
           OR (@i_CCAM_ID_CAMPANIA = -1 AND pe.CCAM_ID_CAMPANIA IS NULL)
           OR pe.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (@i_CSED_ID_SEDE IS NULL
           OR (@i_CSED_ID_SEDE = -1 AND pe.CSED_ID_SEDE IS NULL)
           OR pe.CSED_ID_SEDE = @i_CSED_ID_SEDE)
      AND (ISNULL(@i_SOLO_VENCIDOS, 'N') <> 'S'
           OR (pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy))
      AND (NULLIF(@i_ESTADO, '') IS NULL OR ISNULL(u.FUSU_ESTADO, 'V') = @i_ESTADO)
      AND (NULLIF(@i_TEXTO, '') IS NULL
           OR u.SUSU_USERNAME LIKE '%' + @i_TEXTO + '%'
           OR pf.SPFL_NOMBRE LIKE '%' + @i_TEXTO + '%'
           OR p.SPER_NRO_DOC_IDENTIDAD LIKE @i_TEXTO + '%'
           OR COALESCE(p.SPER_NOM_COMPLETO, CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE)) LIKE '%' + @i_TEXTO + '%')
    ORDER BY u.CUSU_ID_USUARIO;
END
GO

-- Tarjetas. Result set 1: totales; 2: activos por campaña; 3: activos por sede.
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_USUARIO_RESUMEN
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @hoy DATE = CAST(GETDATE() AS DATE);

    SELECT
        SUM(CASE WHEN ISNULL(u.FUSU_ESTADO, 'V') = 'V' THEN 1 ELSE 0 END) AS NACTIVOS,
        SUM(CASE WHEN pe.FPEl_FIN_CONTRATO IS NOT NULL AND CAST(pe.FPEl_FIN_CONTRATO AS DATE) < @hoy THEN 1 ELSE 0 END) AS NCONTRATOS_VENCIDOS
    FROM dbo.TMKK_USUARIO u
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO;

    SELECT c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE, COUNT(u.CUSU_ID_USUARIO) AS NUSUARIOS
    FROM dbo.TMKK_CAMPANIA c
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CCAM_ID_CAMPANIA = c.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = pe.CUSU_ID_USUARIO AND ISNULL(u.FUSU_ESTADO, 'V') = 'V'
    WHERE c.FCAM_ESTADO = 'V'
    GROUP BY c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE
    ORDER BY c.SCAM_NOMBRE;

    SELECT s.CSED_ID_SEDE, s.SSED_NOMBRE, COUNT(u.CUSU_ID_USUARIO) AS NUSUARIOS
    FROM dbo.TMKK_SEDE s
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CSED_ID_SEDE = s.CSED_ID_SEDE
    LEFT JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = pe.CUSU_ID_USUARIO AND ISNULL(u.FUSU_ESTADO, 'V') = 'V'
    WHERE s.FSED_ESTADO = 'V'
    GROUP BY s.CSED_ID_SEDE, s.SSED_NOMBRE
    ORDER BY s.SSED_NOMBRE;
END
GO

-- ------------------------------------------------------------------------------
-- Alta de usuario. Crea o reutiliza la persona (por tipo y número de documento),
-- el usuario, su perfil y su registro de personal. La contraseña la genera la API
-- (hash BCrypt) y queda marcada para cambio obligatorio.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_USUARIO
    @i_NOMBRE_COMPLETO    VARCHAR(200),
    @i_TIP_DOC            TINYINT      = 1,       -- TMKK_TIP_DOC_IDENTIDAD (1 = DNI)
    @i_NRO_DOC            VARCHAR(16)  = NULL,
    @i_CORREO             VARCHAR(100) = NULL,
    @i_CELULAR            VARCHAR(16)  = NULL,
    @i_USERNAME           VARCHAR(50),
    @i_PASSWORD_HASH      VARCHAR(255),
    @i_CPFL_ID_PERFIL     INT,
    @i_CCAM_ID_CAMPANIA   INT          = NULL,
    @i_CSED_ID_SEDE       INT          = NULL,
    @i_CPEL_PUESTO        VARCHAR(8)   = NULL,
    @i_FPEL_MODALIDAD     CHAR(1)      = NULL,
    @i_CPEL_ID_SUPERVISOR INT          = NULL,
    @i_ID_BIO             VARCHAR(16)  = NULL,
    @i_ID_VENTA           VARCHAR(30)  = NULL,
    @i_ID_OVER            VARCHAR(16)  = NULL,
    @i_ID_VICI            VARCHAR(16)  = NULL,
    @i_HORA_INICIO        TIME(0)      = NULL,
    @i_HORA_FIN           TIME(0)      = NULL,
    @i_FEC_INGRESO        DATE         = NULL,
    @i_CONTRATO_INICIO    DATE         = NULL,
    @i_CONTRATO_FIN       DATE         = NULL,
    @i_NUM_CUENTA         VARCHAR(30)  = NULL,
    @i_ESTADO             CHAR(1)      = 'V',
    @i_AUD_INS_USER       VARCHAR(16),
    @o_CUSU_ID_USUARIO    INT OUTPUT,
    @o_CPEL_ID_PERSONAL   INT OUTPUT,
    @o_resultMessage      VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @persona INT, @tipDoc VARCHAR(3) = CAST(@i_TIP_DOC AS VARCHAR(3));

        IF EXISTS (SELECT 1 FROM dbo.TMKK_USUARIO WHERE SUSU_USERNAME = @i_USERNAME)
        BEGIN
            SET @o_resultMessage = '0|El nombre de usuario ya está en uso';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERFIL WHERE CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL AND ISNULL(FPFL_ESTADO, 'V') = 'V')
        BEGIN
            SET @o_resultMessage = '0|Perfil no válido';
            RETURN;
        END

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_SEDE WHERE CSED_ID_SEDE = @i_CSED_ID_SEDE AND FSED_ESTADO = 'V')
        BEGIN
            SET @o_resultMessage = '0|Seleccione una sede válida';
            RETURN;
        END

        IF @i_CONTRATO_INICIO IS NOT NULL AND @i_CONTRATO_FIN IS NOT NULL AND @i_CONTRATO_FIN < @i_CONTRATO_INICIO
        BEGIN
            SET @o_resultMessage = '0|La fecha fin de contrato no puede ser menor a la de inicio';
            RETURN;
        END

        IF NULLIF(@i_NRO_DOC, '') IS NOT NULL
            SELECT TOP (1) @persona = CPER_ID_PERSONA FROM dbo.TPLS_PERSONA
            WHERE SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC AND CAST(FPER_TIP_DOC_IDENTIDAD AS VARCHAR(3)) = @tipDoc;

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
            VALUES ('1', CASE WHEN NULLIF(@i_NRO_DOC, '') IS NULL THEN NULL ELSE @tipDoc END, NULLIF(@i_NRO_DOC, ''),
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
                @i_HORA_INICIO, @i_HORA_FIN, ISNULL(@i_FEC_INGRESO, CAST(GETDATE() AS DATE)), @i_CONTRATO_INICIO, @i_CONTRATO_FIN,
                NULLIF(@i_NUM_CUENTA, ''), 'V', GETDATE(), @i_AUD_INS_USER);
        SET @o_CPEL_ID_PERSONAL = SCOPE_IDENTITY();

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
-- Edición de usuario. Puede conservar su sede aunque se haya inactivado, pero no
-- pasar a una sede inactiva.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_USUARIO
    @i_CUSU_ID_USUARIO    INT,
    @i_NOMBRE_COMPLETO    VARCHAR(200),
    @i_TIP_DOC            TINYINT      = 1,
    @i_NRO_DOC            VARCHAR(16)  = NULL,
    @i_CORREO             VARCHAR(100) = NULL,
    @i_CELULAR            VARCHAR(16)  = NULL,
    @i_USERNAME           VARCHAR(50),
    @i_CPFL_ID_PERFIL     INT,
    @i_CCAM_ID_CAMPANIA   INT          = NULL,
    @i_CSED_ID_SEDE       INT          = NULL,
    @i_CPEL_PUESTO        VARCHAR(8)   = NULL,
    @i_FPEL_MODALIDAD     CHAR(1)      = NULL,
    @i_CPEL_ID_SUPERVISOR INT          = NULL,
    @i_ID_BIO             VARCHAR(16)  = NULL,
    @i_ID_VENTA           VARCHAR(30)  = NULL,
    @i_ID_OVER            VARCHAR(16)  = NULL,
    @i_ID_VICI            VARCHAR(16)  = NULL,
    @i_HORA_INICIO        TIME(0)      = NULL,
    @i_HORA_FIN           TIME(0)      = NULL,
    @i_FEC_INGRESO        DATE         = NULL,
    @i_CONTRATO_INICIO    DATE         = NULL,
    @i_CONTRATO_FIN       DATE         = NULL,
    @i_NUM_CUENTA         VARCHAR(30)  = NULL,
    @i_ESTADO             CHAR(1)      = 'V',
    @i_AUD_UPD_USER       VARCHAR(16),
    @o_resultMessage      VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @persona INT, @personal INT, @sedeActual INT, @tipDoc VARCHAR(3) = CAST(@i_TIP_DOC AS VARCHAR(3));

        SELECT @persona = u.CPER_ID_PERSONA, @personal = pe.CPEL_ID_PERSONAL, @sedeActual = pe.CSED_ID_SEDE
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

        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERFIL WHERE CPFL_ID_PERFIL = @i_CPFL_ID_PERFIL AND ISNULL(FPFL_ESTADO, 'V') = 'V')
        BEGIN
            SET @o_resultMessage = '0|Perfil no válido';
            RETURN;
        END

        IF NULLIF(@i_NRO_DOC, '') IS NOT NULL AND EXISTS (
            SELECT 1 FROM dbo.TPLS_PERSONA p JOIN dbo.TMKK_USUARIO u ON u.CPER_ID_PERSONA = p.CPER_ID_PERSONA
            WHERE p.SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOC AND CAST(p.FPER_TIP_DOC_IDENTIDAD AS VARCHAR(3)) = @tipDoc
              AND p.CPER_ID_PERSONA <> @persona)
        BEGIN
            SET @o_resultMessage = '0|Otro usuario ya tiene el documento ' + @i_NRO_DOC;
            RETURN;
        END

        IF @i_CSED_ID_SEDE IS NULL
           OR (@i_CSED_ID_SEDE <> ISNULL(@sedeActual, 0)
               AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_SEDE WHERE CSED_ID_SEDE = @i_CSED_ID_SEDE AND FSED_ESTADO = 'V'))
        BEGIN
            SET @o_resultMessage = '0|Seleccione una sede válida';
            RETURN;
        END

        IF @i_CPEL_ID_SUPERVISOR IS NOT NULL AND @i_CPEL_ID_SUPERVISOR = @personal
        BEGIN
            SET @o_resultMessage = '0|Un usuario no puede ser su propio supervisor';
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
            FPER_TIP_DOC_IDENTIDAD = CASE WHEN NULLIF(@i_NRO_DOC, '') IS NULL THEN FPER_TIP_DOC_IDENTIDAD ELSE @tipDoc END,
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

        -- Usuarios antiguos sin registro de personal
        IF @personal IS NULL
        BEGIN
            INSERT INTO dbo.TMKK_PERSONAL (CPER_ID_PERSONA, CUSU_ID_USUARIO, CPFL_ID_PERFIL, FPEl_ESTADO, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@persona, @i_CUSU_ID_USUARIO, @i_CPFL_ID_PERFIL, 'V', GETDATE(), @i_AUD_UPD_USER);
            SET @personal = SCOPE_IDENTITY();
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
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CPEL_ID_PERSONAL = @personal;

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

        UPDATE dbo.TMKK_USUARIO
        SET FUSU_ESTADO = @i_ESTADO, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        SET @o_resultMessage = '1|Estado actualizado';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Restablecer contraseña desde Mantenimiento > Usuarios. Con @i_FORZAR_CAMBIO = 'S'
-- el usuario deberá cambiarla en su próximo login. @i_CERRAR_SESIONES se acepta
-- por compatibilidad con la API; esta BD aún no registra sesiones.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_CAMBIAR_PASSWORD
    @i_CUSU_ID_USUARIO   INT,
    @i_PASSWORD_HASH     VARCHAR(255),
    @i_FORZAR_CAMBIO     CHAR(1) = 'N',
    @i_CERRAR_SESIONES   CHAR(1) = 'N',
    @i_AUD_UPD_USER      VARCHAR(16),
    @o_resultMessage     VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE dbo.TMKK_USUARIO
        SET SUSU_PASSWORD_HASH = @i_PASSWORD_HASH,
            FUSU_CAMBIAR_PASSWORD = ISNULL(@i_FORZAR_CAMBIO, 'N'),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        SET @o_resultMessage = '1|Contraseña actualizada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

PRINT 'Mantenimiento > Usuarios + Sede aplicado correctamente.';
GO
