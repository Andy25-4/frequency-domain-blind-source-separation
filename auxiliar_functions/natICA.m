function [y, w, evol_w, nit] = natICA(x, varargin)
% NATURAL ICA: [y, w, evol_w, nit] = natICA(x, varargin)
% 
% w -> matriz de separa��o
% y -> fontes separadas
% evol_w -> evolu��o da matriz de separa��o com o tempo, as itera��es est�o
% na 3� dimens�o
% nit -> n�mero de itera��es para convergir
%
% x -> matriz de misturas (cada linha � uma mistura)
%
%       Properties:
%
%               'InitSepMat' - matriz de separa��o inicial (default matriz
%                              identidade)
%               'InitSourceSig' - sinal de fontes inicial (default igual �
%                                 InitSepMat*x)
%               'ScoreFunction' - "score" function, pode ser
%                       'sign' (equivalente a tanh com shape parameter alto)
%                       'tanh'
%                       'genGaussian'
%                       'genLaplace'
%               'eta' - passo de adapta��o do gradiente natural(default .2)
%               'MaxIter' - n�mero de itera��es m�ximo
%               'estFuncDev' - desvio padr�o estimado da fun��o densidade de
%                              probabilidade do sinal y. A 'ScoreFunction'
%                              � derivada desta densidade. Veja abaixo para
%                              saber como esta vari�ncia altera cada uma
%                              das 'ScoreFunction'. O default � 1
%               'nonHolonomic' - utiliza o Natural ICA modificado por
%                                Cichocki
%
%           USANDO TANH
%               'estFuncDev' - a fun��o � tanh(y/DEV^2), onde DEV � a
%                              'estFuncDev'
%
%           USANDO SIGN
%               'estFuncDev' - a fun��o � sign(y)/DEV
%
%           USANDO GENERALIZED GAUSSIAN
%               'estFuncDev' - a fun��o � (|y|^(r-1) / DEV^r)*sign(y)
%
%               'gaussExp' - o expoent 'r' da fun��o acima. O default �
%                            0.5, ou seja, uma distribui��o Gamma
%
%           USANDO GENERALIZED LAPLACE
%               'estFuncDev' - a fun��o � 0.5 / (DEV*sqrt( |y|^2 + a ))
%
%               'laplaceShape' - o par�metro 'a' da fun��o acima. O default �
%                                0.1
%
% SOMENTE RESOLVE , POR ENQUANTO, COM O MESMO N�MERO DE FONTES QUE MISTURAS


%           N�O-IMPLEMENTADO
%
%           USANDO PEARSON
%               'PearsonCoefs' - vetor de 5 elementos contendo b0, b1, c0,
%                               c1 e c2, nesta ordem; ser� ignorado se a 
%                               score for 'adaptPearson'
%
%           USANDO ADAPTIVE PEARSON
%               'InitSourceSig' � OBRIGAT�RIO, mas a fun��o funcionar� sem,
%                               por�m dando resultados falsos
%               'PearsonType' - tipo de distribui��o Pearson. Pode ser
%                               1(default), 4 ou 6

%% Processando as entradas e sa�das
if nargout > 2,     save_progress = 1;
else                save_progress = 0;                              end

N = size(x, 1);
I = eye(N);

if numel(varargin)

    ind_arg1 = find( strcmp('ScoreFunction', varargin) , 1);
    ind_arg2 = find( strcmp('eta', varargin) , 1);
    ind_arg3 = find( strcmp('MaxIter', varargin) , 1);
    ind_arg4 = find( strcmp('estFuncDev', varargin) , 1);
%    ind_arg5 = find( strcmp('PearsonCoefs', varargin) , 1);
    ind_arg6 = find( strcmp('InitSepMat', varargin) , 1);
    ind_arg7 = find( strcmp('InitSourceSig', varargin) , 1);
%    ind_arg8 = find( strcmp('PearsonType', varargin) , 1);
    ind_arg9 = find( strcmp('gaussExp', varargin) , 1);
    ind_arg10 = find( strcmp('nonHolonomic', varargin) , 1);
    ind_arg11 = find( strcmp('laplaceShape', varargin) , 1);
     
    if ~isempty(ind_arg1),  score = varargin{ind_arg1 + 1};
    else                    score = 'tanh';                         end
    if ~isempty(ind_arg2),  eta = varargin{ind_arg2 + 1};
    else                    eta = .2;                               end
    if ~isempty(ind_arg3),  Max_It = varargin{ind_arg3 + 1};
    else                    Max_It = 250;                           end
    if ~isempty(ind_arg4),  est_dev = varargin{ind_arg4 + 1};
    else                    est_dev = 1;                            end
