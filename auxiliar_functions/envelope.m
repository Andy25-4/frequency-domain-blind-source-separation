function env = envelope(y, type, w)
%
% env = envelope(y, type) calcula o envelope de y, que � um ou mais vetores,
% dispostos a cada linha. N�O FUNCIONA COM MAIS DE 2 dimens�es. O par�metro
% 'type' diz o tipo de envelope. 1 � valor absoluto e 2 � valor relativo
% quadr�tico em rela��o aos outros elementos da mesma coluna.
%
% env = envelope(y, type, w), � para o m�todo 3, onde w � uma matriz com o
% mesmo n�mero de linhas que y, e um n�mero de colunas igual ao n�mero de
% sensores.
%
%   1 ('AbsValue')  - Valor absoluto.
%   2 ('PowValue')  - Raz�o entre a pot�ncia do valor do vetor e a soma das
%                     pot�ncias do mesmo valor em todos os vetores. Por
%                     defini��o, varia entre 0 e 1.
%   3 ('PowValue2') - Similar ao acima, por�m cada elemento j de uma linha
%                     i de y, onde a = w^(-1) e M � o n�mero de sensores, �
%                     sum(||a(1,i)*y(i,j) + a(2,i)*y(i,j) + ... + a(M,i)*y(i,j)||^2)
%   4 ('SPDValue')   - 

% � aconselh�vel que esta fun��o n�o dependa da fase do sinal.

N = size(y, 1); % N�mero de vetores
env = zeros(size(y));

if type == 1
    env = abs(y);

elseif type == 2
    for i = 1:N
        env(i,:) = y(i, :).*conj(y(i, :));
    end
    env = bsxfun(@rdivide, env, sum(env, 1));

    % Pre MatLab 2008
    %sumenv = repmat(sum(env, 1), size(env, 1), 1);
    %env = env ./ sumenv;
    
elseif type == 3
    a = inv(w);
    for i = 1:N
        tmpy = a(:,i) * y(i,:);
        env(i, :) = sum(tmpy.*conj(tmpy), 1);
    end
    %env = bsxfun(@rdivide, env, sum(env, 1));
    
    % Pre MatLab 2008
    sumenv = repmat(sum(env, 1), size(env, 1), 1);
    env = env ./ sumenv;
    
elseif type == 4
    for i = 1:N
        env(i, :) = y(i, :).*conj(y(i, :));
    end
    env = 10*log(env);
%    env = bsxfun(@rdivide, env, sum(env, 1));
    
    % Pre MatLab 2008
    %sumenv = repmat(sum(env, 1), size(env, 1), 1);
    %env = env ./ sumenv;

end