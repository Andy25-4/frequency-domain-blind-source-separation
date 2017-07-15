function r = tdoa(W, ref, f)
%
% r = tdoa(W, ref, f) retorna o Time Difference of Arrival
%
% r - matriz N x (M-1), onde cada linha � o TDOA de uma fonte em rela��o
%     aos microfones
% W - matriz N (fontes) x M (misturas) separadora
% ref - microfone a ser utilizado como refer�ncia. Ref � o n�mero da coluna
%       de W que corresponde a este sensor
% f - frequ�ncia do sinal
%
N = size(W,1);
M = size(W,2);

% Exce��o
if f == 0
    r = nan(N,M-1);
    return
end

if N == M,      A = inv(W);
else            A = pinv(W);                                        end

r = zeros(N,M-1);
for cm = 1:ref-1
    r(:,cm) = (angle(A(cm,:) ./ A(ref,:)) / (2*pi*f)).'; % Pode-se colocar um sinal de '-' aqui, o que altera apenas a refer�ncia
end
for cm = ref+1:M
    r(:,cm-1) = (angle(A(cm,:) ./ A(ref,:)) / (2*pi*f)).'; % Pode-se colocar um sinal de '-' aqui, o que altera apenas a refer�ncia
end