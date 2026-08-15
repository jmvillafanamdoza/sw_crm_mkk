using Aiwara.CRM.Api.Config;
using Aiwara.CRM.Api.EndPoints;
using Aiwara.CRM.Api.Filtros;
using Aiwara.CRM.Api.Repositorios;
using Aiwara.CRM.Api.Swagger;
using FluentValidation;
using Scalar.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// ---------------------------------------------------------------------
// 1. Configuración fuertemente tipada (appsettings -> Config/)
// ---------------------------------------------------------------------
builder.Services.Configure<DatabaseSettings>(
    builder.Configuration.GetSection("ConnectionStrings"));

// ---------------------------------------------------------------------
// 2. CORS
// ---------------------------------------------------------------------
const string corsPolicyName = "DefaultCorsPolicy";
builder.Services.AddCors(options =>
{
    options.AddPolicy(corsPolicyName, policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
        // Si necesitas credenciales/cookies, reemplaza AllowAnyOrigin()
        // por WithOrigins("https://tu-dominio.com").AllowCredentials()
    });
});

// ---------------------------------------------------------------------
// 3. OpenAPI nativo (.NET 10) + Scalar como UI (reemplazo de Swagger UI)
// ---------------------------------------------------------------------
builder.Services.AddAiwaraOpenApi();

// ---------------------------------------------------------------------
// 4. Acceso a datos (Dapper + factory de conexiones)
// ---------------------------------------------------------------------
builder.Services.AddScoped<IConnectionFactory, ConnectionFactory>();
builder.Services.AddScoped<IEjemploRepositorio, EjemploRepositorio>();
builder.Services.AddScoped<ITipoValorRepositorio, TipoValorRepositorio>();

// ---------------------------------------------------------------------
// 5. AutoMapper (perfiles se detectan automáticamente en Utilitarios/)
// ---------------------------------------------------------------------
builder.Services.AddAutoMapper(cfg => { }, AppDomain.CurrentDomain.GetAssemblies());

// ---------------------------------------------------------------------
// 6. FluentValidation (validadores en Validaciones/)
// ---------------------------------------------------------------------
builder.Services.AddValidatorsFromAssemblyContaining<Program>();

// ---------------------------------------------------------------------
// 7. Repositorios (agrega acá cada repo nuevo, o migra a un modulo de
//    extensión tipo ServiceCollectionExtensions si crecen mucho)
// ---------------------------------------------------------------------
// builder.Services.AddScoped<IClienteRepositorio, ClienteRepositorio>();

var app = builder.Build();

// ---------------------------------------------------------------------
// Pipeline HTTP
// ---------------------------------------------------------------------
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();                 // expone /openapi/v1.json
    app.MapScalarApiReference(options =>
    {
        options.Title = "Aiwara CRM API";
        options.Theme = ScalarTheme.Purple;
    });                                // UI en /scalar/v1
}

app.UseMiddleware<ExceptionHandlingMiddleware>();
app.UseHttpsRedirection();
app.UseCors(corsPolicyName);

// Registro de endpoints (Minimal API) agrupados por dominio
app.MapTipoValorEndpoints();

app.Run();
