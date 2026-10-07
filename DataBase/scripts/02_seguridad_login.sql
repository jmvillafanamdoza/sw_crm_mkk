-- ==============================================================================
-- BASE DE DATOS: MAKOKOS (CRM MKK)
-- SCRIPT 02: SEGURIDAD Y LOGIN
--   * Incorpora public/DB/ESQUEMA_LOGIN.sql del front (ahora idempotente).
--   * Sistema, perfiles y menús alineados con src/navigation/vertical/index.ts.
--   * SPs de login, sesiones, recuperación/cambio de contraseña y menú por usuario.
--
-- Las contraseñas y tokens NUNCA llegan en texto plano: la API genera el hash
-- (BCrypt/Argon2) y lo verifica; los SPs solo guardan y devuelven hashes.
-- ==============================================================================

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

-- ==============================================================================
-- 1. TABLAS
-- ==============================================================================

-- Nombre completo tal como se captura en los formularios del front ("Nombres y
-- Apellidos"). Los campos separados (SPER_NOMBRE, SPER_APE_*) siguen disponibles.
IF COL_LENGTH('dbo.TPLS_PERSONA', 'SPER_NOM_COMPLETO') IS NULL
    ALTER TABLE dbo.TPLS_PERSONA ADD SPER_NOM_COMPLETO VARCHAR(200) NULL;
GO

-- Control de acceso en TMKK_USUARIO
IF COL_LENGTH('dbo.TMKK_USUARIO', 'DUSU_ULTIMO_LOGIN') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD DUSU_ULTIMO_LOGIN DATETIME NULL;
IF COL_LENGTH('dbo.TMKK_USUARIO', 'NUSU_INTENTOS_FALLIDOS') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD NUSU_INTENTOS_FALLIDOS TINYINT NOT NULL CONSTRAINT DF_TMKK_USUARIO_INTENTOS DEFAULT 0;
IF COL_LENGTH('dbo.TMKK_USUARIO', 'DUSU_FEC_BLOQUEO') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD DUSU_FEC_BLOQUEO DATETIME NULL;
IF COL_LENGTH('dbo.TMKK_USUARIO', 'FUSU_RECORDAR') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD FUSU_RECORDAR CHAR(1) NOT NULL CONSTRAINT DF_TMKK_USUARIO_RECORDAR DEFAULT 'N';
-- 'S' obliga a cambiar la contraseña en el siguiente login (usuario nuevo o contraseña restablecida)
IF COL_LENGTH('dbo.TMKK_USUARIO', 'FUSU_CAMBIAR_PASSWORD') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO ADD FUSU_CAMBIAR_PASSWORD CHAR(1) NOT NULL CONSTRAINT DF_TMKK_USUARIO_CAMBIAR_PWD DEFAULT 'N';
GO

IF OBJECT_ID('dbo.TMKK_USUARIO_SESION') IS NULL
CREATE TABLE dbo.TMKK_USUARIO_SESION (
    CUSN_ID_SESION      INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_USUARIO_SESION PRIMARY KEY,
    CUSU_ID_USUARIO     INT NOT NULL,
    SUSN_ACCESS_TOKEN   VARCHAR(255) NOT NULL CONSTRAINT UQ_TMKK_SESION_ACCESS UNIQUE,  -- hash del token
    SUSN_REFRESH_TOKEN  VARCHAR(255) NULL,                                                -- hash del refresh token
    FUSN_RECORDAR       CHAR(1) NOT NULL CONSTRAINT DF_TMKK_SESION_RECORDAR DEFAULT 'N',
    SUSN_IP_ORIGEN      VARCHAR(45) NULL,
    SUSN_USER_AGENT     VARCHAR(255) NULL,
    DUSN_FEC_INICIO     DATETIME NOT NULL CONSTRAINT DF_TMKK_SESION_INICIO DEFAULT GETDATE(),
    DUSN_FEC_EXPIRA     DATETIME NOT NULL,
    DUSN_FEC_CIERRE     DATETIME NULL,
    FUSN_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_SESION_ESTADO DEFAULT 'V',  -- V=vigente, R=revocada, X=expirada
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_SESION_USUARIO FOREIGN KEY (CUSU_ID_USUARIO) REFERENCES dbo.TMKK_USUARIO (CUSU_ID_USUARIO) ON DELETE CASCADE
);
GO
-- UNIQUE que admite varios NULL (una sesión sin "recuérdame" no tiene refresh token)
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_SESION_REFRESH')
    CREATE UNIQUE INDEX UX_TMKK_SESION_REFRESH ON dbo.TMKK_USUARIO_SESION (SUSN_REFRESH_TOKEN) WHERE SUSN_REFRESH_TOKEN IS NOT NULL;
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_TMKK_SESION_USUARIO')
    CREATE INDEX IX_TMKK_SESION_USUARIO ON dbo.TMKK_USUARIO_SESION (CUSU_ID_USUARIO, FUSN_ESTADO);
GO

IF OBJECT_ID('dbo.TMKK_USUARIO_TOKEN_RECUPERACION') IS NULL
CREATE TABLE dbo.TMKK_USUARIO_TOKEN_RECUPERACION (
    CTKR_ID_TOKEN       INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_TOKEN_RECUPERACION PRIMARY KEY,
    CUSU_ID_USUARIO     INT NOT NULL,
    STKR_TOKEN          VARCHAR(255) NOT NULL CONSTRAINT UQ_TMKK_TKR_TOKEN UNIQUE,  -- hash del token enviado por correo
    DTKR_FEC_SOLICITUD  DATETIME NOT NULL CONSTRAINT DF_TMKK_TKR_SOLICITUD DEFAULT GETDATE(),
    DTKR_FEC_EXPIRA     DATETIME NOT NULL,
    DTKR_FEC_USO        DATETIME NULL,
    STKR_IP_SOLICITUD   VARCHAR(45) NULL,
    FTKR_ESTADO         CHAR(1) NOT NULL CONSTRAINT DF_TMKK_TKR_ESTADO DEFAULT 'V',  -- V=vigente, U=usado, X=expirado/anulado
    AUD_INS_FEC         DATETIME NULL,
    AUD_INS_USER        VARCHAR(16) NULL,
    AUD_UPD_FEC         DATETIME NULL,
    AUD_UPD_USER        VARCHAR(16) NULL,
    CONSTRAINT FK_TMKK_TKR_USUARIO FOREIGN KEY (CUSU_ID_USUARIO) REFERENCES dbo.TMKK_USUARIO (CUSU_ID_USUARIO) ON DELETE CASCADE
);
GO

IF OBJECT_ID('dbo.TMKK_USUARIO_INTENTO_LOGIN') IS NULL
CREATE TABLE dbo.TMKK_USUARIO_INTENTO_LOGIN (
    CILG_ID_INTENTO         INT IDENTITY(1,1) NOT NULL CONSTRAINT PK_TMKK_INTENTO_LOGIN PRIMARY KEY,
    SILG_USUARIO_INGRESADO  VARCHAR(100) NOT NULL,
    CUSU_ID_USUARIO         INT NULL,
    FILG_EXITOSO            CHAR(1) NOT NULL,       -- S/N
    SILG_MOTIVO_FALLO       VARCHAR(100) NULL,      -- PASSWORD_INCORRECTO, USUARIO_INACTIVO, USUARIO_NO_EXISTE, USUARIO_BLOQUEADO
    SILG_IP_ORIGEN          VARCHAR(45) NULL,
    SILG_USER_AGENT         VARCHAR(255) NULL,
    DILG_FECHA              DATETIME NOT NULL CONSTRAINT DF_TMKK_ILG_FECHA DEFAULT GETDATE(),
    CONSTRAINT FK_TMKK_ILG_USUARIO FOREIGN KEY (CUSU_ID_USUARIO) REFERENCES dbo.TMKK_USUARIO (CUSU_ID_USUARIO)
);
GO

-- Excepciones de menú por usuario: P = permitir (aunque su perfil no lo tenga), D = denegar
IF COL_LENGTH('dbo.TMKK_USUARIO_EXCEPCION_MENU', 'FUME_TIPO') IS NULL
    ALTER TABLE dbo.TMKK_USUARIO_EXCEPCION_MENU ADD FUME_TIPO CHAR(1) NOT NULL CONSTRAINT DF_TMKK_UEM_TIPO DEFAULT 'P';
GO

-- Nombre de ruta del front (unplugin-vue-router), p.ej. 'ventas-lista-de-ventas'
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'UX_TMKK_MENU_RUTA')
    CREATE UNIQUE INDEX UX_TMKK_MENU_RUTA ON dbo.TMKK_MENU (CSIT_ID_SISTEMA, SMNU_RUTA_VISUAL) WHERE SMNU_RUTA_VISUAL IS NOT NULL;
