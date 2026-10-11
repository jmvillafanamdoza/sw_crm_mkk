using System.Security.Cryptography;

namespace Aiwara.CRM.Api.Utilitarios;

/// <summary>
/// Contraseñas temporales (usuario nuevo o restablecida por un administrador) y su hash BCrypt.
/// La BD solo guarda el hash; la contraseña en claro se muestra una sola vez al administrador.
/// </summary>
public static class GeneradorPassword
{
    // Sin caracteres que se confunden al dictarlos o copiarlos (0/O, 1/l/I)
    private const string Mayusculas = "ABCDEFGHJKLMNPQRSTUVWXYZ";
    private const string Minusculas = "abcdefghijkmnpqrstuvwxyz";
    private const string Digitos = "23456789";

    public static string GenerarTemporal(int longitud = 10)
    {
        var todos = Mayusculas + Minusculas + Digitos;

        // Garantiza al menos una mayúscula, una minúscula y un dígito
        var caracteres = new List<char>
        {
            Mayusculas[RandomNumberGenerator.GetInt32(Mayusculas.Length)],
            Minusculas[RandomNumberGenerator.GetInt32(Minusculas.Length)],
            Digitos[RandomNumberGenerator.GetInt32(Digitos.Length)]
        };

        while (caracteres.Count < longitud)
        {
            caracteres.Add(todos[RandomNumberGenerator.GetInt32(todos.Length)]);
        }

        var resultado = caracteres.ToArray();
        RandomNumberGenerator.Shuffle(resultado.AsSpan());

        return new string(resultado);
    }

    public static string Hashear(string password) => BCrypt.Net.BCrypt.HashPassword(password);

    public static bool Verificar(string password, string hash) => BCrypt.Net.BCrypt.Verify(password, hash);
}
