function indArray = getCustomInd(f, dist, f0, fmax)
% indArray = getCustomInd(f, dist, f0, fmax) retorna os �ndices dos harm�nicos
% da frequ�ncia cujo �ndice � 'f', e os �ndices adjacentes a ela, com uma
% dist�ncia de 'dist'. 'f0' � o �ndice da frequ�ncia 0, e fmax
% � o �ndice da frequ�ncia m�xima.
%
% As frequ�ncias podem ser decrescentes. Neste caso, f0 > fmax, ou seja, o
% �ndice da frequ�ncia 0 pode ser 256, e o da frequ�ncia m�xima 1. Isto �
% �til para encontrar harm�nicos de frequ�ncias negativas.
%
% A sa�da � um vetor LINHA
%
% Atualmente ele retorna os seguintes harm�nicos:
% f/2 - 1, f/2, f/2 + 1
% 2*f - 1, 2*f, 2*f + 1
%
if fmax > f0
    indArray = [getCustomHarmInd(f, f0, fmax) getAdjInd(f, dist, f0, fmax)];    % Frequ�ncias crescentes
else
    indArray = [getCustomHarmInd(f, f0, fmax) getAdjInd(f, dist, fmax, f0)];    % Frequ�ncias decrescentes
end     

indArray = unique(indArray);
