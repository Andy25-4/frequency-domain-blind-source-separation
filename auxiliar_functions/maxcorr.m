function [Rf perm] = maxcorr(base_sig, adj_sig)
%
% [Rf, perm] = maxcorr(base_sig, adj_sig) analisa as correla��es
% entre um vetor com fontes de uma frequ�ncia base e outros vetores com fontes
% de frequ�ncias adjacentes, utilizando todas as permuta��es poss�veis das
% fontes da frequ�ncia base. � feita a soma dos valores de correla��o para cada
% permuta��o e retornada a maior soma e a permuta��o que obteve a maior soma.
%
% Rf - m�xima soma de correla��es
% perm - vetor coluna com a permuta��o que obteve a m�xima soma
% base_sig - matriz com as fontes da frequ�ncia base, onde cada fonte � uma linha
% adj_sig - matriz de 3 DIMENS�ES, similar � base_sig, e a 3� dimens�o � a das
%           frequ�ncias. � OBRIGAT�RIO que a matriz tenha 3 dimens�es
%
N = size(base_sig, 2);
poss_perms = perms(1:size(base_sig, 1)); % Cada linha � uma permuta��o
n_perms = size(poss_perms, 1);
Rf = zeros(n_perms, 1);

for prm = 1:n_perms
    permbase = base_sig(poss_perms(prm, :), :);
    
    % Pr�-calculando para agilizar a fun��o
    med_base = mean(permbase, 2);
    var_base = var(permbase, 0, 2);

    % Pode-se tentar usar a fun��o corrcoef do MatLab, se ela for mais
    % r�pida
    for f = 1:size(adj_sig, 1)
        tmpadj = squeeze( adj_sig(f, :, :) );
        Rf(prm) = Rf(prm) + sum( (sum(permbase .* tmpadj, 2)/(N-1) - (N/(N-1)) * med_base .* mean(tmpadj, 2)) ./ (sqrt(var_base .* var(tmpadj, 0, 2))) );
    end
end

[Rf ind]= max(Rf);
perm = poss_perms(ind, :).';
