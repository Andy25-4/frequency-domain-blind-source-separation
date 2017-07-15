function indArray = getAdjInd(baseind, distance, minind, maxind)
% indArray = getAdjInd(baseind, distance, min, max) retorna os �ndices adjacentes a
% 'baseind', com uma dist�ncia de 'distance', sabendo que o �ndice m�nimo n�o
% pode ser menor que 'minind' e o �ndice m�ximo, maior que 'maxind'
%
% A sa�da � um vetor LINHA
%
% Exemplos:
% getAdjInd(5, 2, -5, 15) retorna o vetor     [3 4 6 7]
% getAdjInd(5, 4, -5, 15) retorna o vetor [1 2 3 4 6 7 8 9]
% getAdjInd(5, 4, 3, 8) retorna o vetor       [3 4 6 7 8]

indArray = [ (baseind - distance):(baseind - 1) (baseind + 1):(baseind + distance) ];
indArray = indArray(indArray >= minind & indArray <= maxind);