GO

-- ==============================================================================
-- 2. DATOS INICIALES: sistema, perfiles y menú (espejo de la navegación del front)
-- ==============================================================================
IF NOT EXISTS (SELECT 1 FROM dbo.TMKK_SISTEMA WHERE SSIT_NOMBRE = 'CRM MAKOKOS')
    INSERT INTO dbo.TMKK_SISTEMA (SSIT_NOMBRE, SSIT_DESCRIPCION, SIT_ESTADO, AUD_INS_FEC, AUD_INS_USER)
    VALUES ('CRM MAKOKOS', 'CRM de ventas, asistencia y llamadas', 'V', GETDATE(), 'AIW_SISTEMAS');
GO

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

-- Menú: (ruta, padre, nombre, icono, orden). Los padres no tienen ruta propia en el
-- front; se identifican con una clave 'grupo:*'.
DECLARE @menu TABLE (ruta VARCHAR(255), padre VARCHAR(255), nombre VARCHAR(100), icono VARCHAR(50), orden INT);
INSERT INTO @menu VALUES
    ('grupo:ventas',                 NULL,                'Ventas',                 'tabler-shopping-cart',     10),
    ('ventas-lista-de-ventas',       'grupo:ventas',      'Lista de Ventas',        'tabler-list',              11),
    ('ventas-registro-de-ventas',    'grupo:ventas',      'Registro de Ventas',     'tabler-receipt-2',         12),
    ('grupo:asistencia',             NULL,                'Asistencia',             'tabler-headset',           20),
    ('asistencia-registro',          'grupo:asistencia',  'Registro de Asistencia', 'tabler-calendar-check',    21),
    ('asistencia-reportes',          'grupo:asistencia',  'Reportes de Asistencia', 'tabler-chart-bar',         22),
    ('grupo:llamadas',               NULL,                'Llamadas',               'tabler-phone',             30),
    ('llamadas-dash-tipificaciones', 'grupo:llamadas',    'Dash Tipificaciones',    'tabler-chart-pie',         31),
    ('comisiones',                   NULL,                'Comisiones',             'tabler-percentage',        40),
    ('grupo:headcount',              NULL,                'HeadCount',              'tabler-users',             50),
    ('personal',                     'grupo:headcount',   'Dashboard HeadCount',    'tabler-layout-dashboard',  51),
    ('personal-registro-bajas',      'grupo:headcount',   'Registro-Bajas',         'tabler-user-minus',        52),
    ('procesos-yreportes',           NULL,                'Procesos y Reportes',    'tabler-report',            60),
    ('grupo:mantenimiento',          NULL,                'Mantenimiento',          'tabler-tool',              70),
    ('mantenimiento-usuarios',       'grupo:mantenimiento','Usuarios',              'tabler-users',             71),
    ('mantenimiento-campanias',      'grupo:mantenimiento','Campañas',              'tabler-speakerphone',      72),
    ('mantenimiento-estados',        'grupo:mantenimiento','Estados',               'tabler-list-check',        73),
    ('mantenimiento-operadores',     'grupo:mantenimiento','Operadores',            'tabler-antenna',           74);

