-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 03: MAESTROS Y CATÁLOGOS
--   Tablas : TMKK_CAMPANIA, TMKK_SEDE, TMKK_UBIGEO
--   Datos  : planes, campañas, sedes y grupos nuevos de TMKK_TIP_VALOR que usa el front
--   SPs    : CRUD de campañas, sedes, operadores y planes; consulta de ubigeo y
--            tipos de documento (Mantenimiento > Campañas / Estados / Operadores)
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF OBJECT_ID('dbo.TMKK_UBIGEO') IS NULL
CREATE TABLE dbo.TMKK_UBIGEO (
    CUBI_COD_UBIGEO     CHAR(6) NOT NULL CONSTRAINT PK_TMKK_UBIGEO PRIMARY KEY,  -- código INEI
    SUBI_DEPARTAMENTO   VARCHAR(50) NOT NULL,
    SUBI_PROVINCIA      VARCHAR(50) NOT NULL,
    SUBI_DISTRITO       VARCHAR(80) NOT NULL,
    FUBI_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_UBIGEO_ESTADO DEFAULT 'V',
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
    SCAM_COLOR          VARCHAR(20) NULL,       -- color de Vuetify para chips (primary, info, ...)
    FCAM_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_CAMPANIA_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_CAMPANIA_OPERADOR FOREIGN KEY (COPE_ID_OPERADOR) REFERENCES dbo.TMKK_OPERADOR (COPE_ID_OPERADOR)
);
GO

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
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_SEDE_UBIGEO FOREIGN KEY (CUBI_COD_UBIGEO) REFERENCES dbo.TMKK_UBIGEO (CUBI_COD_UBIGEO)
);
GO

-- Nombre único de plan para poder buscarlo desde el front ("39.90")
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_PLAN_NOMBRE')
    CREATE UNIQUE INDEX UX_TMKK_PLAN_NOMBRE ON dbo.TMKK_PLAN (SPLN_NOMBRE);
GO

-- ==============================================================================
-- 2. DATOS INICIALES
-- ==============================================================================

-- Ubigeos usados hoy en el front (Registro de Ventas y sedes). Cargue el resto
-- desde la lista oficial del INEI con el mismo formato.
INSERT INTO dbo.TMKK_UBIGEO (CUBI_COD_UBIGEO, SUBI_DEPARTAMENTO, SUBI_PROVINCIA, SUBI_DISTRITO, AUD_INS_FEC, AUD_INS_USER)
SELECT u.cod, u.dep, u.prov, u.dist, GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('150101', 'LIMA',   'LIMA',   'LIMA'),
    ('150116', 'LIMA',   'LIMA',   'LINCE'),
    ('150132', 'LIMA',   'LIMA',   'SAN JUAN DE LURIGANCHO'),
    ('150140', 'LIMA',   'LIMA',   'SANTIAGO DE SURCO'),
    ('070101', 'CALLAO', 'CALLAO', 'CALLAO'),
    ('070102', 'CALLAO', 'CALLAO', 'BELLAVISTA')
) u (cod, dep, prov, dist)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_UBIGEO x WHERE x.CUBI_COD_UBIGEO = u.cod);

-- Campañas que aparecen en el front (Usuarios, Asistencia, Llamadas y Dashboard)
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

INSERT INTO dbo.TMKK_SEDE (SSED_NOMBRE, CUBI_COD_UBIGEO, FSED_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT s.nombre, s.ubigeo, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    ('SURCO',                  '150140'),
    ('SAN JUAN DE LURIGANCHO', '150132'),
    ('LINCE',                  '150116')
) s (nombre, ubigeo)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_SEDE x WHERE x.SSED_NOMBRE = s.nombre);

-- Planes del Registro de Ventas
INSERT INTO dbo.TMKK_PLAN (SPLN_NOMBRE, SPLN_DES_PLAN, NPLN_VALOR_PLAN, FPLN_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT p.nombre, 'PLAN ' + p.nombre, CAST(p.nombre AS DECIMAL(14, 2)), 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES ('19.90'), ('29.90'), ('39.90'), ('49.90'), ('55.90'), ('65.90'), ('69.90'), ('79.90'), ('105.90')) p (nombre)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_PLAN x WHERE x.SPLN_NOMBRE = p.nombre);

