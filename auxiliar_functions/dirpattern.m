function U = dirpattern(W, d, f, teta)
%
% U = dirpattern(W, d, f, teta) retorna o "directivity pattern" de v�rias
% fontes, onde W � a matriz de separa��o da fonte. O �ngulo perpendicular �
% posi��o dos sensores � pi/2 (90�)
%
% U - matriz onde cada linha � o "directivity pattern" de uma fonte
%
% teta - vetor linha onde cada elemento � um �ngulo onde f deve ser
%        encontrado. Deve estar entre 0 e pi
% W - matriz N (fontes) x M (misturas) separadora
% d - vetor com a posi��o dos sensores em metros(exemplo [-0.02 0.02], se a
%     dist�ncia entre os sensores for 0.04
% f - frequ�ncia do sinal
%
global SPEED_OF_SOUND
if isempty(SPEED_OF_SOUND)
    SPEED_OF_SOUND = 343;
end

d = d(:);

c = 1/SPEED_OF_SOUND; % inverso da velocidade de propaga��o no meio, em s/m
N = size(W, 1); % N�mero de fontes

U = zeros(N, length(teta));
for cn = 1:N
    U(cn, :) = abs(sum(diag(W(cn, :)) * exp(i*2*pi*f*c*d*cos(teta)), 1));
end