INSERT INTO dbo.TMKK_MENU (CSIT_ID_SISTEMA, CMNU_MENU_PADRE, SMNU_NOMBRE, SMNU_RUTA_VISUAL, SMNU_ICONO, NMNU_ORDEN, FMNU_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT @sis, NULL, m.nombre, m.ruta, m.icono, m.orden, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM @menu m
WHERE m.padre IS NULL
  AND NOT EXISTS (SELECT 1 FROM dbo.TMKK_MENU x WHERE x.CSIT_ID_SISTEMA = @sis AND x.SMNU_RUTA_VISUAL = m.ruta);

INSERT INTO dbo.TMKK_MENU (CSIT_ID_SISTEMA, CMNU_MENU_PADRE, SMNU_NOMBRE, SMNU_RUTA_VISUAL, SMNU_ICONO, NMNU_ORDEN, FMNU_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT @sis, p.CMNU_ID_MENU, m.nombre, m.ruta, m.icono, m.orden, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM @menu m
JOIN dbo.TMKK_MENU p ON p.CSIT_ID_SISTEMA = @sis AND p.SMNU_RUTA_VISUAL = m.padre
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_MENU x WHERE x.CSIT_ID_SISTEMA = @sis AND x.SMNU_RUTA_VISUAL = m.ruta);

-- Accesos por perfil (ajústelos según la operación). '*' = todo el menú.
DECLARE @acceso TABLE (perfil VARCHAR(50), ruta VARCHAR(255));
INSERT INTO @acceso VALUES
    ('ADMINISTRADOR', '*'),
    ('SUPERVISOR', 'grupo:ventas'), ('SUPERVISOR', 'ventas-lista-de-ventas'), ('SUPERVISOR', 'ventas-registro-de-ventas'),
    ('SUPERVISOR', 'grupo:asistencia'), ('SUPERVISOR', 'asistencia-registro'), ('SUPERVISOR', 'asistencia-reportes'),
    ('SUPERVISOR', 'grupo:llamadas'), ('SUPERVISOR', 'llamadas-dash-tipificaciones'),
    ('SUPERVISOR', 'comisiones'),
    ('SUPERVISOR', 'grupo:headcount'), ('SUPERVISOR', 'personal'),
    ('SUPERVISOR', 'procesos-yreportes'),
    ('ASESOR', 'grupo:ventas'), ('ASESOR', 'ventas-lista-de-ventas'), ('ASESOR', 'ventas-registro-de-ventas'),
    ('BACKOFFICE', 'grupo:ventas'), ('BACKOFFICE', 'ventas-lista-de-ventas'), ('BACKOFFICE', 'ventas-registro-de-ventas'),
    ('BACKOFFICE', 'procesos-yreportes');

INSERT INTO dbo.TMKK_PERFIL_MENU (CPFL_ID_PERFIL, CMNU_ID_MENU, FRLM_ESTADO, AUD_INS_FEC, AUD_INS_USER)
SELECT DISTINCT p.CPFL_ID_PERFIL, m.CMNU_ID_MENU, 'V', GETDATE(), 'AIW_SISTEMAS'
FROM @acceso a
JOIN dbo.TMKK_PERFIL p ON p.CSIT_ID_SISTEMA = @sis AND p.SPFL_NOMBRE = a.perfil
JOIN dbo.TMKK_MENU m ON m.CSIT_ID_SISTEMA = @sis AND (a.ruta = '*' OR m.SMNU_RUTA_VISUAL = a.ruta)
WHERE NOT EXISTS (SELECT 1 FROM dbo.TMKK_PERFIL_MENU x WHERE x.CPFL_ID_PERFIL = p.CPFL_ID_PERFIL AND x.CMNU_ID_MENU = m.CMNU_ID_MENU);
GO

-- ==============================================================================
-- 3. STORED PROCEDURES
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- Busca al usuario por nombre de usuario o correo (el login acepta ambos).
-- Devuelve el hash para que la API lo verifique. FBLOQUEADO = 'S' mientras no
-- pasen @i_MINUTOS_BLOQUEO desde el último bloqueo.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_LOGIN_USUARIO
    @i_USUARIO          VARCHAR(100),
    @i_MINUTOS_BLOQUEO  INT = 15
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (1)
        u.CUSU_ID_USUARIO,
        u.SUSU_USERNAME,
        u.SUSU_PASSWORD_HASH,
        u.FUSU_ESTADO,
        u.NUSU_INTENTOS_FALLIDOS,
        u.DUSU_FEC_BLOQUEO,
        CASE WHEN u.DUSU_FEC_BLOQUEO IS NOT NULL
              AND DATEADD(MINUTE, @i_MINUTOS_BLOQUEO, u.DUSU_FEC_BLOQUEO) > GETDATE()
             THEN 'S' ELSE 'N' END AS FBLOQUEADO,
        u.FUSU_CAMBIAR_PASSWORD,
        u.DUSU_ULTIMO_LOGIN,
        p.CPER_ID_PERSONA,
        COALESCE(p.SPER_NOM_COMPLETO,
                 LTRIM(CONCAT(p.SPER_APE_PATERNO, ' ', p.SPER_APE_MATERNO, ' ', p.SPER_NOMBRE))) AS SNOMBRE_COMPLETO,
        COALESCE(p.SPER_COR_LABORAL, p.SPER_COR_PERSONAL) AS SCORREO,
        pf.CPFL_ID_PERFIL,
        pf.SPFL_NOMBRE AS SPERFIL,
        pe.CPEL_ID_PERSONAL
    FROM dbo.TMKK_USUARIO u
    JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = u.CPER_ID_PERSONA
    LEFT JOIN dbo.TMKK_USUARIO_PERFIL up ON up.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO AND up.FUSR_ESTADO = 'V'
    LEFT JOIN dbo.TMKK_PERFIL pf ON pf.CPFL_ID_PERFIL = up.CPFL_ID_PERFIL
    LEFT JOIN dbo.TMKK_PERSONAL pe ON pe.CUSU_ID_USUARIO = u.CUSU_ID_USUARIO
    WHERE u.SUSU_USERNAME = @i_USUARIO
       OR p.SPER_COR_LABORAL = @i_USUARIO
       OR p.SPER_COR_PERSONAL = @i_USUARIO
    ORDER BY CASE WHEN u.SUSU_USERNAME = @i_USUARIO THEN 0 ELSE 1 END, up.DUSR_FECHA_ASIGNACION DESC;
END
GO

-- ------------------------------------------------------------------------------
-- Registra el resultado de un intento de login.
--   Éxito : resetea intentos, quita bloqueo y guarda último login / "recuérdame".
--   Fallo : suma un intento; al llegar a @i_MAX_INTENTOS bloquea al usuario.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_INTENTO_LOGIN
    @i_USUARIO_INGRESADO VARCHAR(100),
    @i_CUSU_ID_USUARIO   INT          = NULL,
    @i_EXITOSO           CHAR(1),               -- S/N
    @i_MOTIVO_FALLO      VARCHAR(100) = NULL,
    @i_IP_ORIGEN         VARCHAR(45)  = NULL,
    @i_USER_AGENT        VARCHAR(255) = NULL,
    @i_RECORDAR          CHAR(1)      = 'N',
    @i_MAX_INTENTOS      TINYINT      = 5,
    @o_resultMessage     VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRANSACTION;

        INSERT INTO dbo.TMKK_USUARIO_INTENTO_LOGIN
            (SILG_USUARIO_INGRESADO, CUSU_ID_USUARIO, FILG_EXITOSO, SILG_MOTIVO_FALLO, SILG_IP_ORIGEN, SILG_USER_AGENT)
        VALUES
            (@i_USUARIO_INGRESADO, @i_CUSU_ID_USUARIO, @i_EXITOSO, @i_MOTIVO_FALLO, @i_IP_ORIGEN, @i_USER_AGENT);

        IF @i_CUSU_ID_USUARIO IS NOT NULL
        BEGIN
            IF @i_EXITOSO = 'S'
                UPDATE dbo.TMKK_USUARIO
                SET NUSU_INTENTOS_FALLIDOS = 0,
                    DUSU_FEC_BLOQUEO       = NULL,
                    DUSU_ULTIMO_LOGIN      = GETDATE(),
                    FUSU_RECORDAR          = ISNULL(@i_RECORDAR, 'N')
                WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;
            ELSE IF ISNULL(@i_MOTIVO_FALLO, '') <> 'USUARIO_BLOQUEADO'
                UPDATE dbo.TMKK_USUARIO
                SET NUSU_INTENTOS_FALLIDOS = CASE WHEN NUSU_INTENTOS_FALLIDOS + 1 >= @i_MAX_INTENTOS THEN 0 ELSE NUSU_INTENTOS_FALLIDOS + 1 END,
                    DUSU_FEC_BLOQUEO       = CASE WHEN NUSU_INTENTOS_FALLIDOS + 1 >= @i_MAX_INTENTOS THEN GETDATE() ELSE DUSU_FEC_BLOQUEO END
                WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;
        END

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Intento registrado';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_USUARIO_SESION
    @i_CUSU_ID_USUARIO  INT,
    @i_ACCESS_TOKEN     VARCHAR(255),
    @i_REFRESH_TOKEN    VARCHAR(255) = NULL,
    @i_RECORDAR         CHAR(1)      = 'N',
    @i_IP_ORIGEN        VARCHAR(45)  = NULL,
    @i_USER_AGENT       VARCHAR(255) = NULL,
    @i_FEC_EXPIRA       DATETIME,
    @o_CUSN_ID_SESION   INT OUTPUT,
    @o_resultMessage    VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- Las sesiones vencidas del usuario se marcan como expiradas
        UPDATE dbo.TMKK_USUARIO_SESION
        SET FUSN_ESTADO = 'X', AUD_UPD_FEC = GETDATE()
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUSN_ESTADO = 'V' AND DUSN_FEC_EXPIRA <= GETDATE();

        INSERT INTO dbo.TMKK_USUARIO_SESION
            (CUSU_ID_USUARIO, SUSN_ACCESS_TOKEN, SUSN_REFRESH_TOKEN, FUSN_RECORDAR, SUSN_IP_ORIGEN, SUSN_USER_AGENT,
             DUSN_FEC_EXPIRA, AUD_INS_FEC, AUD_INS_USER)
        VALUES
            (@i_CUSU_ID_USUARIO, @i_ACCESS_TOKEN, NULLIF(@i_REFRESH_TOKEN, ''), ISNULL(@i_RECORDAR, 'N'), @i_IP_ORIGEN, @i_USER_AGENT,
             @i_FEC_EXPIRA, GETDATE(), 'LOGIN');

        SET @o_CUSN_ID_SESION = SCOPE_IDENTITY();
        SET @o_resultMessage = '1|Sesión creada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Valida el token Bearer de cada request. Sin filas = sesión inválida.
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_USUARIO_SESION
    @i_ACCESS_TOKEN VARCHAR(255)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT s.CUSN_ID_SESION, s.CUSU_ID_USUARIO, u.SUSU_USERNAME, s.DUSN_FEC_EXPIRA, s.FUSN_RECORDAR
    FROM dbo.TMKK_USUARIO_SESION s
    JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = s.CUSU_ID_USUARIO
    WHERE s.SUSN_ACCESS_TOKEN = @i_ACCESS_TOKEN
      AND s.FUSN_ESTADO = 'V'
      AND s.DUSN_FEC_EXPIRA > GETDATE()
      AND u.FUSU_ESTADO = 'V';
END
GO

-- Rota los tokens de una sesión a partir de su refresh token.
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_REFRESCAR_SESION
    @i_REFRESH_TOKEN        VARCHAR(255),
    @i_NUEVO_ACCESS_TOKEN   VARCHAR(255),
    @i_NUEVO_REFRESH_TOKEN  VARCHAR(255),
    @i_FEC_EXPIRA           DATETIME,
    @o_CUSU_ID_USUARIO      INT OUTPUT,
    @o_resultMessage        VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        UPDATE s
        SET @o_CUSU_ID_USUARIO   = s.CUSU_ID_USUARIO,
            SUSN_ACCESS_TOKEN    = @i_NUEVO_ACCESS_TOKEN,
            SUSN_REFRESH_TOKEN   = @i_NUEVO_REFRESH_TOKEN,
            DUSN_FEC_EXPIRA      = @i_FEC_EXPIRA,
            AUD_UPD_FEC          = GETDATE(),
            AUD_UPD_USER         = 'REFRESH'
        FROM dbo.TMKK_USUARIO_SESION s
        JOIN dbo.TMKK_USUARIO u ON u.CUSU_ID_USUARIO = s.CUSU_ID_USUARIO
        WHERE s.SUSN_REFRESH_TOKEN = @i_REFRESH_TOKEN
          AND s.FUSN_ESTADO = 'V'
          AND u.FUSU_ESTADO = 'V';

        IF @@ROWCOUNT = 0
        BEGIN
            SET @o_resultMessage = '0|Sesión no válida';
            RETURN;
        END

        SET @o_resultMessage = '1|Sesión renovada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Logout. Con @i_TODAS = 'S' cierra todas las sesiones del usuario dueño del token.
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_CERRAR_SESION
    @i_ACCESS_TOKEN  VARCHAR(255),
    @i_TODAS         CHAR(1) = 'N',
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @usuario INT = (SELECT CUSU_ID_USUARIO FROM dbo.TMKK_USUARIO_SESION WHERE SUSN_ACCESS_TOKEN = @i_ACCESS_TOKEN);

        IF @usuario IS NULL
        BEGIN
            SET @o_resultMessage = '0|Sesión no encontrada';
            RETURN;
        END

        UPDATE dbo.TMKK_USUARIO_SESION
        SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = 'LOGOUT'
        WHERE FUSN_ESTADO = 'V'
          AND ((@i_TODAS = 'S' AND CUSU_ID_USUARIO = @usuario) OR SUSN_ACCESS_TOKEN = @i_ACCESS_TOKEN);

        SET @o_resultMessage = '1|Sesión cerrada';
    END TRY
    BEGIN CATCH
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- "¿Olvidaste tu contraseña?": genera el token (la API envía el correo con los
-- datos devueltos en el SELECT). Anula los tokens vigentes anteriores.
-- Si el usuario no existe se responde éxito igual, para no revelar cuentas.
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_INS_BOF_TOKEN_RECUPERACION
    @i_USUARIO       VARCHAR(100),
    @i_TOKEN         VARCHAR(255),
    @i_FEC_EXPIRA    DATETIME,
    @i_IP_SOLICITUD  VARCHAR(45) = NULL,
    @o_resultMessage VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @usuario INT, @correo VARCHAR(100), @nombre VARCHAR(200);

        SELECT TOP (1)
            @usuario = u.CUSU_ID_USUARIO,
            @correo  = COALESCE(p.SPER_COR_LABORAL, p.SPER_COR_PERSONAL),
            @nombre  = COALESCE(p.SPER_NOM_COMPLETO, LTRIM(CONCAT(p.SPER_NOMBRE, ' ', p.SPER_APE_PATERNO)))
        FROM dbo.TMKK_USUARIO u
        JOIN dbo.TPLS_PERSONA p ON p.CPER_ID_PERSONA = u.CPER_ID_PERSONA
        WHERE u.FUSU_ESTADO = 'V'
          AND (u.SUSU_USERNAME = @i_USUARIO OR p.SPER_COR_LABORAL = @i_USUARIO OR p.SPER_COR_PERSONAL = @i_USUARIO);

        IF @usuario IS NOT NULL AND @correo IS NOT NULL
        BEGIN
            BEGIN TRANSACTION;

            UPDATE dbo.TMKK_USUARIO_TOKEN_RECUPERACION
            SET FTKR_ESTADO = 'X', AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = 'RECUPERACION'
            WHERE CUSU_ID_USUARIO = @usuario AND FTKR_ESTADO = 'V';

            INSERT INTO dbo.TMKK_USUARIO_TOKEN_RECUPERACION
                (CUSU_ID_USUARIO, STKR_TOKEN, DTKR_FEC_EXPIRA, STKR_IP_SOLICITUD, AUD_INS_FEC, AUD_INS_USER)
            VALUES
                (@usuario, @i_TOKEN, @i_FEC_EXPIRA, @i_IP_SOLICITUD, GETDATE(), 'RECUPERACION');

            COMMIT TRANSACTION;
        END

        -- Datos para que la API envíe el correo (sin filas = no enviar nada)
        SELECT @usuario AS CUSU_ID_USUARIO, @correo AS SCORREO, @nombre AS SNOMBRE_COMPLETO
        WHERE @usuario IS NOT NULL AND @correo IS NOT NULL;

        SET @o_resultMessage = '1|Si la cuenta existe, se enviará un correo con las instrucciones';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- Usa el token de recuperación: cambia la contraseña y cierra todas las sesiones.
CREATE OR ALTER PROCEDURE dbo.PRMKK_UPD_BOF_RESTABLECER_PASSWORD
    @i_TOKEN          VARCHAR(255),
    @i_PASSWORD_HASH  VARCHAR(255),
    @o_resultMessage  VARCHAR(500) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @usuario INT, @token INT;

        SELECT @token = CTKR_ID_TOKEN, @usuario = CUSU_ID_USUARIO
        FROM dbo.TMKK_USUARIO_TOKEN_RECUPERACION
        WHERE STKR_TOKEN = @i_TOKEN AND FTKR_ESTADO = 'V' AND DTKR_FEC_EXPIRA > GETDATE();

        IF @token IS NULL
        BEGIN
            SET @o_resultMessage = '0|El enlace de recuperación no es válido o ya expiró';
            RETURN;
        END

        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_USUARIO
        SET SUSU_PASSWORD_HASH = @i_PASSWORD_HASH, FUSU_CAMBIAR_PASSWORD = 'N',
            NUSU_INTENTOS_FALLIDOS = 0, DUSU_FEC_BLOQUEO = NULL,
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = 'RECUPERACION'
        WHERE CUSU_ID_USUARIO = @usuario;

        UPDATE dbo.TMKK_USUARIO_TOKEN_RECUPERACION
        SET FTKR_ESTADO = 'U', DTKR_FEC_USO = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = 'RECUPERACION'
        WHERE CTKR_ID_TOKEN = @token;

        UPDATE dbo.TMKK_USUARIO_SESION
        SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = 'RECUPERACION'
        WHERE CUSU_ID_USUARIO = @usuario AND FUSN_ESTADO = 'V';

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Contraseña restablecida';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Cambio de contraseña (Perfil > Seguridad, o un administrador desde Usuarios).
-- La API valida la contraseña actual antes de llamar. Con @i_FORZAR_CAMBIO = 'S'
-- (reset por administrador) el usuario deberá cambiarla en su próximo login.
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
        BEGIN TRANSACTION;

        UPDATE dbo.TMKK_USUARIO
        SET SUSU_PASSWORD_HASH = @i_PASSWORD_HASH,
            FUSU_CAMBIAR_PASSWORD = ISNULL(@i_FORZAR_CAMBIO, 'N'),
            NUSU_INTENTOS_FALLIDOS = 0, DUSU_FEC_BLOQUEO = NULL,
            AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO;

        IF @@ROWCOUNT = 0
        BEGIN
            ROLLBACK TRANSACTION;
            SET @o_resultMessage = '0|Usuario no encontrado';
            RETURN;
        END

        IF @i_CERRAR_SESIONES = 'S'
            UPDATE dbo.TMKK_USUARIO_SESION
            SET FUSN_ESTADO = 'R', DUSN_FEC_CIERRE = GETDATE(), AUD_UPD_FEC = GETDATE(), AUD_UPD_USER = @i_AUD_UPD_USER
            WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUSN_ESTADO = 'V';

        COMMIT TRANSACTION;
        SET @o_resultMessage = '1|Contraseña actualizada';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        SET @o_resultMessage = '0|error en el procesamiento ' + ISNULL(ERROR_MESSAGE(), 'Error desconocido');
    END CATCH;
END
GO

-- ------------------------------------------------------------------------------
-- Menú del usuario = menús de sus perfiles + excepciones 'P' - excepciones 'D'.
-- Incluye automáticamente los padres de cualquier opción permitida.
-- SMNU_RUTA_VISUAL es el nombre de ruta del front (los grupos empiezan con 'grupo:').
-- ------------------------------------------------------------------------------
CREATE OR ALTER PROCEDURE dbo.PRMKK_CON_BOF_MENU_USUARIO
    @i_CUSU_ID_USUARIO INT
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH permitidos AS (
        SELECT pm.CMNU_ID_MENU
        FROM dbo.TMKK_USUARIO_PERFIL up
        JOIN dbo.TMKK_PERFIL pf ON pf.CPFL_ID_PERFIL = up.CPFL_ID_PERFIL AND pf.FPFL_ESTADO = 'V'
        JOIN dbo.TMKK_PERFIL_MENU pm ON pm.CPFL_ID_PERFIL = up.CPFL_ID_PERFIL AND pm.FRLM_ESTADO = 'V'
        WHERE up.CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND up.FUSR_ESTADO = 'V'
        UNION
        SELECT CMNU_ID_MENU FROM dbo.TMKK_USUARIO_EXCEPCION_MENU
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUME_ESTADO = 'V' AND FUME_TIPO = 'P'
        EXCEPT
        SELECT CMNU_ID_MENU FROM dbo.TMKK_USUARIO_EXCEPCION_MENU
        WHERE CUSU_ID_USUARIO = @i_CUSU_ID_USUARIO AND FUME_ESTADO = 'V' AND FUME_TIPO = 'D'
    ),
    arbol AS (
        SELECT m.CMNU_ID_MENU, m.CMNU_MENU_PADRE
        FROM dbo.TMKK_MENU m
        JOIN permitidos p ON p.CMNU_ID_MENU = m.CMNU_ID_MENU
        WHERE m.FMNU_ESTADO = 'V'
        UNION ALL
        SELECT m.CMNU_ID_MENU, m.CMNU_MENU_PADRE
        FROM dbo.TMKK_MENU m
        JOIN arbol a ON a.CMNU_MENU_PADRE = m.CMNU_ID_MENU
        WHERE m.FMNU_ESTADO = 'V'
    )
    SELECT DISTINCT m.CMNU_ID_MENU, m.CMNU_MENU_PADRE, m.SMNU_NOMBRE, m.SMNU_RUTA_VISUAL, m.SMNU_ICONO, m.NMNU_ORDEN
    FROM dbo.TMKK_MENU m
    JOIN arbol a ON a.CMNU_ID_MENU = m.CMNU_ID_MENU
    ORDER BY m.NMNU_ORDEN;
END
GO

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
