function indArray = getInvCustomHarmInd(f, f0, fmax)
% indArray = getInvCustomHarmInd(f, f0, fmax) retorna os �ndices dos harm�nicos
% inversos de getCustomHarmInd
%
% Em outras palavras, para uma frequ�ncia f, ela retorna de quais outras
% frequ�ncias ela � harm�nica.

% N�O EST� FUNCIONANDO MUITO BEM PARA FREQU�NCIAS DECRESCENTES (pega mais 
% do que o necess�rio nos ceil, normalmente isso n�o � problema). Talvez
% tenha que usar floor(.)

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

if f == 1
    indArray = [];
else

    indArray = [2*(f - f0 + 1) + f0,  2*(f - f0 + 1) + f0 - 1, ...
                2*(f - f0) + f0,  2*(f - f0) + f0 - 1, ...
                2*(f - f0 - 1) + f0,  2*(f - f0 - 1) + f0 - 1, ...
                ceil((f - f0 + 1)/2) + f0, ceil((f - f0)/2) + f0, ...
                ceil((f - f0 - 1)/2) + f0];

            if increasing_freq
                indArray = indArray(indArray > f0 & indArray <= fmax);
            else 
                indArray = indArray(indArray >= fmax & indArray < f0);
            end
            
    indArray = unique(indArray);
    indArray(indArray == f) = [];
end

