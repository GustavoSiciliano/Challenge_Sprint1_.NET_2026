using System.Text.Encodings.Web;
using System.Text.Json;
using System.Text.Json.Serialization;
using ProTons.Models;

namespace ProTons.Data;

public class AreaRepositorioJson
{
    private static readonly JsonSerializerOptions Opcoes = new()
    {
        WriteIndented = true,
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
        Converters = { new JsonStringEnumConverter() }
    };

    private readonly string _caminho;

    // Define o caminho do arquivo JSON.
    public AreaRepositorioJson(string caminho)
    {
        _caminho = caminho;
    }

    // Localiza a raiz do projeto para definir o caminho padrão do JSON.
    public static string CaminhoPadrao()
    {
        var pasta = new DirectoryInfo(AppContext.BaseDirectory);

        while (pasta != null &&
               pasta.GetFiles("*.sln").Length == 0 &&
               pasta.GetFiles("*.csproj").Length == 0)
            pasta = pasta.Parent;

        var raiz = pasta?.FullName ?? AppContext.BaseDirectory;

        return Path.Combine(raiz, "dados", "areas.json");
    }

    // Carrega as áreas cadastradas no arquivo JSON.
    public List<AreaAplicacao> Carregar()
    {
        if (!File.Exists(_caminho))
            return new List<AreaAplicacao>();

        var json = File.ReadAllText(_caminho);
        if (string.IsNullOrWhiteSpace(json))
            return new List<AreaAplicacao>();

        try
        {
            return JsonSerializer.Deserialize<List<AreaAplicacao>>(json, Opcoes) ?? new List<AreaAplicacao>();
        }
        catch (JsonException)
        {
            throw new InvalidDataException(
                $"O arquivo de dados está corrompido: {_caminho}. Corrija ou apague o arquivo e execute novamente.");
        }
    }

    // Salva as áreas no arquivo JSON.
    public void Salvar(List<AreaAplicacao> areas)
    {
        var pasta = Path.GetDirectoryName(_caminho);
        if (!string.IsNullOrEmpty(pasta))
            Directory.CreateDirectory(pasta);

        // Grava em arquivo temporário e troca no final, para nunca deixar o JSON pela metade.
        var temporario = _caminho + ".tmp";

        try
        {
            File.WriteAllText(temporario, JsonSerializer.Serialize(areas, Opcoes));
            File.Move(temporario, _caminho, overwrite: true);
        }
        finally
        {
            if (File.Exists(temporario))
                File.Delete(temporario);
        }
    }
}