%    if ~isempty(ind_arg5),  coefs = varargin{ind_arg5 + 1};         end
    if ~isempty(ind_arg6),  w = varargin{ind_arg6 + 1};
    else                    w = I;                                  end % LIMITA NUMERO DE FONTES IGUAL NUMERO DE MISTURAS
    if ~isempty(ind_arg7),  y = varargin{ind_arg7 + 1};
    else                    y = w*x;                                end
%    if ~isempty(ind_arg8),  pears_dist = varargin{ind_arg8 + 1};
%    else                    pears_dist = 1;                         end
    if ~isempty(ind_arg9),  r_gauss = varargin{ind_arg9 + 1};
    else                    r_gauss = 0.5;                          end
    if ~isempty(ind_arg10), nonholonomic = true;
    else                    nonholonomic = false;                   end
    if ~isempty(ind_arg11), a_laplace = varargin{ind_arg11 + 1};
    else                    a_laplace = 0.1;                        end
    
else
    % DEFAULT
    score = 'sign';
    nonholonomic = false;
    est_dev = 1;
    eta = .2;
    Max_It = 250;
    w = I;
    y = w*x;
end

if r_gauss <= 0
    error('NATURAL ICA - O ''r'' da fun��o Gaussian deve ser maior que 0')
end

%% Inicializa��o

%epsilon = min(x, [], 2); % Fator para evitar divis�es por zero  FALTA TRATAR  FALTA TRATAR  FALTA TRATAR  FALTA TRATAR  FALTA TRATAR  FALTA TRATAR  FALTA TRATAR 

size_errwin = 8; % Tamanho da janela utilizada para testar converg�ncia (default 8 amostras) FUTURO PAR�METRO ???? FUTURO PAR�METRO ???? FUTURO PAR�METRO ????
err_thre = 0.01;  % Threshold do erro para teste de converg�ncia (default 0.01) FUTURO PAR�METRO ???? FUTURO PAR�METRO ???? FUTURO PAR�METRO ????
err_w = zeros(size_errwin, N, N);

% Retorna um n�mero que diz o tipo de 'score function' 
score_cell = {'tanh'; 'Pearson'; 'adaptPearson'; 'sign'; 'genGaussian'; 'genLaplace'};
tmp = [1; 2; 3; 4; 5; 6];
score_type = tmp(strcmp(score, score_cell));

if isempty(score_type)
    error('NATURAL ICA - ''Score Function'' desconhecida')
end

g_tan = 1/est_dev^2;
g_sign = 0.5/est_dev;
g_gauss = 1/est_dev^r_gauss;
g_laplace = 0.5/est_dev;

num_of_samples = size(x, 2);

if save_progress,       evol_w = zeros(Max_It, N, N);               end  % LIMITA NUMERO DE FONTES IGUAL NUMERO DE MISTURAS

%% Natural ICA
for it = 1:Max_It
    mod_y = abs(y);
 
