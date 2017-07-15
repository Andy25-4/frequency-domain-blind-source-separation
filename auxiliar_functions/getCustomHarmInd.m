function indArray = getCustomHarmInd(f, f0, fmax)
% indArray = getCustomHarmInd(f, f0, fmax) retorna os �ndices dos harm�nicos
% da frequ�ncia cujo �ndice � 'f', e 'f0' � o �ndice da frequ�ncia 0. fmax
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
if fmax > f0,       increasing_freq = true;             % Frequ�ncias crescentes
else                increasing_freq = false;    end     % Frequ�ncias decrescentes

if increasing_freq
    if (f < f0) || (f > fmax)
        error('GETCUSTOMHARMIND - Frequ�ncia f fora dos limites f0 e fmax')
    end
else
    if (f > f0) || (f < fmax)
        error('GETCUSTOMHARMIND - Frequ�ncia f fora dos limites f0 e fmax')
    end
end

if f == f0
    indArray = [];
else

    indArray = [ceil((f-f0)/2) + f0 - 1, ceil((f-f0)/2) + f0, ...
                ceil((f-f0)/2) + f0 + 1, ...                               % f/2 - 1, f/2, f/2 + 1
                (f-f0)*2 + f0 - 1, (f-f0)*2 + f0, (f-f0)*2 + f0 + 1];       % 2*f - 1, 2*f, 2*f + 1

            if increasing_freq
                indArray = indArray(indArray > f0 & indArray <= fmax);
            else 
                indArray = indArray(indArray >= fmax & indArray < f0);
            end
            
    indArray = unique(indArray);
    indArray(indArray == f) = [];
end

