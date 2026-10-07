-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 07: VENTAS (Registro de Ventas, Lista de Ventas, Gestión BO)
--   Tablas : columnas nuevas en TMKK_VENTA, TMKK_VENTA_PORTABILIDAD y TMKK_VENTA_POST_POST
--            TMKK_VENTA_BIOMETRIA   (validación de PRE A POST y POST A POST)
--            TMKK_VENTA_ESTADO_HIST (trazabilidad de cambios de estado del BackOffice)
--            TMKK_META_VENTA        (meta mensual del dashboard)
--   SPs    : registrar / editar / anular venta, lista paginada, tarjetas por tipo,
--            detalle, cambio de estado, metas.
--
-- Códigos (TMKK_TIP_VALOR):
--   TIPO_VENTA       1 PRE A POST, 2 PORTABILIDAD, 3 POST A POST, 4 LINEA NUEVA
--   TIP_ESTADO_VENTA 1 ACTIVADO, 2 CANCELADO, 3 PENDIENTE, 4 CAIDO, 6 PROCESAMIENTO,
--                    7 OBSERVACION, 8 INGRESADO
-- FVEN_ESTADO sigue siendo el estado del registro (V vigente / I anulado);
-- CVEN_ESTADO_VENTA es el estado comercial.
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

IF COL_LENGTH('dbo.TMKK_VENTA', 'CPEL_ID_ASESOR') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CPEL_ID_ASESOR INT NULL
        CONSTRAINT FK_TMKK_VENTA_ASESOR REFERENCES dbo.TMKK_PERSONAL (CPEL_ID_PERSONAL);
IF COL_LENGTH('dbo.TMKK_VENTA', 'CCAM_ID_CAMPANIA') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CCAM_ID_CAMPANIA INT NULL
        CONSTRAINT FK_TMKK_VENTA_CAMPANIA REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA);
IF COL_LENGTH('dbo.TMKK_VENTA', 'CVEN_CANAL_VENTA') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CVEN_CANAL_VENTA VARCHAR(8) NULL;          -- TIP_VALOR 'CANAL_VENTA'
IF COL_LENGTH('dbo.TMKK_VENTA', 'CVEN_ESTADO_VENTA') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CVEN_ESTADO_VENTA VARCHAR(8) NOT NULL
        CONSTRAINT DF_TMKK_VENTA_ESTADO_VENTA DEFAULT '3';                    -- PENDIENTE
IF COL_LENGTH('dbo.TMKK_VENTA', 'SVEN_CELULAR') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD SVEN_CELULAR VARCHAR(20) NULL;             -- celular a migrar / portar
IF COL_LENGTH('dbo.TMKK_VENTA', 'SVEN_CELULAR_CONTACTO') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD SVEN_CELULAR_CONTACTO VARCHAR(20) NULL;
IF COL_LENGTH('dbo.TMKK_VENTA', 'SVEN_CORREO') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD SVEN_CORREO VARCHAR(100) NULL;
IF COL_LENGTH('dbo.TMKK_VENTA', 'NVEN_VALOR') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD NVEN_VALOR DECIMAL(14, 2) NULL;            -- precio del plan al momento de la venta
IF COL_LENGTH('dbo.TMKK_VENTA', 'DVEN_FEC_ACTIVACION') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD DVEN_FEC_ACTIVACION DATETIME NULL;
IF COL_LENGTH('dbo.TMKK_VENTA', 'CVEN_MOTIVO_CAIDA') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CVEN_MOTIVO_CAIDA VARCHAR(8) NULL;         -- TIP_VALOR 'TIP_MOTIVO_CAIDA'
IF COL_LENGTH('dbo.TMKK_VENTA', 'SVEN_OBSERVACION') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD SVEN_OBSERVACION VARCHAR(500) NULL;
IF COL_LENGTH('dbo.TMKK_VENTA', 'CUBI_COD_UBIGEO') IS NULL
    ALTER TABLE dbo.TMKK_VENTA ADD CUBI_COD_UBIGEO CHAR(6) NULL
        CONSTRAINT FK_TMKK_VENTA_UBIGEO REFERENCES dbo.TMKK_UBIGEO (CUBI_COD_UBIGEO);

IF COL_LENGTH('dbo.TMKK_VENTA_PORTABILIDAD', 'COPE_ID_OPERADOR') IS NULL
    ALTER TABLE dbo.TMKK_VENTA_PORTABILIDAD ADD COPE_ID_OPERADOR SMALLINT NULL
        CONSTRAINT FK_TMKK_VPORTA_OPERADOR REFERENCES dbo.TMKK_OPERADOR (COPE_ID_OPERADOR);
IF COL_LENGTH('dbo.TMKK_VENTA_POST_POST', 'CPLN_ID_PLAN_ANTERIOR') IS NULL
    ALTER TABLE dbo.TMKK_VENTA_POST_POST ADD CPLN_ID_PLAN_ANTERIOR INT NULL
        CONSTRAINT FK_TMKK_VPOSTPOST_PLAN REFERENCES dbo.TMKK_PLAN (CPLN_ID_CODIGO);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_VENTA_FECHA')
    CREATE INDEX IX_TMKK_VENTA_FECHA ON dbo.TMKK_VENTA (DVEN_FECHA_REGISTRO)
        INCLUDE (SVEN_TIPO_VENTA, CVEN_ESTADO_VENTA, CVEN_CANAL_VENTA, CPEL_ID_ASESOR, CCAM_ID_CAMPANIA, CPLN_ID_CODIGO, FVEN_ESTADO);
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_VENTA_CELULAR')
    CREATE INDEX IX_TMKK_VENTA_CELULAR ON dbo.TMKK_VENTA (SVEN_CELULAR);
GO

IF OBJECT_ID('dbo.TMKK_VENTA_BIOMETRIA') IS NULL
CREATE TABLE dbo.TMKK_VENTA_BIOMETRIA (
    CVEN_ID_VENTA           INT NOT NULL CONSTRAINT PK_TMKK_VENTA_BIOMETRIA PRIMARY KEY,
    DVBI_FEC_NACIMIENTO     DATE NULL,
    SVBI_LUGAR_NACIMIENTO   VARCHAR(100) NULL,
    DVBI_FEC_EMISION_DOC    DATE NULL,
    SVBI_NOMBRE_PADRE       VARCHAR(150) NULL,
    SVBI_NOMBRE_MADRE       VARCHAR(150) NULL,
    AUD_INS_FEC             DATETIME NULL,
    AUD_INS_USER            VARCHAR(16) NULL,
    AUD_UPD_FEC             DATETIME NULL,
    AUD_UPD_USER            VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_VBIO_VENTA FOREIGN KEY (CVEN_ID_VENTA) REFERENCES dbo.TMKK_VENTA (CVEN_ID_VENTA)
);
GO