-- Grupos nuevos de TMKK_TIP_VALOR (listas cortas del front)
INSERT INTO dbo.TMKK_TIP_VALOR (CTPV_COD_TIP_VALOR, CTPV_TIP_VALOR, STPV_DES_TIP_VALOR_1, STPV_DES_TIP_VALOR_2, FTPV_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT t.grupo, t.valor, t.descr, t.descr2, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM (VALUES
    -- Lista de Ventas > Canal de venta
    ('CANAL_VENTA',       '1', 'CALL CENTER',              NULL),
    ('CANAL_VENTA',       '2', 'CAMPO',                    NULL),
    ('CANAL_VENTA',       '3', 'REDES SOCIALES',           NULL),
    ('CANAL_VENTA',       '4', 'STAND',                    NULL),
    -- Registro de Ventas > Portabilidad > Modalidad
    ('MODALIDAD_LINEA',   '1', 'POSTPAGO',                 NULL),
    ('MODALIDAD_LINEA',   '2', 'PREPAGO',                  NULL),
    -- HeadCount
    ('MODALIDAD_TRABAJO', 'P', 'Presencial',               NULL),
    ('MODALIDAD_TRABAJO', 'R', 'Remoto',                   NULL),
    ('PUESTO_TRABAJO',    '1', 'Administración',           NULL),
    ('PUESTO_TRABAJO',    '2', 'Administrativo',           NULL),
    ('PUESTO_TRABAJO',    '3', 'Asesor(a)',                NULL),
    ('PUESTO_TRABAJO',    '4', 'Back Office',              NULL),
    ('PUESTO_TRABAJO',    '5', 'Marketing',                NULL),
    ('PUESTO_TRABAJO',    '6', 'Personal de limpieza',     NULL),
    ('PUESTO_TRABAJO',    '7', 'RRHH',                     NULL),
    ('PUESTO_TRABAJO',    '8', 'Supervisor(a)',            NULL),
    ('TIPO_BAJA',         '1', 'Renuncia',                 NULL),
    ('TIPO_BAJA',         '2', 'Abandono',                 NULL),
    ('TIPO_BAJA',         '3', 'Fin de contrato',          NULL),
    ('TIPO_BAJA',         '4', 'Retiro por desempeño',     NULL),
    -- TPLS_PERSONA.FPER_TIP_SEXO / FPER_TIP_EST_CIVIL
    ('TIP_SEXO',          'F', 'Femenino',                 NULL),
    ('TIP_SEXO',          'M', 'Masculino',                NULL),
    ('TIP_EST_CIVIL',     'S', 'Soltero(a)',               NULL),
    ('TIP_EST_CIVIL',     'C', 'Casado(a)',                NULL),
    ('TIP_EST_CIVIL',     'N', 'Conviviente',              NULL),
    ('TIP_EST_CIVIL',     'D', 'Divorciado(a)',            NULL),
    ('TIP_EST_CIVIL',     'V', 'Viudo(a)',                 NULL)
) t (grupo, valor, descr, descr2)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR x WHERE x.CTPV_COD_TIP_VALOR = t.grupo AND x.CTPV_TIP_VALOR = t.valor);

-- Color de Vuetify para cada estado de venta (STPV_DES_TIP_VALOR_2), igual que estadoColor() del front
UPDATE tv
SET STPV_DES_TIP_VALOR_2 = c.color
FROM dbo.TMKK_TIP_VALOR tv
JOIN (VALUES ('ACTIVADO', 'success'), ('INGRESADO', 'success'), ('PENDIENTE', 'warning'), ('PROCESAMIENTO', 'warning'),
             ('OBSERVACION', 'warning'), ('CANCELADO', 'error'), ('CAIDO', 'error')) c (estado, color)
  ON c.estado = tv.STPV_DES_TIP_VALOR_1
