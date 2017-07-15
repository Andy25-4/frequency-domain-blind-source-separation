function [z,V] = pre_whitening(x)
%
% Fun��o que efetua um branqueamento dos dados via decomposi��o por autovalores
% Utilize a fun��o pre_centering antes dessa, sen�o a m�dia dos valores n�o
% ser� nula.
%
% Sintaxe:
%  [z,V] = pre_whitening(x)
% 
% Argumento de entrada:
%  x -> dados (possivelmente complexos, dispostos a cada linha) a serem branqueados 
% 
% Argumento de sa�da:
%  z -> dados branqueados
%  V -> matriz que efetua a transforma��o linear que branqueia x (z = V * x)

% �ltima modifica��o: 24/01/10 - corrigido bug do transpose
%                     07/07/10 - agora a m�dia do sinal branqueado � 0,
%                                utilizando a fun��o pre_centering

%% Inicializa��o
N = size(x,2);
M = size(x,1);
R = zeros(M);

%% C�lculo da matriz de covari�ncia
for ind = 1:N
    R = R + x(:,ind) * x(:,ind)'; % O operador ' j� representa transposi��o hermitiana, ou seja, usar tamb�m a fun��o conj � errado
end
 
R = R/N;

%% Autovalores (D) e Autovetores (E)
[E,D] = eig(R);
 
% Pondo em ordem decrescente os autovalores (ATEN��O: sup�e-se que n�o haja autovalores id�nticos)

[d ind] = sort(diag(D), 'descend');
D = diag(d);
E = E(:,ind);


%% Calculando a matriz de transforma��o
V = D^(-1/2) * E';
z = V * x;
