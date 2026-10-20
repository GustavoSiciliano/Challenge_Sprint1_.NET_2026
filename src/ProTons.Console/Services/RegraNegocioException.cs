namespace ProTons.Services;

// Representa um erro causado por uma regra de negócio.
public class RegraNegocioException : Exception
{
    public RegraNegocioException(string mensagem) : base(mensagem) { }
}