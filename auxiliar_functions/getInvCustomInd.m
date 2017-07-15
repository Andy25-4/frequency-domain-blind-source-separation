function indArray = getInvCustomInd(f, dist, f0, fmax)
% indArray = getInvCustomInd(f, dist, f0, fmax) retorna os �ndices inversos
% da fun��o getCustomInd.
%
% Em outras palavras, para uma frequ�ncia f, ela retorna de quais outras
% frequ�ncias ela � adjacente ou harm�nica.
%
if fmax > f0
    indArray = [getInvCustomHarmInd(f, f0, fmax) getAdjInd(f, dist, f0, fmax)];    % Frequ�ncias crescentes
else
    indArray = [getInvCustomHarmInd(f, f0, fmax) getAdjInd(f, dist, fmax, f0)];    % Frequ�ncias decrescentes
end     

indArray = unique(indArray);