IF OBJECT_ID('dbo.TMKK_VENTA_ESTADO_HIST') IS NULL
CREATE TABLE dbo.TMKK_VENTA_ESTADO_HIST (
    CVEH_ID_HISTORIAL       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_VENTA_ESTADO_HIST PRIMARY KEY,
    CVEN_ID_VENTA           INT NOT NULL,
    CVEH_ESTADO_ANTERIOR    VARCHAR(8) NULL,
    CVEH_ESTADO_NUEVO       VARCHAR(8) NOT NULL,
    CVEH_MOTIVO_CAIDA       VARCHAR(8) NULL,
    SVEH_OBSERVACION        VARCHAR(500) NULL,
    AUD_INS_FEC             DATETIME NOT NULL CONSTRAINT DF_TMKK_VEH_FEC DEFAULT GETDATE(),
    AUD_INS_USER            VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_VEH_VENTA FOREIGN KEY (CVEN_ID_VENTA) REFERENCES dbo.TMKK_VENTA (CVEN_ID_VENTA)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_VEH_VENTA')
    CREATE INDEX IX_TMKK_VEH_VENTA ON dbo.TMKK_VENTA_ESTADO_HIST (CVEN_ID_VENTA);
GO

IF OBJECT_ID('dbo.TMKK_META_VENTA') IS NULL
CREATE TABLE dbo.TMKK_META_VENTA (
    CMET_ID_META        INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_META_VENTA PRIMARY KEY,
    NMET_PERIODO        INT NOT NULL,           -- AAAAMM
    CCAM_ID_CAMPANIA    INT NULL,               -- NULL = meta general
    NMET_CANTIDAD       INT NOT NULL,
    FMET_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_META_ESTADO DEFAULT 'V',
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_META_CAMPANIA FOREIGN KEY (CCAM_ID_CAMPANIA) REFERENCES dbo.TMKK_CAMPANIA (CCAM_ID_CAMPANIA),
    CONSTRAINT CK_TMKK_META_PERIODO CHECK (NMET_PERIODO BETWEEN 200001 AND 299912 AND NMET_PERIODO % 100 BETWEEN 1 AND 12)
);
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_META_PERIODO')
    CREATE UNIQUE INDEX UX_TMKK_META_PERIODO ON dbo.TMKK_META_VENTA (NMET_PERIODO, CCAM_ID_CAMPANIA) WHERE FMET_ESTADO = 'V';
GO

-- ==============================================================================
-- 2. STORED PROCEDURES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Registro de Venta. Valida los campos obligatorios según el tipo de venta
-- (mismas reglas que registro-de-ventas.vue), crea/actualiza al cliente por
-- documento y guarda la venta con su detalle en una sola transacción.
-- Con @i_CVEN_ID_VENTA se edita una venta existente (lo usa PRMKK_UPD_BOF_VENTA).
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_VENTA
    @i_TIPO_VENTA           INT,
    -- Datos del cliente
    @i_CTDI_ID_DOCUMENTO    TINYINT,                -- 1 DNI, 3 CE, 6 PASAPORTE
    @i_NRO_DOCUMENTO        VARCHAR(16),
    @i_NOMBRES_APELLIDOS    VARCHAR(200),
    @i_CORREO               VARCHAR(100),
    @i_CELULAR_CONTACTO     VARCHAR(20),
    -- Línea / producto
    @i_CELULAR_MIGRAR       VARCHAR(20)  = NULL,
    @i_COPE_ID_OPERADOR     SMALLINT     = NULL,     -- portabilidad
    @i_MODALIDAD            VARCHAR(50)  = NULL,     -- portabilidad: POSTPAGO / PREPAGO
    @i_CPLN_ID_PLAN_ANTERIOR INT         = NULL,     -- post a post
    @i_CPLN_ID_PLAN         INT,
    -- Validación / biometría (pre a post y post a post)
    @i_FEC_NACIMIENTO       DATE         = NULL,
    @i_LUGAR_NACIMIENTO     VARCHAR(100) = NULL,
    @i_FEC_EMISION_DOC      DATE         = NULL,
    @i_NOMBRE_PADRE         VARCHAR(150) = NULL,
    @i_NOMBRE_MADRE         VARCHAR(150) = NULL,
    -- Dirección de entrega
    @i_CUBI_COD_UBIGEO      CHAR(6),
    @i_DIRECCION_EXACTA     VARCHAR(250),
    @i_REFERENCIA           VARCHAR(250) = NULL,
    @i_NUM_ORDEN            VARCHAR(50)  = NULL,
    -- Asignación
    @i_CPEL_ID_ASESOR       INT          = NULL,     -- si no se envía, se toma del usuario
    @i_CUSU_ID_USUARIO      INT          = NULL,
    @i_CCAM_ID_CAMPANIA     INT          = NULL,     -- si no se envía, la del asesor
    @i_CANAL_VENTA          VARCHAR(8)   = NULL,     -- TIP_VALOR 'CANAL_VENTA'
    @i_CLLM_ID_LLAMADA      INT          = NULL,
    @i_AUD_USER             VARCHAR(16),
    @i_CVEN_ID_VENTA        INT          = NULL,     -- solo para edición
    @o_CVEN_ID_VENTA        INT OUTPUT,
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @esPorta BIT = CASE WHEN @i_TIPO_VENTA = 2 THEN 1 ELSE 0 END,
                @esPostPost BIT = CASE WHEN @i_TIPO_VENTA = 3 THEN 1 ELSE 0 END,
                @requiereCelular BIT = CASE WHEN @i_TIPO_VENTA IN (1, 2, 3) THEN 1 ELSE 0 END,
                @requiereBiometria BIT = CASE WHEN @i_TIPO_VENTA IN (1, 3) THEN 1 ELSE 0 END,
                @persona INT, @asesor INT = @i_CPEL_ID_ASESOR, @campania INT = @i_CCAM_ID_CAMPANIA,
                @valor DECIMAL(14, 2), @ubigeoTexto VARCHAR(150), @operador VARCHAR(50), @planAnterior VARCHAR(100),
                @tipPersona CHAR(1), @error VARCHAR(500) = NULL;

        SET @o_CVEN_ID_VENTA = @i_CVEN_ID_VENTA;

        -- ---------------- Validaciones ----------------
        IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR WHERE CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND CTPV_TIP_VALOR = CAST(@i_TIPO_VENTA AS VARCHAR(8)) AND FTPV_ESTADO = 'V')
            SET @error = 'Tipo de venta no válido';
        ELSE IF NULLIF(LTRIM(@i_NRO_DOCUMENTO), '') IS NULL OR NULLIF(LTRIM(@i_NOMBRES_APELLIDOS), '') IS NULL
             OR NULLIF(LTRIM(@i_CORREO), '') IS NULL OR NULLIF(LTRIM(@i_CELULAR_CONTACTO), '') IS NULL
            SET @error = 'Complete los datos del cliente (documento, nombres, correo y celular de contacto)';
        ELSE IF @requiereCelular = 1 AND NULLIF(LTRIM(@i_CELULAR_MIGRAR), '') IS NULL
            SET @error = 'Ingrese el celular a migrar / portar';
        ELSE IF @esPorta = 1 AND (@i_COPE_ID_OPERADOR IS NULL OR NULLIF(@i_MODALIDAD, '') IS NULL)
            SET @error = 'Para portabilidad ingrese operador de procedencia y modalidad';
        ELSE IF @esPostPost = 1 AND @i_CPLN_ID_PLAN_ANTERIOR IS NULL
            SET @error = 'Para POST A POST ingrese el plan anterior';
        ELSE IF @requiereBiometria = 1 AND (@i_FEC_NACIMIENTO IS NULL OR NULLIF(@i_LUGAR_NACIMIENTO, '') IS NULL OR @i_FEC_EMISION_DOC IS NULL
                                            OR NULLIF(@i_NOMBRE_PADRE, '') IS NULL OR NULLIF(@i_NOMBRE_MADRE, '') IS NULL)
            SET @error = 'Complete los datos de validación / biometría';
        ELSE IF NULLIF(@i_CUBI_COD_UBIGEO, '') IS NULL OR NULLIF(LTRIM(@i_DIRECCION_EXACTA), '') IS NULL
            SET @error = 'Complete el ubigeo y la dirección de entrega';
        ELSE IF @i_CVEN_ID_VENTA IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_VENTA WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA AND FVEN_ESTADO = 'V')
            SET @error = 'Venta no encontrada';
        ELSE IF NULLIF(@i_NUM_ORDEN, '') IS NOT NULL AND EXISTS (
                SELECT 1 FROM dbo.TMKK_VENTA WHERE SNUM_ORDEN = @i_NUM_ORDEN AND FVEN_ESTADO = 'V'
                  AND CVEN_ID_VENTA <> ISNULL(@i_CVEN_ID_VENTA, 0))
            SET @error = 'El número de orden ' + @i_NUM_ORDEN + ' ya está registrado';

        IF @error IS NULL
        BEGIN
            SELECT @valor = NPLN_VALOR_PLAN FROM dbo.TMKK_PLAN WHERE CPLN_ID_CODIGO = @i_CPLN_ID_PLAN AND FPLN_ESTADO = 'V';
            IF @valor IS NULL SET @error = 'Plan no válido';
        END

        IF @error IS NULL
        BEGIN
            SELECT @ubigeoTexto = SUBI_DEPARTAMENTO + ' - ' + SUBI_PROVINCIA + ' - ' + SUBI_DISTRITO
            FROM dbo.TMKK_UBIGEO WHERE CUBI_COD_UBIGEO = @i_CUBI_COD_UBIGEO;
            IF @ubigeoTexto IS NULL SET @error = 'Ubigeo no válido';
        END

        IF @error IS NULL
        BEGIN
            SELECT @tipPersona = ISNULL(FTDI_TIP_PERSONA, '1') FROM dbo.TMKK_TIP_DOC_IDENTIDAD
            WHERE CTDI_ID_DOCUMENTO = @i_CTDI_ID_DOCUMENTO AND FTDI_ESTADO = 'V';
            IF @tipPersona IS NULL SET @error = 'Tipo de documento no válido';
        END

        IF @error IS NULL AND @esPorta = 1
        BEGIN
            SELECT @operador = SOPE_NOMBRE FROM dbo.TMKK_OPERADOR WHERE COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR;
            IF @operador IS NULL SET @error = 'Operador no válido';
        END

        IF @error IS NULL AND @esPostPost = 1
        BEGIN
            SELECT @planAnterior = SPLN_NOMBRE FROM dbo.TMKK_PLAN WHERE CPLN_ID_CODIGO = @i_CPLN_ID_PLAN_ANTERIOR;
            IF @planAnterior IS NULL SET @error = 'Plan anterior no válido';
        END

        IF @error IS NULL AND NULLIF(@i_CANAL_VENTA, '') IS NOT NULL
           AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR WHERE CTPV_COD_TIP_VALOR = 'CANAL_VENTA' AND CTPV_TIP_VALOR = @i_CANAL_VENTA)
            SET @error = 'Canal de venta no válido';

        IF @error IS NOT NULL
        BEGIN
            SET @o_resultMessage = '0|' + @error;
            RETURN;
        END

        -- Asesor y campaña
        IF @asesor IS NULL AND @i_CUSU_ID_USUARIO IS NOT NULL
            SELECT @asesor = CPEL_ID_PERSONAL FROM dbo.TMKK_PERSONAL WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;
        IF @campania IS NULL
            SELECT @campania = CCAM_ID_CAMPANIA FROM dbo.TMKK_PERSONAL WHERE CPEL_ID_PERSONAL = @asesor;

        BEGIN TRANSACTION;

        -- ---------------- Cliente ----------------
        SELECT TOP (1) @persona = CPER_ID_PERSONA FROM dbo.TPLS_PERSONA
        WHERE FPER_TIP_DOC_IDENTIDAD = @i_CTDI_ID_DOCUMENTO AND SPER_NRO_DOC_IDENTIDAD = @i_NRO_DOCUMENTO;

        IF @persona IS NULL
        BEGIN
            INSERT INTO dbo.TPLS_PERSONA (FPER_TIP_PERSONA, FPER_TIP_DOC_IDENTIDAD, SPER_NRO_DOC_IDENTIDAD, SPER_NOM_COMPLETO,
                                          SPER_FEC_NACIMIENTO, SPER_CELULAR, SPER_COR_PERSONAL, SPER_DIRECCION, CUBI_COD_UBIGEO,
                                          FPER_ESTADO, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@tipPersona, @i_CTDI_ID_DOCUMENTO, @i_NRO_DOCUMENTO, UPPER(LTRIM(RTRIM(@i_NOMBRES_APELLIDOS))),
                    @i_FEC_NACIMIENTO, @i_CELULAR_CONTACTO, @i_CORREO, @i_DIRECCION_EXACTA, @i_CUBI_COD_UBIGEO,
                    'V', GETDATE(), @i_AUD_USER);
            SET @persona = SCOPE_IDENTITY();
        END
        ELSE
            UPDATE dbo.TPLS_PERSONA
            SET SPER_NOM_COMPLETO   = UPPER(LTRIM(RTRIM(@i_NOMBRES_APELLIDOS))),
                SPER_FEC_NACIMIENTO = COALESCE(@i_FEC_NACIMIENTO, SPER_FEC_NACIMIENTO),
                SPER_CELULAR        = @i_CELULAR_CONTACTO,
                SPER_COR_PERSONAL   = @i_CORREO,
                SPER_DIRECCION      = @i_DIRECCION_EXACTA,
                CUBI_COD_UBIGEO     = @i_CUBI_COD_UBIGEO,
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CPER_ID_PERSONA = @persona;

        -- ---------------- Venta ----------------
        IF @i_CVEN_ID_VENTA IS NULL
        BEGIN
            INSERT INTO dbo.TMKK_VENTA (CVEN_ID_LLAMADA, CVEN_ID_CLIENTE, CPLN_ID_CODIGO, DVEN_FECHA_REGISTRO, SVEN_TIPO_VENTA,
                                        SUBIGEO, CUBI_COD_UBIGEO, SDIRECCION_EXACTA, SREFERENCIA, SNUM_ORDEN, FVEN_ESTADO,
                                        CPEL_ID_ASESOR, CCAM_ID_CAMPANIA, CVEN_CANAL_VENTA, CVEN_ESTADO_VENTA, SVEN_CELULAR,
                                        SVEN_CELULAR_CONTACTO, SVEN_CORREO, NVEN_VALOR, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@i_CLLM_ID_LLAMADA, @persona, @i_CPLN_ID_PLAN, GETDATE(), @i_TIPO_VENTA,
                    @ubigeoTexto, @i_CUBI_COD_UBIGEO, @i_DIRECCION_EXACTA, NULLIF(@i_REFERENCIA, ''), NULLIF(@i_NUM_ORDEN, ''), 'V',
                    @asesor, @campania, NULLIF(@i_CANAL_VENTA, ''), '3', NULLIF(@i_CELULAR_MIGRAR, ''),
                    @i_CELULAR_CONTACTO, @i_CORREO, @valor, GETDATE(), @i_AUD_USER);

            SET @o_CVEN_ID_VENTA = SCOPE_IDENTITY();

            INSERT INTO dbo.TMKK_VENTA_ESTADO_HIST (CVEN_ID_VENTA, CVEH_ESTADO_ANTERIOR, CVEH_ESTADO_NUEVO, SVEH_OBSERVACION, AUD_INS_USER)
            VALUES (@o_CVEN_ID_VENTA, NULL, '3', 'Registro de venta', @i_AUD_USER);
        END
        ELSE
            UPDATE dbo.TMKK_VENTA
            SET CVEN_ID_CLIENTE = @persona, CPLN_ID_CODIGO = @i_CPLN_ID_PLAN, SVEN_TIPO_VENTA = @i_TIPO_VENTA,
                SUBIGEO = @ubigeoTexto, CUBI_COD_UBIGEO = @i_CUBI_COD_UBIGEO, SDIRECCION_EXACTA = @i_DIRECCION_EXACTA,
                SREFERENCIA = NULLIF(@i_REFERENCIA, ''), SNUM_ORDEN = NULLIF(@i_NUM_ORDEN, ''),
                CPEL_ID_ASESOR = COALESCE(@asesor, CPEL_ID_ASESOR), CCAM_ID_CAMPANIA = COALESCE(@campania, CCAM_ID_CAMPANIA),
                CVEN_CANAL_VENTA = NULLIF(@i_CANAL_VENTA, ''), SVEN_CELULAR = NULLIF(@i_CELULAR_MIGRAR, ''),
                SVEN_CELULAR_CONTACTO = @i_CELULAR_CONTACTO, SVEN_CORREO = @i_CORREO, NVEN_VALOR = @valor,
                CVEN_ID_LLAMADA = COALESCE(@i_CLLM_ID_LLAMADA, CVEN_ID_LLAMADA),
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA;

        -- ---------------- Detalle según tipo ----------------
        DELETE FROM dbo.TMKK_VENTA_PORTABILIDAD WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA AND @esPorta = 0;
        DELETE FROM dbo.TMKK_VENTA_POST_POST    WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA AND @esPostPost = 0;
        DELETE FROM dbo.TMKK_VENTA_BIOMETRIA    WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA AND @requiereBiometria = 0;

        IF @esPorta = 1
        BEGIN
            UPDATE dbo.TMKK_VENTA_PORTABILIDAD
            SET SCELULAR_MIGRAR = @i_CELULAR_MIGRAR, COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR, SOPERADOR_PROCEDENCIA = @operador,
                SMODALIDAD = @i_MODALIDAD, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.TMKK_VENTA_PORTABILIDAD (CVEN_ID_VENTA, SCELULAR_MIGRAR, SOPERADOR_PROCEDENCIA, SMODALIDAD, COPE_ID_OPERADOR, AUD_INS_FEC, AUD_INS_USER)
                VALUES (@o_CVEN_ID_VENTA, @i_CELULAR_MIGRAR, @operador, @i_MODALIDAD, @i_COPE_ID_OPERADOR, GETDATE(), @i_AUD_USER);
        END

        IF @esPostPost = 1
        BEGIN
            UPDATE dbo.TMKK_VENTA_POST_POST
            SET SCELULAR_MIGRAR = @i_CELULAR_MIGRAR, CPLN_ID_PLAN_ANTERIOR = @i_CPLN_ID_PLAN_ANTERIOR, SPLAN_ANTERIOR = @planAnterior,
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.TMKK_VENTA_POST_POST (CVEN_ID_VENTA, SCELULAR_MIGRAR, SPLAN_ANTERIOR, CPLN_ID_PLAN_ANTERIOR, AUD_INS_FEC, AUD_INS_USER)
                VALUES (@o_CVEN_ID_VENTA, @i_CELULAR_MIGRAR, @planAnterior, @i_CPLN_ID_PLAN_ANTERIOR, GETDATE(), @i_AUD_USER);
        END

        IF @requiereBiometria = 1
        BEGIN
            UPDATE dbo.TMKK_VENTA_BIOMETRIA
            SET DVBI_FEC_NACIMIENTO = @i_FEC_NACIMIENTO, SVBI_LUGAR_NACIMIENTO = @i_LUGAR_NACIMIENTO,
                DVBI_FEC_EMISION_DOC = @i_FEC_EMISION_DOC, SVBI_NOMBRE_PADRE = @i_NOMBRE_PADRE, SVBI_NOMBRE_MADRE = @i_NOMBRE_MADRE,
                AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
            WHERE CVEN_ID_VENTA = @o_CVEN_ID_VENTA;

            IF @@ROWCOUNT = 0
                INSERT INTO dbo.TMKK_VENTA_BIOMETRIA (CVEN_ID_VENTA, DVBI_FEC_NACIMIENTO, SVBI_LUGAR_NACIMIENTO, DVBI_FEC_EMISION_DOC,
                                                      SVBI_NOMBRE_PADRE, SVBI_NOMBRE_MADRE, AUD_INS_FEC, AUD_INS_USER)
                VALUES (@o_CVEN_ID_VENTA, @i_FEC_NACIMIENTO, @i_LUGAR_NACIMIENTO, @i_FEC_EMISION_DOC,
                        @i_NOMBRE_PADRE, @i_NOMBRE_MADRE, GETDATE(), @i_AUD_USER);
        END

        COMMIT TRANSACTION;
        SET @o_resultMessage = CASE WHEN @i_CVEN_ID_VENTA IS NULL THEN '1|Venta registrada correctamente' ELSE '1|Venta actualizada correctamente' END;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Editar Venta: mismos parámetros que el registro + id de la venta.
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_VENTA
    @i_CVEN_ID_VENTA        INT,
    @i_TIPO_VENTA           INT,
    @i_CTDI_ID_DOCUMENTO    TINYINT,
    @i_NRO_DOCUMENTO        VARCHAR(16),
    @i_NOMBRES_APELLIDOS    VARCHAR(200),
    @i_CORREO               VARCHAR(100),
    @i_CELULAR_CONTACTO     VARCHAR(20),
    @i_CELULAR_MIGRAR       VARCHAR(20)  = NULL,
    @i_COPE_ID_OPERADOR     SMALLINT     = NULL,
    @i_MODALIDAD            VARCHAR(50)  = NULL,
    @i_CPLN_ID_PLAN_ANTERIOR INT         = NULL,
    @i_CPLN_ID_PLAN         INT,
    @i_FEC_NACIMIENTO       DATE         = NULL,
    @i_LUGAR_NACIMIENTO     VARCHAR(100) = NULL,
    @i_FEC_EMISION_DOC      DATE         = NULL,
    @i_NOMBRE_PADRE         VARCHAR(150) = NULL,
    @i_NOMBRE_MADRE         VARCHAR(150) = NULL,
    @i_CUBI_COD_UBIGEO      CHAR(6),
    @i_DIRECCION_EXACTA     VARCHAR(250),
    @i_REFERENCIA           VARCHAR(250) = NULL,
    @i_NUM_ORDEN            VARCHAR(50)  = NULL,
    @i_CPEL_ID_ASESOR       INT          = NULL,
    @i_CCAM_ID_CAMPANIA     INT          = NULL,
    @i_CANAL_VENTA          VARCHAR(8)   = NULL,
    @i_AUD_USER             VARCHAR(16),
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id INT;

    EXEC dbo.PRMKK_INS_BOF_VENTA
        @i_TIPO_VENTA = @i_TIPO_VENTA, @i_CTDI_ID_DOCUMENTO = @i_CTDI_ID_DOCUMENTO, @i_NRO_DOCUMENTO = @i_NRO_DOCUMENTO,
        @i_NOMBRES_APELLIDOS = @i_NOMBRES_APELLIDOS, @i_CORREO = @i_CORREO, @i_CELULAR_CONTACTO = @i_CELULAR_CONTACTO,
        @i_CELULAR_MIGRAR = @i_CELULAR_MIGRAR, @i_COPE_ID_OPERADOR = @i_COPE_ID_OPERADOR, @i_MODALIDAD = @i_MODALIDAD,
        @i_CPLN_ID_PLAN_ANTERIOR = @i_CPLN_ID_PLAN_ANTERIOR, @i_CPLN_ID_PLAN = @i_CPLN_ID_PLAN,
        @i_FEC_NACIMIENTO = @i_FEC_NACIMIENTO, @i_LUGAR_NACIMIENTO = @i_LUGAR_NACIMIENTO, @i_FEC_EMISION_DOC = @i_FEC_EMISION_DOC,
        @i_NOMBRE_PADRE = @i_NOMBRE_PADRE, @i_NOMBRE_MADRE = @i_NOMBRE_MADRE,
        @i_CUBI_COD_UBIGEO = @i_CUBI_COD_UBIGEO, @i_DIRECCION_EXACTA = @i_DIRECCION_EXACTA, @i_REFERENCIA = @i_REFERENCIA,
        @i_NUM_ORDEN = @i_NUM_ORDEN, @i_CPEL_ID_ASESOR = @i_CPEL_ID_ASESOR, @i_CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA,
        @i_CANAL_VENTA = @i_CANAL_VENTA, @i_AUD_USER = @i_AUD_USER, @i_CVEN_ID_VENTA = @i_CVEN_ID_VENTA,
        @o_CVEN_ID_VENTA = @id OUTPUT, @o_resultMessage = @o_resultMessage OUTPUT;
