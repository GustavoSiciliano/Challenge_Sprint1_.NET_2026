namespace ProTons.Models;

// Define os rótulos exibidos para cada setor.
public static class SetorExtensions
{
    public static string Rotulo(this Setor setor)
    {
        switch (setor)
        {
            case Setor.Saude:
                return "Saúde";
            case Setor.Agricultura:
                return "Agricultura";
            case Setor.Industria:
                return "Indústria";
            case Setor.Pesquisa:
                return "Pesquisa";
            case Setor.Energia:
                return "Energia";
            default:
                return setor.ToString();
        }
    }
}