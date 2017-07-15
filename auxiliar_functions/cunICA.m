function [y, u, evol_u, nit] = cunICA(z, type, Max_It)
% COMPLEX UNITARY ICA:  [y, u, evol_u] = cunICA(x)
%                       [y, u, evol_u] = cunICA(x, type, Max_It)
% u -> matriz de separa��o unit�ria
% y -> fontes separadas
% evol_u -> evolu��o da matriz de separa��o com o tempo, as itera��es est�o
% na 3� dimens�o
% nit -> n�mero de itera��es para convergir
%
% z -> matriz de misturas (cada linha � uma mistura)
% type -> fun��o G a utilizar. 1 - genLaplace
% Max_It -> numero m�ximo de itera��es
%
% SOMENTE RESOLVE , POR ENQUANTO, COM O MESMO N�MERO DE FONTES QUE MISTURAS

%% Processando as entradas e sa�das
if nargout > 2,     save_progress = 1;
else                save_progress = 0;                              end
    
if nargin < 3
    Max_It = 250;
    if nargin < 2
        type = 1;
    end
end

%% Inicializa��o
N = size(z, 1);
num_of_samples = size(z, 2);

u = eye(N);
y = z;
alpha = 0.1;

convergence_test = true;
Min_It = 8; % N�mero de itera��es a partir do qual se testa a converg�ncia
err_thre = 0;  % Threshold do erro para teste de converg�ncia (default 0)
err_u = zeros(N,1);

% A densidade estimada das fontes � p(x) = C*exp( -(sqrt(abs(x)^2 + alpha) / b) )
% C n�o � importante, e b � a vari�ncia, que somente afeta a escala do
% sinal, que � ajustada depois em um FDBSS.
% Portanto, a densidade fica
%       p(x) = exp(-sqrt(abs(x)^2 + alpha))

if save_progress,       evol_u = zeros(Max_It, N, N);               end  % LIMITA NUMERO DE FONTES IGUAL NUMERO DE MISTURAS

%% Fast ICA
for it = 1:Max_It
    mod_y2 = y.*conj(y);
    ant_u = u;
    
    switch type
        case 1
        % Encontrando as fun��es g(y) e g'(y)
        tmp = 0.5 ./ sqrt(mod_y2 + alpha);
        phi = tmp .* y; % na verdade � tmp .* conj(y), mas fazendo desta forma n�o precisamos encontrar phi(y)
        gg = tmp .* (1 - 0.5*mod_y2 ./ (mod_y2 + alpha));

        % Encontrando a matriz gamma e phi(y), que � igual conj(g), da� se
        % torna desncess�rio
        gamma = diag( sum(gg, 2) / num_of_samples );
    end
    
    % Atualizando a matriz de separa��o u
    u = gamma * u - phi * z' / num_of_samples;
    
    % Ajustando para uma matriz unit�ria
    u = (u*u')^(-1/2) * u;
    
    if convergence_test
        %% Descobrindo a converg�ncia
        % Basta testar se o produto interno do vetor atual e o antigo � 1,
        % pois isto significa que eles apontam na mesma dire��o
        for cn = 1:N
            err_u(cn) = abs(u(cn, :) * ant_u(cn, :)');
        end
        
        % Como cada vetor � unit�rio, o produto interno n�o pode ser maior
        % que 1. Se n�o existir mais nenhum valor menor do que 1, sai do
        % loop. Espero um n�mero m�nimo de itera��es.
        if it > Min_It
            if ~sum(err_u < (1 - err_thre)),                  break;      end
        end
        
    end
    
    if save_progress,       evol_u(it, :, :) = u;                   end
    
    y = u * z;
end

nit = it;