END
GO

-- ------------------------------------------------------------------------------
-- Lista de Ventas (paginada). Las columnas siguen los headers de lista-de-ventas.vue.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_VENTA
    @i_FEC_INICIO       DATE,
    @i_FEC_FIN          DATE,
    @i_CANAL_VENTA      VARCHAR(8)   = NULL,
    @i_TIPO_VENTA       INT          = NULL,
    @i_ESTADO_VENTA     VARCHAR(8)   = NULL,
    @i_CPEL_ID_ASESOR   INT          = NULL,     -- un ASESOR solo ve sus ventas
    @i_CCAM_ID_CAMPANIA INT          = NULL,
    @i_TEXTO            VARCHAR(100) = NULL,     -- celular, documento, cliente, asesor u orden
    @i_PAGINA           INT          = 1,
    @i_TAMANIO_PAGINA   INT          = 10        -- -1 = todos
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.CVEN_ID_VENTA,
        v.DVEN_FECHA_REGISTRO                           AS DFEC_VENTA,
        v.CVEN_ESTADO_VENTA,
        ev.STPV_DES_TIP_VALOR_1                         AS SESTADO_VENTA,
        ev.STPV_DES_TIP_VALOR_2                         AS SESTADO_COLOR,
        v.SVEN_CELULAR                                  AS SCEL_MIGRACION,
        v.CPEL_ID_ASESOR,
        COALESCE(pa.SPER_NOM_COMPLETO, NULLIF(LTRIM(CONCAT(pa.SPER_APE_PATERNO, ' ', pa.SPER_APE_MATERNO, ' ', pa.SPER_NOMBRE)), '')) AS SNOMBRE_VENDEDOR,
        v.DVEN_FEC_ACTIVACION                           AS DFEC_ACTIVACION,
        c.SPER_NRO_DOC_IDENTIDAD                        AS SNUMERO_DOCUMENTO,
        COALESCE(c.SPER_NOM_COMPLETO, c.SPER_RAZ_SOCIAL, NULLIF(LTRIM(CONCAT(c.SPER_NOMBRE, ' ', c.SPER_APE_PATERNO, ' ', c.SPER_APE_MATERNO)), '')) AS SNOMBRE_CLIENTE,
        pl.SPLN_NOMBRE                                  AS SPLAN,
        v.NVEN_VALOR,
        v.SVEN_TIPO_VENTA                               AS NTIPO_VENTA,
        tv.STPV_DES_TIP_VALOR_1                         AS STIPO_VENTA,
        v.CVEN_CANAL_VENTA,
        cv.STPV_DES_TIP_VALOR_1                         AS SCANAL_VENTA,
        cam.SCAM_NOMBRE                                 AS SCAMPANIA,
        v.SNUM_ORDEN,
        COUNT(*) OVER ()                                AS NTOTAL_REGISTROS
    FROM dbo.TMKK_VENTA v
    LEFT JOIN dbo.TPLS_PERSONA c ON c.CPER_ID_PERSONA = v.CVEN_ID_CLIENTE
    LEFT JOIN dbo.TMKK_PERSONAL ase ON ase.CPEL_ID_PERSONAL = v.CPEL_ID_ASESOR
    LEFT JOIN dbo.TPLS_PERSONA pa ON pa.CPER_ID_PERSONA = ase.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO
    LEFT JOIN dbo.TMKK_CAMPANIA cam ON cam.CCAM_ID_CAMPANIA = v.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_TIP_VALOR ev ON ev.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND ev.CTPV_TIP_VALOR = v.CVEN_ESTADO_VENTA
    LEFT JOIN dbo.TMKK_TIP_VALOR tv ON tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.CTPV_TIP_VALOR = CAST(v.SVEN_TIPO_VENTA AS VARCHAR(8))
    LEFT JOIN dbo.TMKK_TIP_VALOR cv ON cv.CTPV_COD_TIP_VALOR = 'CANAL_VENTA' AND cv.CTPV_TIP_VALOR = v.CVEN_CANAL_VENTA
    WHERE v.FVEN_ESTADO = 'V'
      AND v.DVEN_FECHA_REGISTRO >= @i_FEC_INICIO AND v.DVEN_FECHA_REGISTRO < DATEADD(DAY, 1, @i_FEC_FIN)
      AND (NULLIF(@i_CANAL_VENTA, '') IS NULL OR v.CVEN_CANAL_VENTA = @i_CANAL_VENTA)
      AND (@i_TIPO_VENTA IS NULL OR v.SVEN_TIPO_VENTA = @i_TIPO_VENTA)
      AND (NULLIF(@i_ESTADO_VENTA, '') IS NULL OR v.CVEN_ESTADO_VENTA = @i_ESTADO_VENTA)
      AND (@i_CPEL_ID_ASESOR IS NULL OR v.CPEL_ID_ASESOR = @i_CPEL_ID_ASESOR)
      AND (@i_CCAM_ID_CAMPANIA IS NULL OR v.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
      AND (NULLIF(@i_TEXTO, '') IS NULL
           OR v.SVEN_CELULAR LIKE '%' + @i_TEXTO + '%'
           OR v.SNUM_ORDEN LIKE '%' + @i_TEXTO + '%'
           OR c.SPER_NRO_DOC_IDENTIDAD LIKE @i_TEXTO + '%'
           OR c.SPER_NOM_COMPLETO LIKE '%' + @i_TEXTO + '%'
           OR pa.SPER_NOM_COMPLETO LIKE '%' + @i_TEXTO + '%'
           OR pl.SPLN_NOMBRE LIKE '%' + @i_TEXTO + '%')
    ORDER BY v.DVEN_FECHA_REGISTRO DESC
    OFFSET CASE WHEN @i_TAMANIO_PAGINA = -1 THEN 0 ELSE (ISNULL(@i_PAGINA, 1) - 1) * @i_TAMANIO_PAGINA END ROWS
    FETCH NEXT CASE WHEN @i_TAMANIO_PAGINA = -1 THEN 2147483647 ELSE @i_TAMANIO_PAGINA END ROWS ONLY;
END
GO

-- Tarjetas superiores de Lista de Ventas (Total + una por tipo). Mismos filtros
-- que la lista, salvo el tipo (las tarjetas son las que filtran por tipo).
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_VENTA_RESUMEN_TIPO
    @i_FEC_INICIO       DATE,
    @i_FEC_FIN          DATE,
    @i_CANAL_VENTA      VARCHAR(8) = NULL,
    @i_ESTADO_VENTA     VARCHAR(8) = NULL,
    @i_CPEL_ID_ASESOR   INT        = NULL,
    @i_CCAM_ID_CAMPANIA INT        = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT CAST(tv.CTPV_TIP_VALOR AS INT) AS NTIPO_VENTA,
           tv.STPV_DES_TIP_VALOR_1 AS STIPO_VENTA,
           COUNT(v.CVEN_ID_VENTA) AS NCANTIDAD,
           SUM(COUNT(v.CVEN_ID_VENTA)) OVER () AS NTOTAL
    FROM dbo.TMKK_TIP_VALOR tv
    LEFT JOIN dbo.TMKK_VENTA v
      ON v.SVEN_TIPO_VENTA = CAST(tv.CTPV_TIP_VALOR AS INT)
     AND v.FVEN_ESTADO = 'V'
     AND v.DVEN_FECHA_REGISTRO >= @i_FEC_INICIO AND v.DVEN_FECHA_REGISTRO < DATEADD(DAY, 1, @i_FEC_FIN)
     AND (NULLIF(@i_CANAL_VENTA, '') IS NULL OR v.CVEN_CANAL_VENTA = @i_CANAL_VENTA)
     AND (NULLIF(@i_ESTADO_VENTA, '') IS NULL OR v.CVEN_ESTADO_VENTA = @i_ESTADO_VENTA)
     AND (@i_CPEL_ID_ASESOR IS NULL OR v.CPEL_ID_ASESOR = @i_CPEL_ID_ASESOR)
     AND (@i_CCAM_ID_CAMPANIA IS NULL OR v.CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA)
    WHERE tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.FTPV_ESTADO = 'V'
    GROUP BY tv.CTPV_TIP_VALOR, tv.STPV_DES_TIP_VALOR_1
    ORDER BY tv.CTPV_TIP_VALOR;
END
GO

-- ------------------------------------------------------------------------------
-- Detalle (Ver / Gestión BO y Editar Venta). Dos result sets:
--   1. Venta completa con los mismos nombres de campo que el formulario
--   2. Historial de estados
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_VENTA_DETALLE
    @i_CVEN_ID_VENTA INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.CVEN_ID_VENTA, v.DVEN_FECHA_REGISTRO, v.SVEN_TIPO_VENTA AS NTIPO_VENTA, tv.STPV_DES_TIP_VALOR_1 AS STIPO_VENTA,
        v.CVEN_ESTADO_VENTA, ev.STPV_DES_TIP_VALOR_1 AS SESTADO_VENTA, ev.STPV_DES_TIP_VALOR_2 AS SESTADO_COLOR,
        v.DVEN_FEC_ACTIVACION, v.CVEN_MOTIVO_CAIDA, mc.STPV_DES_TIP_VALOR_1 AS SMOTIVO_CAIDA, v.SVEN_OBSERVACION,
        -- cliente
        c.CPER_ID_PERSONA, c.FPER_TIP_DOC_IDENTIDAD AS CTDI_ID_DOCUMENTO, td.STDI_ABREVIATURA AS STIPO_DOCUMENTO,
        c.SPER_NRO_DOC_IDENTIDAD AS SNRO_DOCUMENTO, c.SPER_NOM_COMPLETO AS SNOMBRES_APELLIDOS,
        v.SVEN_CORREO AS SCORREO, v.SVEN_CELULAR_CONTACTO AS SCELULAR_CONTACTO,
        -- línea / producto
        v.SVEN_CELULAR AS SCELULAR_MIGRAR, po.COPE_ID_OPERADOR, po.SOPERADOR_PROCEDENCIA, po.SMODALIDAD,
        pp.CPLN_ID_PLAN_ANTERIOR, pp.SPLAN_ANTERIOR,
        v.CPLN_ID_CODIGO AS CPLN_ID_PLAN, pl.SPLN_NOMBRE AS SPLAN, v.NVEN_VALOR,
        -- biometría
        b.DVBI_FEC_NACIMIENTO, b.SVBI_LUGAR_NACIMIENTO, b.DVBI_FEC_EMISION_DOC, b.SVBI_NOMBRE_PADRE, b.SVBI_NOMBRE_MADRE,
        -- dirección
        v.CUBI_COD_UBIGEO, v.SUBIGEO, v.SDIRECCION_EXACTA, v.SREFERENCIA, v.SNUM_ORDEN,
        -- asignación
        v.CPEL_ID_ASESOR, pa.SPER_NOM_COMPLETO AS SNOMBRE_VENDEDOR, v.CCAM_ID_CAMPANIA, cam.SCAM_NOMBRE AS SCAMPANIA,
        v.CVEN_CANAL_VENTA, cv.STPV_DES_TIP_VALOR_1 AS SCANAL_VENTA, v.CVEN_ID_LLAMADA,
        v.AUD_INS_USER, v.AUD_INS_FEC, v.AUD_UPD_USER, v.AUD_UPD_FEC
    FROM dbo.TMKK_VENTA v
    LEFT JOIN dbo.TPLS_PERSONA c ON c.CPER_ID_PERSONA = v.CVEN_ID_CLIENTE
    LEFT JOIN dbo.TMKK_TIP_DOC_IDENTIDAD td ON td.CTDI_ID_DOCUMENTO = c.FPER_TIP_DOC_IDENTIDAD
    LEFT JOIN dbo.TMKK_VENTA_PORTABILIDAD po ON po.CVEN_ID_VENTA = v.CVEN_ID_VENTA
    LEFT JOIN dbo.TMKK_VENTA_POST_POST pp ON pp.CVEN_ID_VENTA = v.CVEN_ID_VENTA
    LEFT JOIN dbo.TMKK_VENTA_BIOMETRIA b ON b.CVEN_ID_VENTA = v.CVEN_ID_VENTA
    LEFT JOIN dbo.TMKK_PLAN pl ON pl.CPLN_ID_CODIGO = v.CPLN_ID_CODIGO
    LEFT JOIN dbo.TMKK_PERSONAL ase ON ase.CPEL_ID_PERSONAL = v.CPEL_ID_ASESOR
    LEFT JOIN dbo.TPLS_PERSONA pa ON pa.CPER_ID_PERSONA = ase.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_CAMPANIA cam ON cam.CCAM_ID_CAMPANIA = v.CCAM_ID_CAMPANIA
    LEFT JOIN dbo.TMKK_TIP_VALOR tv ON tv.CTPV_COD_TIP_VALOR = 'TIPO_VENTA' AND tv.CTPV_TIP_VALOR = CAST(v.SVEN_TIPO_VENTA AS VARCHAR(8))
    LEFT JOIN dbo.TMKK_TIP_VALOR ev ON ev.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND ev.CTPV_TIP_VALOR = v.CVEN_ESTADO_VENTA
    LEFT JOIN dbo.TMKK_TIP_VALOR mc ON mc.CTPV_COD_TIP_VALOR = 'TIP_MOTIVO_CAIDA' AND mc.CTPV_TIP_VALOR = v.CVEN_MOTIVO_CAIDA
    LEFT JOIN dbo.TMKK_TIP_VALOR cv ON cv.CTPV_COD_TIP_VALOR = 'CANAL_VENTA' AND cv.CTPV_TIP_VALOR = v.CVEN_CANAL_VENTA
    WHERE v.CVEN_ID_VENTA = @i_CVEN_ID_VENTA;

    SELECT h.CVEH_ID_HISTORIAL, h.CVEH_ESTADO_ANTERIOR, ea.STPV_DES_TIP_VALOR_1 AS SESTADO_ANTERIOR,
           h.CVEH_ESTADO_NUEVO, en.STPV_DES_TIP_VALOR_1 AS SESTADO_NUEVO, en.STPV_DES_TIP_VALOR_2 AS SESTADO_COLOR,
           mc.STPV_DES_TIP_VALOR_1 AS SMOTIVO_CAIDA, h.SVEH_OBSERVACION, h.AUD_INS_FEC, h.AUD_INS_USER
    FROM dbo.TMKK_VENTA_ESTADO_HIST h
    LEFT JOIN dbo.TMKK_TIP_VALOR ea ON ea.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND ea.CTPV_TIP_VALOR = h.CVEH_ESTADO_ANTERIOR
    LEFT JOIN dbo.TMKK_TIP_VALOR en ON en.CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND en.CTPV_TIP_VALOR = h.CVEH_ESTADO_NUEVO
    LEFT JOIN dbo.TMKK_TIP_VALOR mc ON mc.CTPV_COD_TIP_VALOR = 'TIP_MOTIVO_CAIDA' AND mc.CTPV_TIP_VALOR = h.CVEH_MOTIVO_CAIDA
    WHERE h.CVEN_ID_VENTA = @i_CVEN_ID_VENTA
    ORDER BY h.AUD_INS_FEC, h.CVEH_ID_HISTORIAL;
END
GO

-- ------------------------------------------------------------------------------
-- Gestión BO: cambio de estado comercial con trazabilidad.
--   CAIDO    -> exige motivo de caída (TIP_MOTIVO_CAIDA)
--   ACTIVADO -> registra fecha de activación (la enviada o la actual)
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_VENTA_ESTADO
    @i_CVEN_ID_VENTA    INT,
    @i_ESTADO_VENTA     VARCHAR(8),
    @i_MOTIVO_CAIDA     VARCHAR(8)   = NULL,
    @i_OBSERVACION      VARCHAR(500) = NULL,
    @i_FEC_ACTIVACION   DATETIME     = NULL,
    @i_NUM_ORDEN        VARCHAR(50)  = NULL,
    @i_AUD_USER         VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @anterior VARCHAR(8), @descEstado VARCHAR(128);

        SELECT @anterior = CVEN_ESTADO_VENTA FROM dbo.TMKK_VENTA WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA AND FVEN_ESTADO = 'V';
        IF @anterior IS NULL
        BEGIN
            SET @o_resultMessage = '0|Venta no encontrada';
            RETURN;
        END

        SELECT @descEstado = STPV_DES_TIP_VALOR_1 FROM dbo.TMKK_TIP_VALOR
        WHERE CTPV_COD_TIP_VALOR = 'TIP_ESTADO_VENTA' AND CTPV_TIP_VALOR = @i_ESTADO_VENTA AND FTPV_ESTADO = 'V';
        IF @descEstado IS NULL
        BEGIN
            SET @o_resultMessage = '0|Estado de venta no válido';
            RETURN;
        END

        IF @descEstado = 'CAIDO' AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_TIP_VALOR
                                                 WHERE CTPV_COD_TIP_VALOR = 'TIP_MOTIVO_CAIDA' AND CTPV_TIP_VALOR = @i_MOTIVO_CAIDA AND FTPV_ESTADO = 'V')
        BEGIN
            SET @o_resultMessage = '0|Indique un motivo de caída válido';
            RETURN;
        END

        IF NULLIF(@i_NUM_ORDEN, '') IS NOT NULL AND EXISTS (SELECT 1 FROM dbo.TMKK_VENTA
                                                            WHERE SNUM_ORDEN = @i_NUM_ORDEN AND FVEN_ESTADO = 'V' AND CVEN_ID_VENTA <> @i_CVEN_ID_VENTA)
        BEGIN
            SET @o_resultMessage = '0|El número de orden ' + @i_NUM_ORDEN + ' ya está registrado';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_VENTA
        SET CVEN_ESTADO_VENTA   = @i_ESTADO_VENTA,
            CVEN_MOTIVO_CAIDA   = CASE WHEN @descEstado = 'CAIDO' THEN @i_MOTIVO_CAIDA ELSE NULL END,
            DVEN_FEC_ACTIVACION = CASE WHEN @descEstado = 'ACTIVADO' THEN COALESCE(@i_FEC_ACTIVACION, DVEN_FEC_ACTIVACION, GETDATE())
                                       ELSE DVEN_FEC_ACTIVACION END,
            SVEN_OBSERVACION    = COALESCE(NULLIF(@i_OBSERVACION, ''), SVEN_OBSERVACION),
            SNUM_ORDEN          = COALESCE(NULLIF(@i_NUM_ORDEN, ''), SNUM_ORDEN),
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA;

        INSERT INTO dbo.TMKK_VENTA_ESTADO_HIST (CVEN_ID_VENTA, CVEH_ESTADO_ANTERIOR, CVEH_ESTADO_NUEVO, CVEH_MOTIVO_CAIDA, SVEH_OBSERVACION, AUD_INS_USER)
        VALUES (@i_CVEN_ID_VENTA, @anterior, @i_ESTADO_VENTA,
                CASE WHEN @descEstado = 'CAIDO' THEN @i_MOTIVO_CAIDA END, NULLIF(@i_OBSERVACION, ''), @i_AUD_USER);

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Estado actualizado a ' + @descEstado;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Eliminar (anulación lógica del registro)
CREATE OR ALTER PROCEDURE dbo.PRMKK_DEL_BOF_VENTA
    @i_CVEN_ID_VENTA INT,
    @i_MOTIVO        VARCHAR(500) = NULL,
    @i_AUD_USER      VARCHAR(16),
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_VENTA
        SET FVEN_ESTADO = 'I', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA AND FVEN_ESTADO = 'V';

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @o_resultMessage = '0|Venta no encontrada';
            RETURN;
        END

        INSERT INTO dbo.TMKK_VENTA_ESTADO_HIST (CVEN_ID_VENTA, CVEH_ESTADO_ANTERIOR, CVEH_ESTADO_NUEVO, SVEH_OBSERVACION, AUD_INS_USER)
        SELECT CVEN_ID_VENTA, CVEN_ESTADO_VENTA, CVEN_ESTADO_VENTA, 'Venta eliminada' + ISNULL(': ' + NULLIF(@i_MOTIVO, ''), ''), @i_AUD_USER
        FROM dbo.TMKK_VENTA WHERE CVEN_ID_VENTA = @i_CVEN_ID_VENTA;

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Venta eliminada';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Metas de venta (tarjeta "Meta de ventas" del dashboard)
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_META_VENTA
    @i_PERIODO          INT,             -- AAAAMM
    @i_CCAM_ID_CAMPANIA INT = NULL,
    @i_CANTIDAD         INT,
    @i_AUD_USER         VARCHAR(16),
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        IF @i_CANTIDAD <= 0
        BEGIN
            SET @o_resultMessage = '0|La meta debe ser mayor a cero';
            RETURN;
        END

        UPDATE dbo.TMKK_META_VENTA
        SET NMET_CANTIDAD = @i_CANTIDAD, AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_USER
        WHERE NMET_PERIODO = @i_PERIODO AND FMET_ESTADO = 'V'
          AND ((@i_CCAM_ID_CAMPANIA IS NULL AND CCAM_ID_CAMPANIA IS NULL) OR CCAM_ID_CAMPANIA = @i_CCAM_ID_CAMPANIA);

        IF @@ROWCOUNT = 0
            INSERT INTO dbo.TMKK_META_VENTA (NMET_PERIODO, CCAM_ID_CAMPANIA, NMET_CANTIDAD, AUD_INS_FEC, AUD_INS_USER)
            VALUES (@i_PERIODO, @i_CCAM_ID_CAMPANIA, @i_CANTIDAD, GETDATE(), @i_AUD_USER);

        SET @o_resultMessage = '1|Meta registrada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_META_VENTA
    @i_PERIODO INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT m.CMET_ID_META, m.NMET_PERIODO, m.CCAM_ID_CAMPANIA, c.SCAM_NOMBRE AS SCAMPANIA, m.NMET_CANTIDAD
    FROM dbo.TMKK_META_VENTA m
    LEFT JOIN dbo.TMKK_CAMPANIA c ON c.CCAM_ID_CAMPANIA = m.CCAM_ID_CAMPANIA
    WHERE m.FMET_ESTADO = 'V' AND (@i_PERIODO IS NULL OR m.NMET_PERIODO = @i_PERIODO)
    ORDER BY m.NMET_PERIODO DESC, c.SCAM_NOMBRE;
END
GO