WHERE tv.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND tv.STPV_DES_TIP_VALOR_2 IS NULL;
GO

-- ==============================================================================
-- 3. STORED PROCEDURES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- CAMPAÑAS
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_CAMPANIA
    @i_CCAM_ID_CAMPANIA INT         = NULL,
    @i_NOMBRE           VARCHAR(100) = NULL,
    @i_ESTADO           CHAR(1)     = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT c.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE, c.SCAM_DESCRIPCION, c.COPE_ID_OPERADOR, o.SOPE_NOMBRE,
           c.SCAM_COLOR, c.FCAM_ESTADO, c.AUD_INS_FEC, c.AUD_INS_USER, c.AUD_UPD_FEC, c.AUD_UPD_USER
    FROM dbo.TMKK_CAMPANIA c
    LEFT JOIN dbo.TMKK_OPERADOR o ON o.COPE_ID_OPERADOR = c.COPE_ID_OPERADOR
    WHERE (@i_CCAM_ID_CAMPANIA IS NULL OR c.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (NULLIF(@i_NOMBRE, '') IS NULL OR c.SCAM_NOMBRE LIKE '%' + @i_NOMBRE + '%')
      AND (NULLIF(@i_ESTADO, '') IS NULL OR c.FCAM_ESTADO = @i_ESTADO)
    ORDER BY c.SCAM_NOMBRE;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_CAMPANIA
    @i_NOMBRE           VARCHAR(100),
    @i_DESCRIPCION      VARCHAR(255) = NULL,
    @i_COPE_ID_OPERADOR SMALLINT     = NULL,
    @i_COLOR            VARCHAR(20)  = NULL,
    @i_AUD_INS_USER     VARCHAR(16),
    @o_CCAM_ID_CAMPANIA INT OUTPUT,
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_CAMPANIA WHERE SCAM_NOMBRE = @i_NOMBRE)
        BEGIN
            SET @o_resultMessage = '0|Ya existe una campaña con ese nombre';
            RETURN;
        END

        INSERT INTO dbo.TMKK_CAMPANIA (SCAM_NOMBRE, SCAM_DESCRIPCION, COPE_ID_OPERADOR, SCAM_COLOR, FCAM_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (UPPER(LTRIM(RTRIM(@i_NOMBRE))), NULLIF(@i_DESCRIPCION, ''), @i_COPE_ID_OPERADOR, NULLIF(@i_COLOR, ''), 'V', GETDATE(), @i_AUD_INS_USER);

        SET @o_CCAM_ID_CAMPANIA = SCOPE_IDENTITY();
        SET @o_resultMessage = '1|Registro correcto';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_CAMPANIA
    @i_CCAM_ID_CAMPANIA INT,
    @i_NOMBRE           VARCHAR(100),
    @i_DESCRIPCION      VARCHAR(255) = NULL,
    @i_COPE_ID_OPERADOR SMALLINT     = NULL,
    @i_COLOR            VARCHAR(20)  = NULL,
    @i_AUD_UPD_USER     VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_CAMPANIA WHERE SCAM_NOMBRE = @i_NOMBRE AND CCAM_ID_CAMPANIA <> @i_CCAM_ID_CAMPANIA)
        BEGIN
            SET @o_resultMessage = '0|Ya existe una campaña con ese nombre';
            RETURN;
        END

        UPDATE dbo.TMKK_CAMPANIA
        SET SCAM_NOMBRE = UPPER(LTRIM(RTRIM(@i_NOMBRE))), SCAM_DESCRIPCION = NULLIF(@i_DESCRIPCION, ''),
            COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR, SCAM_COLOR = NULLIF(@i_COLOR, ''),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA;

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

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_EST_CAMPANIA
    @i_CCAM_ID_CAMPANIA INT,
    @i_ESTADO           CHAR(1),    -- V / I
    @i_AUD_UPD_USER     VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_ESTADO NOT IN ('V', 'I')
        BEGIN
            SET @o_resultMessage = '0|Estado no válido. Use V (vigente) o I (inactivo)';
            RETURN;
        END

        UPDATE dbo.TMKK_CAMPANIA
        SET FCAM_ESTADO = @i_ESTADO, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Registro no encontrado';
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
-- SEDES
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_SEDE
    @i_CSED_ID_SEDE INT     = NULL,
    @i_ESTADO       CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.CSED_ID_SEDE, s.SSED_NOMBRE, s.SSED_DIRECCION, s.CUBI_COD_UBIGEO,
           u.SUBI_DEPARTAMENTO + ' - ' + u.SUBI_PROVINCIA + ' - ' + u.SUBI_DISTRITO AS SUBIGEO,
           s.FSED_ESTADO
    FROM dbo.TMKK_SEDE s
    LEFT JOIN dbo.TMKK_UBIGEO u ON u.CUBI_COD_UBIGEO = s.CUBI_COD_UBIGEO
    WHERE (@i_CSED_ID_SEDE IS NULL OR s.CSED_ID_SEDE = @i_CSED_ID_SEDE)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR s.FSED_ESTADO = @i_ESTADO)
    ORDER BY s.SSED_NOMBRE;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_SEDE
    @i_NOMBRE          VARCHAR(100),
    @i_DIRECCION       VARCHAR(250) = NULL,
    @i_CUBI_COD_UBIGEO CHAR(6)      = NULL,
    @i_AUD_INS_USER    VARCHAR(16),
    @o_CSED_ID_SEDE    INT OUTPUT,
    @o_resultMessage   VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_SEDE WHERE SSED_NOMBRE = @i_NOMBRE)
        BEGIN
            SET @o_resultMessage = '0|Ya existe una sede con ese nombre';
            RETURN;
        END

        INSERT INTO dbo.TMKK_SEDE (SSED_NOMBRE, SSED_DIRECCION, CUBI_COD_UBIGEO, FSED_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (UPPER(LTRIM(RTRIM(@i_NOMBRE))), NULLIF(@i_DIRECCION, ''), NULLIF(@i_CUBI_COD_UBIGEO, ''), 'V', GETDATE(), @i_AUD_INS_USER);

        SET @o_CSED_ID_SEDE = SCOPE_IDENTITY();
        SET @o_resultMessage = '1|Registro correcto';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_SEDE
    @i_CSED_ID_SEDE    INT,
    @i_NOMBRE          VARCHAR(100),
    @i_DIRECCION       VARCHAR(250) = NULL,
    @i_CUBI_COD_UBIGEO CHAR(6)      = NULL,
    @i_ESTADO          CHAR(1)      = NULL,   -- NULL = no cambia
    @i_AUD_UPD_USER    VARCHAR(16),
    @o_resultMessage   VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_SEDE WHERE SSED_NOMBRE = @i_NOMBRE AND CSED_ID_SEDE <> @i_CSED_ID_SEDE)
        BEGIN
            SET @o_resultMessage = '0|Ya existe una sede con ese nombre';
            RETURN;
        END

        UPDATE dbo.TMKK_SEDE
        SET SSED_NOMBRE = UPPER(LTRIM(RTRIM(@i_NOMBRE))), SSED_DIRECCION = NULLIF(@i_DIRECCION, ''),
            CUBI_COD_UBIGEO = NULLIF(@i_CUBI_COD_UBIGEO, ''), FSED_ESTADO = COALESCE(NULLIF(@i_ESTADO, ''), FSED_ESTADO),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CSED_ID_SEDE = @i_CSED_ID_SEDE;

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
-- OPERADORES (COPE_ID_OPERADOR no es IDENTITY: se asigna el siguiente correlativo)
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_OPERADOR
    @i_COPE_ID_OPERADOR SMALLINT = NULL,
    @i_ESTADO           CHAR(1)  = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT COPE_ID_OPERADOR, SOPE_NOMBRE, SOPE_NOM_CORTO, SOPE_ID_EXTERNO, FOPE_ESTADO,
           AUD_INS_FEC, AUD_INS_USER, AUD_UPD_FEC, AUD_UPD_USER
    FROM dbo.TMKK_OPERADOR
    WHERE (@i_COPE_ID_OPERADOR IS NULL OR COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR FOPE_ESTADO = @i_ESTADO)
    ORDER BY COPE_ID_OPERADOR;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_OPERADOR
    @i_NOMBRE           VARCHAR(60),
    @i_NOM_CORTO        VARCHAR(30) = NULL,
    @i_ID_EXTERNO       VARCHAR(5)  = NULL,
    @i_AUD_INS_USER     VARCHAR(16),
    @o_COPE_ID_OPERADOR SMALLINT OUTPUT,
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_OPERADOR WHERE SOPE_NOMBRE = @i_NOMBRE)
        BEGIN
            SET @o_resultMessage = '0|Ya existe un operador con ese nombre';
            RETURN;
        END

        BEGIN TRANSACTION;

        SELECT @o_COPE_ID_OPERADOR = ISNULL(MAX(COPE_ID_OPERADOR), 0) + 1
        FROM dbo.TMKK_OPERADOR WITH (UPDLOCK, HOLDLOCK);

        INSERT INTO dbo.TMKK_OPERADOR (COPE_ID_OPERADOR, SOPE_NOMBRE, SOPE_NOM_CORTO, SOPE_ID_EXTERNO, FOPE_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (@o_COPE_ID_OPERADOR, UPPER(LTRIM(RTRIM(@i_NOMBRE))), NULLIF(@i_NOM_CORTO, ''), NULLIF(@i_ID_EXTERNO, ''), 'V', GETDATE(), @i_AUD_INS_USER);

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Registro correcto';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_OPERADOR
    @i_COPE_ID_OPERADOR SMALLINT,
    @i_NOMBRE           VARCHAR(60),
    @i_NOM_CORTO        VARCHAR(30) = NULL,
    @i_ID_EXTERNO       VARCHAR(5)  = NULL,
    @i_ESTADO           CHAR(1)     = NULL,   -- NULL = no cambia
    @i_AUD_UPD_USER     VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_OPERADOR WHERE SOPE_NOMBRE = @i_NOMBRE AND COPE_ID_OPERADOR <> @i_COPE_ID_OPERADOR)
        BEGIN
            SET @o_resultMessage = '0|Ya existe un operador con ese nombre';
            RETURN;
        END

        UPDATE dbo.TMKK_OPERADOR
        SET SOPE_NOMBRE = UPPER(LTRIM(RTRIM(@i_NOMBRE))), SOPE_NOM_CORTO = NULLIF(@i_NOM_CORTO, ''),
            SOPE_ID_EXTERNO = NULLIF(@i_ID_EXTERNO, ''), FOPE_ESTADO = COALESCE(NULLIF(@i_ESTADO, ''), FOPE_ESTADO),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR;

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
-- PLANES
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_PLAN
    @i_CPLN_ID_CODIGO INT     = NULL,
    @i_ESTADO         CHAR(1) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CPLN_ID_CODIGO, SPLN_NOMBRE, SPLN_DES_PLAN, NPLN_VALOR_PLAN, FPLN_ESTADO
    FROM dbo.TMKK_PLAN
    WHERE (@i_CPLN_ID_CODIGO IS NULL OR CPLN_ID_CODIGO = @i_CPLN_ID_CODIGO)
      AND (NULLIF(@i_ESTADO, '') IS NULL OR FPLN_ESTADO = @i_ESTADO)
    ORDER BY NPLN_VALOR_PLAN;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_PLAN
    @i_NOMBRE         VARCHAR(100),
    @i_DESCRIPCION    VARCHAR(100),
    @i_VALOR          DECIMAL(14, 2),
    @i_AUD_INS_USER   VARCHAR(16),
    @o_CPLN_ID_CODIGO INT OUTPUT,
    @o_resultMessage  VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_PLAN WHERE SPLN_NOMBRE = @i_NOMBRE)
        BEGIN
            SET @o_resultMessage = '0|Ya existe un plan con ese nombre';
            RETURN;
        END

        INSERT INTO dbo.TMKK_PLAN (SPLN_NOMBRE, SPLN_DES_PLAN, NPLN_VALOR_PLAN, FPLN_ESTADO, AUD_INS_FEC, AUD_INS_USER)
        VALUES (LTRIM(RTRIM(@i_NOMBRE)), @i_DESCRIPCION, @i_VALOR, 'V', GETDATE(), @i_AUD_INS_USER);

        SET @o_CPLN_ID_CODIGO = SCOPE_IDENTITY();
        SET @o_resultMessage = '1|Registro correcto';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_PLAN
    @i_CPLN_ID_CODIGO INT,
    @i_NOMBRE         VARCHAR(100),
    @i_DESCRIPCION    VARCHAR(100),
    @i_VALOR          DECIMAL(14, 2),
    @i_ESTADO         CHAR(1) = NULL,   -- NULL = no cambia
    @i_AUD_UPD_USER   VARCHAR(16),
    @o_resultMessage  VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF EXISTS (SELECT 1 FROM dbo.TMKK_PLAN WHERE SPLN_NOMBRE = @i_NOMBRE AND CPLN_ID_CODIGO <> @i_CPLN_ID_CODIGO)
        BEGIN
            SET @o_resultMessage = '0|Ya existe un plan con ese nombre';
            RETURN;
        END

        UPDATE dbo.TMKK_PLAN
        SET SPLN_NOMBRE = LTRIM(RTRIM(@i_NOMBRE)), SPLN_DES_PLAN = @i_DESCRIPCION, NPLN_VALOR_PLAN = @i_VALOR,
            FPLN_ESTADO = COALESCE(NULLIF(@i_ESTADO, ''), FPLN_ESTADO),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CPLN_ID_CODIGO = @i_CPLN_ID_CODIGO;

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
-- UBIGEO (autocomplete "Departamento - Provincia - Distrito" del Registro de Ventas)
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_UBIGEO
    @i_TEXTO VARCHAR(100) = NULL,
    @i_TOP   INT          = 50
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (@i_TOP)
        CUBI_COD_UBIGEO,
        SUBI_DEPARTAMENTO, SUBI_PROVINCIA, SUBI_DISTRITO,
        SUBI_DEPARTAMENTO + ' - ' + SUBI_PROVINCIA + ' - ' + SUBI_DISTRITO AS SUBIGEO
    FROM dbo.TMKK_UBIGEO
    WHERE FUBI_ESTADO = 'V'
      AND (NULLIF(@i_TEXTO, '') IS NULL
           OR SUBI_DEPARTAMENTO + ' - ' + SUBI_PROVINCIA + ' - ' + SUBI_DISTRITO LIKE '%' + @i_TEXTO + '%')
    ORDER BY SUBI_DEPARTAMENTO, SUBI_PROVINCIA, SUBI_DISTRITO;
END
GO

-- ------------------------------------------------------------------------------
-- TIPOS DE DOCUMENTO DE IDENTIDAD (select "Tipo Doc" del Registro de Ventas)
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_TIP_DOC_IDENTIDAD
    @i_ESTADO CHAR(1) = 'V'
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CTDI_ID_DOCUMENTO, STDI_NOMBRE, STDI_ABREVIATURA, FTDI_TIP_PERSONA, FTDI_TIP_CONTENIDO,
           NTDI_MIN_LONGITUD, NTDI_MAX_LONGITUD, FTDI_ESTADO
    FROM dbo.TMKK_TIP_DOC_IDENTIDAD
    WHERE NULLIF(@i_ESTADO, '') IS NULL OR FTDI_ESTADO = @i_ESTADO
    ORDER BY CTDI_ID_DOCUMENTO;
END
GO