%% N�O-IMPLEMENTADO
%
%    %% Pr�-c�lculos de Pearson
%    if score_type == 3
%        media = mean(mod_y(1,:));
%        vari = var(mod_y(1,:));
%        skew = skewness(mod_y(1,:));
%        skew2 = skew^2;
%        kurt = kurtosis(mod_y(1,:));
%        
%        if pears_dist == 1
%            rP = 6*(kurt - skew2 - 1)/(6 + 3*skew2 - 2*kurt);
%            r3P = 0.5*rP + 0.5*rP*(rP+2)*sqrt(skew2/(skew2*(rP+2)^2 + 16*(rP+1)));
%            r4P = 0.5*rP - 0.5*rP*(rP+2)*sqrt(skew2/(skew2*(rP+2)^2 + 16*(rP+1)));
%            if skew >= 0
%                qP = max([r3P r4P]);    pP = min([r3P r4P]);
%            else
%                qP = min([r3P r4P]);    pP = max([r3P r4P]);
%            end
%            bP = (pP + qP)*sqrt(vari*(pP + qP + 1)/(pP*qP));
%            aP = media - bP*pP/(pP + qP);
%
%            coefs(1) = -(pP + qP - 2)*aP - (pP - 1)*bP;
%            coefs(2) = pP + qP - 2;
%            coefs(3) = aP*(aP + bP);
%            coefs(4) = -(2*aP + bP);
%            coefs(5) = 1;
%            
%        elseif pears_dist == 4
%            bP = (9 + 6*skew2 - 5*kurt)/(6 + 3*skew2 - 2*kurt);
%            tauP = 0.5*sqrt(vari*(4*(2*bP - 3) - skew2*(bP - 2)^2));
%            deltaP = sqrt(vari)*skew*(bP - 1)*(bP - 2)/(2*bP*tauP);
%            muP = media - bP*deltaP*tauP/(bP - 1);
%            
%            coefs(1) = -2*bP*muP - 2*bP*tauP*deltaP;
%            coefs(2) = 2*bP;
%            coefs(3) = tauP^2 - muP^2;
%            coefs(4) = -2*muP;
%            coefs(5) = 1;
%            
%        elseif pears_dist == 6
%            rP = 6*(kurt - skew2 - 1)/(6 + 3*skew2 - 2*kurt);
%            r1P = 0.5*(rP-2) + 0.5*rP*(rP+2)*sqrt(skew2/(skew2*(rP+2)^2 + 16*(rP+1)));
%            r2P = 0.5*(rP-2) - 0.5*rP*(rP+2)*sqrt(skew2/(skew2*(rP+2)^2 + 16*(rP+1)));
%            betaP = max([r1P r2P]) + 1;
%            cP = -min([r1P r2P]) - betaP;
%            alfaP = sqrt(vari*(cP - 1)^2*(cP - 2)/((cP + betaP - 1)*betaP));
%            if skew >= 0,   aP = media - alfaP*betaP/(cP - 1);
%            else            aP = media + alfaP*betaP/(cP - 1);      end
%            
%            coefs(1) = (cP + 1)*aP + (betaP - 1)*alfaP;
%            coefs(2) = (cP + 1);
%            coefs(3) = aP*(aP - alfaP);
%            coefs(4) = -(2*aP - alfaP);
%            coefs(5) = 1;
%            
%        else
%            error('Pearson Distribution Type deve ser 1, 4 ou 6!')
%        end
%    end


    % A fun��o g(Y), a 'score' function, deve ser aplicada da seguinte
    % forma: (g(|Y|)/|Y|)* Y, pois a opera��o g(Y) � somente no m�dulo do 
    % n�mero complexo, i.e, a fase deve se manter
    
    %% TANH
    if score_type == 1          % Utilizando tanh
        phi = ( tanh( g_tan*mod_y ) ./ mod_y ) .* y;
        %phi = complex(tanh( g_tan*real(y) ), tanh( g_tan*imag(y) ));
 
     %% N�O-IMPLEMENTADO
%    %% PEARSON
%    elseif (score_type == 2) || (score_type == 3)     % Utilizando Pearson
%        phi = ( ((coefs(1) + coefs(2)*mod_y)./(coefs(3) + coefs(4)*mod_y + coefs(5)*mod_y.^2)) ./ mod_y ) .* y;
        
    %% SIGN
    elseif score_type == 4      % Utilizando sign
        phi = g_sign*y ./ mod_y;
        %phi = complex(g_sign*sign(real(y)), g_sign*sign(imag(y)));

    %% GENERALIZED GAUSSIAN
    elseif score_type == 5      % Utilizando Generalized Gaussian. Como a fun��o deve ser dividida por |Y| (ver acima), est� simplificada
        phi = ( g_gauss*(mod_y).^(r_gauss-2) ) .* y;

    %% GENERALIZED LAPLACE
    elseif score_type == 6
        phi = (g_laplace*y) ./ sqrt((mod_y).^2 + a_laplace);
        %phi = complex( (g_laplace*real(y)) ./ sqrt(real(y).^2 + a_laplace), (g_laplace*imag(y)) ./ sqrt(imag(y).^2 + a_laplace) );
        
    end
    
    if nonholonomic,    deltaw = eta*(diag(diag(phi * y')) / num_of_samples - phi * y' / num_of_samples)*w;
    else                deltaw = eta*(I - phi * y' / num_of_samples)*w; end
    
    %% Descobrindo a converg�ncia
    % Utilizei uma janela de tamanho size_errwin para salvar os �ltimos
    % erros e(w), onde e(w) = |w_atual| - |w_anterior|. Perceba que valores
    % negativos de e(w) s�o permitidos.
    ant_w = abs(w);                 
    w = w + deltaw;
    err_w(mod(it-1, size_errwin)+1, :, :) = abs(w) - ant_w;

    % Testa se sum(e(w)) � menor que um err_thre. Se o erro e(w) estiver
    % oscilando, o que � comum se convergiu, ent�o a soma de e(w) dentro de
    % uma janela ser� bem pr�ximo de zero.
    if it > size_errwin % Aguarda a janela encher
        if isempty(find( sum(err_w, 1) > err_thre, 1 )),    break;      end
    end
    
    if save_progress,       evol_w(it, :, :) = w;                   end
    
    y = w * x;
end

nit = it;

%% Subfunction (pode ser utilizada no futuro)
% Calculates tanh simplier and faster than Matlab tanh.
%function y=tanh(x)
%y = 1 - 2 ./ (exp(2 * x) + 1);
