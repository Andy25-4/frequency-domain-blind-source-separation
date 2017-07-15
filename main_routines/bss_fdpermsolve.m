function [P ind_solve] = bss_fdpermsolve(W, Y, varargin)
%
%   P = bss_fdpermsolve(W, Y)
%
%   W - Matriz com 3 dimens�es, onde a 3� dimens�o � a das frequ�ncias, e
%   as linhas e colunas s�o os coeficientes da matriz de desmistura. Cada
%   linha corresponde aos coeficientes das misturas que gerar�o uma fonte
%
%   Y - Matriz com as sa�das, ou seja, W*X, onde X � a matriz das misturas,
%   em cada frequ�ncia. Cada linha � uma fonte, cada coluna � um frame,
%   e a 3� dimens�o � a das frequ�ncias
%
%   O tamanho da FFT deve ser par!!!
%
%       Properties:
%               'Method' - modifica o m�todo de resolver o problema da
%               permuta��o. Pode ser:
%                   'tdoa'
%                   'conjcorr' (default)
%                   'harmcorr'
%                   'globalcorr'
%                   'doa'
%                   'doa_adjcorr'
%                   'doa_harmcorr'
%                   'doa_conjcorr'
%                   'supervised' - necessita do sinal da fonte
%                   'maxsir' - necessita do sinal da fonte em cada sensor
%
%               'useSymmetry' - explora a simetria da FFT, se existir. Por
%               default, n�o explora a simetria.
%
%           USANDO DOA
%               'DoaThreshold' - diferen�a m�xima entre o �ngulo 
%               encontrado no DOA para uma frequ�ncia e a m�dia dos �ngulos
%               para determinar se a medida � confi�vel. O padr�o �
%               1.5*std(teta).
%
%               'DirPatternThreshold' - diferen�a m�nima entre os
%               'directivity patterns' dos �ngulos das fontes, em dB.
%
%               'DistanceBetweenSensors' - dist�ncia entre os microfones
%               para utilizar no m�todo DOA, em metros. OBRIGAT�RIO
%
%               'SampFrequency' - frequ�ncia de amostragem.
%
%           USANDO TDOA
%
%               'useSymmetry' � OBRIGAT�RIO
%
%               'MaxDistBetweenSensors' - dist�ncia m�xima entre os microfones
%               para utilizar no m�todo TDOA, em metros. Utilizada apenas
%               para limitar as frequ�ncias onde a t�cnica � aplicada. Se
%               for omitida, n�o h� limite.
%
%           USANDO CORRELA��O
%               'NumAdjFrequencies' - n�mero de frequ�ncias adjacentes
%               utilizadas no m�todo da correla��o, para um lado e para o
%               outro. A dist�ncia (em Hz) � igual a
%                   NumAdjFrequencies*fs/Nfreqs, onde Nfreqs=size(W, 1)
%               e o n�mero total de frequ�ncias � igual a 
%                   2*NumAdjFrequencies
%               O padr�o � 3
%
%               'CorrThreshold' - valor m�nimo de correla��o para que o
%               m�todo de correla��o seja confi�vel. S� � aplic�vel se
%               tamb�m estiver sendo utilizado o m�todo de correla��o
%               harm�nica. O padr�o � 
%                   Nfontes*NumAdjFrequencies, onde Nfontes=size(W, 2)
%
%               'HarmonicThreshold' - valor m�nimo de correla��o para que o
%               m�todo de correla��o harm�nica seja confi�vel. O padr�o �
%                   Nfontes*NumHarmFrequencies*0,5
%
%               'Envelope' - tipo de envelope, 'AbsValue', 'PowValue',
%                            'PowValue2'
%
%           USANDO MODO SUPERVISIONADO
%               'SourceSignal' - sinal original da fonte, no mesmo formato
%               de Y, ou seja, a dimens�o 3 � a das frequ�ncias, e cada
%               linha � o sinal de uma fonte
%
%           USANDO MODO MAXSIR
%               'MicSourceComponents' - sinal com os sinais originais das
%               fontes, assim como vistos em cada microfone, ou seja, ap�s
%               passar pela fun��o de transfer�ncia da sala. O formato � o
%               mesmo de Y, mas a dimens�o 2 (as linhas) � distribu�da da 
%               seguinte forma: 
%               linha(1)            Source1_in_Mic1 
%               linha(2)            Source1_in_Mic2
%                                       ...
%               linha(M)            Source1_in_MicM
%               linha(M+1)          Source2_in_Mic1 
%               linha(M+2)          Source2_in_Mic2
%                                       ...
%               linha(2*M)          Source2_in_MicM
%                                       ...
%               linha[(N-1)*M+1]    SourceN_in_Mic1 
%               linha[(N-1)*M+2]    SourceN_in_Mic2
%                                       ...
%               linha(N*M)          SourceN_in_MicM

%% Inicializa��o
debug = 1;

global SPEED_OF_SOUND
SPEED_OF_SOUND = 343;
KMEANS_FACTOR = 0.5;
KMEANS_MAXITER = 5;
tdoa_cluster = 'custom';

K = size(W, 1); % N�mero de bins de frequ�ncia
N = size(W, 2); % N�mero de fontes
M = size(W, 3); % N�mero de misturas
num_of_frames = size(Y, 3);
c_ind_solve = 1; % �ndice da sa�da


%% Processando as entradas e sa�das
if numel(varargin)

    ind_arg1 = find( strcmp('Method', varargin) , 1);
    ind_arg2 = find( strcmp('DistanceBetweenSensors', varargin) , 1);
    ind_arg3 = find( strcmp('SourceSignal', varargin) , 1);
    ind_arg4 = find( strcmp('DoaThreshold', varargin) , 1);
    ind_arg5 = find( strcmp('SampFrequency', varargin) , 1);
    ind_arg6 = find( strcmp('NumAdjFrequencies', varargin) , 1);
    ind_arg7 = find( strcmp('CorrThreshold', varargin) , 1);
    ind_arg8 = find( strcmp('HarmonicThreshold', varargin) , 1);
    ind_arg9 = find( strcmp('MicSourceComponents', varargin) , 1);
    ind_arg10 = find( strcmp('useSymmetry', varargin) , 1);
    ind_arg11 = find( strcmp('DirPatternThreshold', varargin) , 1);
    ind_arg12 = find( strcmp('MaxDistBetweenSensors', varargin) , 1);
    ind_arg13 = find( strcmp('Envelope', varargin) , 1);
     
    if ~isempty(ind_arg1),      method = varargin{ind_arg1 + 1};
    else                        method = 'conjcorr';                end
    if ~isempty(ind_arg2),      d = varargin{ind_arg2 + 1};         end
    if ~isempty(ind_arg3),      S = varargin{ind_arg3 + 1};         end
    if ~isempty(ind_arg4),      doa_thre = varargin{ind_arg4 + 1};  
    else                        doa_thre = 0;                       end
    if ~isempty(ind_arg5),      fs = varargin{ind_arg5 + 1};        end
    if ~isempty(ind_arg6),      corr_neighbor_freq = varargin{ind_arg6 + 1};
    else                        corr_neighbor_freq = 3;             end
    if ~isempty(ind_arg7),      corr_thre = varargin{ind_arg7 + 1};
    else                        corr_thre = N * corr_neighbor_freq; end  %%%%% ARRUMAR %%%%%%%%%%%%%%
    if ~isempty(ind_arg8),      harmonic_thre = varargin{ind_arg8 + 1};
    else                        harmonic_thre = 0;                  end  %%%%% ARRUMAR %%%%%%%%%%%%%%
    if ~isempty(ind_arg9),      Q = varargin{ind_arg9 + 1};         end
    if ~isempty(ind_arg10),     unique_K = K/2 + 1; % N�mero de bins �nicos
    else                        unique_K = K;                       end
    if ~isempty(ind_arg11),     u_thre = varargin{ind_arg11 + 1};   
    else                        u_thre = -Inf;                      end
    if ~isempty(ind_arg12),     dmax = varargin{ind_arg12 + 1};   
    else                        dmax = 0;                           end
    if ~isempty(ind_arg13),     env_str = varargin{ind_arg13 + 1};
    else                        env_str = 'AbsValue';               end    

else
    % DEFAULT
    method = 'conjcorr';
    corr_neighbor_freq = 3;
    env_str = 'AbsValue';
end

switch env_str
    case 'AbsValue',        env_type = 1;
    case 'PowValue',        env_type = 2;
    case 'PowValue2',       env_type = 3;
    case 'SPDValue',        env_type = 4;
end


%% Mais inicializa��o
must_do_doa = false;
doa_no_tests = false;
global_corr_last = false;
must_do_tdoa = false;
must_do_envprecalc = false;
must_do_precalc = false;
must_do_adjprecalc = false;
must_do_corrprecalc = false;
must_do_corr = false;
must_do_localcorr = false;
must_do_harmonic = false;
must_do_precorr = false;
must_do_globalcorr = false;
must_do_supervised = false;
must_do_maxSIR = false;
corr_conf_condition = false;

poss_perms = perms(1:N); % Cada linha � uma permuta��o poss�vel
n_perms = size(poss_perms, 1); % N�mero de permuta��es

P = (1:N).' * ones(1, K); % Matriz de permuta��o. Cada coluna � uma permuta��o
Ptmp = (1:N).' * ones(1, unique_K); % Matriz de permuta��o tempor�ria. Por enquanto, � igual a P nas frequ�ncias confi�veis e diferente nas
                                    % n�o-confi�veis. Futuramente, � melhor que seja v�lida apenas dentro de cada m�todo.
                                    % MODIFICAR  MODIFICAR  MODIFICAR MODIFICAR  MODIFICAR  MODIFICAR MODIFICAR  MODIFICAR  MODIFICAR MODIFICAR 
ind_conf = logical(false(1, unique_K));
envY = zeros(unique_K, N, num_of_frames);

%% Escolha do m�todo
switch lower(method)
    case 'conjcorr'
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_corr = true;
        ind_solve = cell(1,1);

    case 'globalcorr'
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_globalcorr = true;
        global_corr_last = true;
        ind_solve = cell(1,1);
        
    case 'localcorr'
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_localcorr = true;
        ind_solve = cell(1,1);

    case 'allcorr'
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_globalcorr = true;
        must_do_localcorr = true;
        ind_solve = cell(1,1);
        
    case 'doa'
        must_do_doa = true;
        doa_no_tests = true;
        ind_solve = cell(1,1);
        
    case 'doa_adjcorr'
        must_do_doa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_adjprecalc = true;
        must_do_corr = true;
        corr_conf_condition = true;
        ind_solve = cell(2,1);
        
    case 'doa_harmcorr'
        must_do_doa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_adjprecalc = true;
        must_do_precorr = true;
        must_do_harmonic = true;
        must_do_corr = true;
        corr_conf_condition = true;
        ind_solve = cell(4,1);

    case 'harmcorr'
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_adjprecalc = true;
        must_do_precorr = true;
        must_do_harmonic = true;
        must_do_corr = true;
        corr_conf_condition = true;
        ind_solve = cell(3,1);
        
    case 'tdoa_conjcorr'
        must_do_tdoa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_corr = true;
        corr_conf_condition = true;
        ind_solve = cell(2,1);
    
    case 'doa_conjcorr'
        must_do_doa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_corr = true;
        corr_conf_condition = true;
        ind_solve = cell(2,1);
 
    case 'doa_globalcorr'
        must_do_doa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_globalcorr = true;
        global_corr_last = true;
        ind_solve = cell(2,1);
        
    case 'doa_allcorr'
        must_do_doa = true;
        must_do_envprecalc = true;
        must_do_precalc = true;
        must_do_corrprecalc = true;
        must_do_globalcorr = true;
        must_do_localcorr = true;
        ind_solve = cell(2,1);
        
    case 'tdoa'
        must_do_tdoa = true;
        ind_solve = cell(1,1);
        
    case 'supervised'
        must_do_supervised = true;
        ind_solve = cell(1,1);
        
    case 'maxsir'
        must_do_maxSIR = true;
        ind_solve = cell(1,1);
end

%% Envelope
if must_do_envprecalc
    if debug
        disp('--- Pr�-c�lculos do envelope para os m�todos de correla��o:')
    end
    
    for k = 1:unique_K
        Ytmp(:, :) = Y(k, :, :);
        envY(k, :, :) = envelope(Ytmp, env_type, squeeze(W(k, :, :)));
    end
    
end

%% DOA
if must_do_doa
    if debug
        disp('--- M�todo DOA (Direction of Arrival):')
    end
    
    freq = [0 : fs/K : (fs/K)*(K/2-1), -fs/2 : fs/K : -fs/K];
    mics = -(M-1)*d/2 : d : (M-1)*d/2;
    teta = zeros(N, unique_K);
    
    for k = find(~ind_conf)
        teta(:, k) = doa( squeeze(W(k, :, :)), d, freq(k) );
        [teta(:, k), Ptmp(:, k)] = sort(teta(:, k), 'ascend');
    end

    % Testa se o �ngulo pode ser encontrado
    ind_conf(sum(isnan(teta), 1) == 0) = true;
    mteta = median(teta(:, ind_conf), 2);
    
    if(~doa_thre), doa_thre = std( teta(:, ind_conf), 0, 2) * 1.5;  end
    
    % Testa se o �ngulo encontrado � pr�ximo da m�dia dos �ngulos
    if ~doa_no_tests
        for k = find(ind_conf)
            if sum( abs(teta(:, k) - mteta) > doa_thre) > 0
                ind_conf(k) = false;
            end
        end
    end
    
    % Testa se o SIR entre os "directivy pattern" dos �ngulos das fontes �
    % alto
    if ~doa_no_tests
        for k = find(ind_conf)
            Wtmp = squeeze(W(k, Ptmp(:, k), :)); % Ajusta a permuta��o de W

            % A fun��o abaixo tem dimens�o num_fontes x num_fontes. Cada linha
            % representa o "directivity pattern" em db de uma das fontes para os
            % �ngulos estimados para todas as fontes. A diagonal principal
            % representa a amplitude U de uma fonte no �ngulo estimado para
            % ela, e os elementos fora da diagonal principal representam a
            % amplitude U desta fonte em outros �ngulos, que devem ser
            % maiores, se a estimativa estiver correta (a diagonal
            % principal � o m�nimo)
            fun = 10*log10( dirpattern( Wtmp, mics, freq(k), teta(:, k).' ).^2 );

            fun = sum(sum(triu(fun, 1))) + sum(sum(tril(fun, -1))) - trace(fun);
            if(fun < u_thre)
                ind_conf(k) = false;
            end
        end
    end

    P(:, ind_conf) = Ptmp(:, ind_conf);
    
    % Atualizando as matrizes
    for k = find(ind_conf)
        W(k, :, :) = W(k, P(:, k), :);
        envY(k, :, :) = envY(k, P(:, k), :);
    end
    
    ind_solve{c_ind_solve} = ind_conf;
    c_ind_solve = c_ind_solve + 1;
    
    if debug
        disp( sprintf('N�mero de bins resolvidos: %.0f', sum(ind_conf)) )
        disp('Desvio Padr�o dos �ngulos estimados (em radianos):')
        disp(doa_thre/1.5)
        disp('�ngulos encontrados (em graus):')
        disp(mteta*180/pi)
    end
end

%% TDOA
if must_do_tdoa
    if debug
        disp('--- M�todo TDOA (Time Difference of Arrival):')
    end
    
    freq = [0 : fs/K : (fs/K)*(K/2-1), -fs/2 : fs/K : -fs/K];

    % Se a condi��o abaixo for verdadeira, o TDOA funciona para todas as
    % frequ�ncias
    if dmax < SPEED_OF_SOUND/fs,         dmax = 0;                  end

    % Encontra a frequ�ncia at� a qual o algoritmo funciona
    if dmax,    ind_fmax = find(freq > SPEED_OF_SOUND/(2*dmax), 1) - 1;
    else        ind_fmax = length(ind_conf);                        end
    
    r = zeros(N, ind_fmax, M-1);
    ref_mic = 2;

    for k = 1:ind_fmax
        if ~ind_conf(k)
            r(:, k, :) = tdoa(squeeze(W(k, :, :)), ref_mic, freq(k));
        else
            r(:, k, :) = nan(N, M-1);
        end
    end
    
    ind_valid = false(size(ind_conf));
    ind_valid(~isnan(r(1, :, 1))) = true; % L�gico, 0 se nan, 1 se valor v�lido
    r = r(:, ind_valid, :); % Limpa a matriz 'r', para n�o dar Warning no kmeans
    
    map_freq2r = zeros(size(ind_valid));
    map_freq2r(ind_valid) = 1:size(r, 2); % map_freq2r cont�m zeros onde r era 'nan' Ex.: [0 0 1 2 3 0 4 5 6 7 0 8]
    freq_valid = find(ind_valid); % freq_valid diz os �ndices das frequ�ncias que n�o cont�m 'nan'
    switch lower(tdoa_cluster)
        case 'custom'
            perm = zeros(size(Ptmp));
            tmp = zeros(1, n_perms);
            tmp2 = zeros(N, M-1);
            tmpr = r; % Cont�m r depois de permutado. Serve para encontrar os centr�ides
            centr = zeros(N, M-1);
            converged = false;

            while(~converged)
                centr(:, :) = mean(tmpr, 2);  % Encontra os N centr�ides. A dimens�o � N x (M-1)
                
                for k = find(~ind_conf & ind_valid)
                    rk =  map_freq2r(k); % A frequ�ncia k � correspondente ao �ndice rk na matriz r 
                    if ~rk,              continue;       end % Se a frequ�ncia deu 'nan' no tdoa

                    % Testa as permuta��es e retorna a soma das dist�ncias
                    % de cada uma
                    for i = 1:n_perms
                        tmp2(:, :) = r(poss_perms(i, :), rk, :);
                        tmp(i) = sum(  sum((tmp2 - centr).^2, 2)  ); % A soma interna � a norma^2 da diferen�a entre os vetores
                    end

                    [dummy tmpind] = min(tmp); % A menor dist�ncia simboliza a permuta��o correta
                    perm(:, k) = poss_perms(tmpind, :).';
                end

                % Testando converg�ncia
                remaining_freqs = sum(sum(abs(perm(:, ~ind_conf & ind_valid) - Ptmp(:, ~ind_conf & ind_valid)), 1) ~= 0);
                if ~remaining_freqs
                    converged = true;
                end
                
                for k = find(~ind_conf & ind_valid)
                    Ptmp(:, k) = perm(:, k); % Atualiza Ptmp
                    tmpr(:, rk, :) = r(Ptmp(:, k), rk, :); % Permuta r de acordo com o resultado
                end
            end
            
%            r = permute(r, [1 3 2]);
%            cluster_sum = sum(  sum(bsxfun(@minus, r, centr).^2, 2)  , 3);
%            cluster_dist = squeeze(sum((bsxfun(@minus, r, centr)).^2, 2));
%            tdoa_thre = std( cluster_dist(:, ind_conf), 0, 2) * 1;
%            tdoa_conf = (sum(bsxfun(@gt, cluster_dist, tdoa_thre), 1) == 0);
            ind_conf(~ind_conf & ind_valid) = true;
            
        case 'kmeans'
            r = reshape(r, size(r, 1)*size(r, 2), M-1);
            
            cluster_valid = false;
            cc = 0;
            while ~cluster_valid && cc < KMEANS_MAXITER

                [dummy centr cluster_sum cluster_dist] = kmeans(r, N); % dist � uma matriz com o n�mero de linhas de r e N colunas

                cluster_valid = true;
                for cn = 1:N
                    if sum(dummy == cn) < KMEANS_FACTOR*(length(dummy)/N)
                        cluster_valid = false;
                    end
                end
                cc = cc + 1;
            end

            % Cada centr�ide simboliza uma fonte real
            tmpperm = zeros(N, 1);
            for cc = 1:length(freq_valid)
                tmpmat = cluster_dist((cc-1)*N + 1 : (cc-1)*N + N, :); % Matriz fontes permutadas x fontes reais

                for cn = 1:N
                    [dummy perm_srcs] = min(tmpmat); % Vetor linha com as fontes mais pr�ximas de cada centr�ide
                    [dummy real_src]= min(dummy); % Escalar com o �ndice do centr�ide com o menor valor, i.e, a fonte real  

                    tmpperm(perm_srcs(real_src)) = real_src; % Atualiza a permuta��o
                    tmpmat(perm_srcs(real_src), :) = inf(1,N); % Elimina a linha e coluna da matriz
                    tmpmat(:, real_src) = inf(N,1);
                end

                Ptmp(:, freq_valid(cc)) = tmpperm;
                ind_conf(freq_valid(cc)) = true; % MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR  MODIFICAR 
            end
            
    end

    % Atualizando as matrizes
    for k = find(ind_conf)
        P(:, k) = Ptmp(:, k);
        W(k, :, :) = W(k, P(:, k), :);
        envY(k, :, :) = envY(k, P(:, k), :);
    end
    
    ind_solve{c_ind_solve} = ind_conf;
    c_ind_solve = c_ind_solve + 1;
    
    if debug
        disp( sprintf('N�mero de bins resolvidos: %.0f', sum(ind_conf)) )
%        disp('Soma quadr�tica de cada cluster:')
%        disp(cluster_sum)
        disp('Centr�ides encontrados:')
        disp(centr)
    end
end

%% Pr�-c�lculos para otimiza��o
if must_do_precalc
    if debug
        disp('--- Pr�-c�lculos para otimiza��o:')
    end

    Ymean = zeros(N, unique_K);
    Yvar = zeros(N, unique_K);
    
    if debug
        disp('------ M�dias e Vari�ncias')
    end

    Ytmp = zeros(N, num_of_frames);
    for k = 1:unique_K
        Ytmp(:, :) = envY(k, :, :);
        Ymean(:, k) = mean(Ytmp, 2);
        Yvar(:, k) = var(Ytmp, 0, 2);
    end
end

%% Pr�-c�lculos para otimizar o m�todo de correla��o adjacente
if must_do_adjprecalc
    if debug
        disp('--- Pr�-c�lculos para agilizar o m�todo de correla��o de frequ�ncias adjacentes:')
    end

    Ycorr = repmat(struct( 'indFreqs', [], 'AdjFreqCorr', []), 1, unique_K);

    Ytmp = zeros(N, num_of_frames);
    Ytmp2 = zeros(N, num_of_frames);
    for k = find(~ind_conf)
        Ytmp(:, :) = envY(k, :, :);
        if(k <= K/2 + 1) % Se a frequ�ncia for positiva ou -fs/2 ( se 'useSymmetry' estiver habilitado, � necess�rio fazer isto. Se n�o estiver, como o envelope n�o depende da fase, envelope(Y_fs/2) = envelpe(Y_-fs/2) ))
            kk = getAdjInd(k, corr_neighbor_freq, 1, K/2 + 1);
        else% Se a frequ�ncia for negativa
            kk = getAdjInd(k, corr_neighbor_freq, K/2 + 1, unique_K);
        end            
        
        Ycorr(k).indFreqs = kk;
        Ycorr(k).AdjFreqCorr = zeros(length(kk), N, N);
        for i = 1:length(kk)
            Ytmp2(:, :) = envY(kk(i), :, :);
            Ycorr(k).AdjFreqCorr(i, :, :) = fast_corr2by2(Ytmp, Ytmp2, Ymean(:, k), Ymean(:, kk(i)), Yvar(:, k), Yvar(:, kk(i)));
        end
    end
    
end

%% Pr�-c�lculos para otimizar o m�todo de correla��o conjugada
if must_do_corrprecalc
    if debug
        disp('--- Pr�-c�lculos para agilizar o m�todo de correla��o de frequ�ncias:')
    end
    
    Ycorr = repmat(struct( 'indFreqs', [], 'AdjFreqCorr', []), 1, unique_K);

    Ytmp = zeros(N, num_of_frames);
    Ytmp2 = zeros(N, num_of_frames);
    for k = find(~ind_conf)
        Ytmp(:, :) = envY(k, :, :);
        if(k <= K/2 + 1) % Se a frequ�ncia for positiva ou -fs/2 ( se 'useSymmetry' estiver habilitado, � necess�rio fazer isto. Se n�o estiver, como o envelope n�o depende da fase, envelope(Y_fs/2) = envelpe(Y_-fs/2) ))
            kk = getCustomInd(k, corr_neighbor_freq, 1, K/2 + 1);
        else% Se a frequ�ncia for negativa
            kk = getCustomInd(k, corr_neighbor_freq, K/2 + 1, unique_K);
        end            
        
        Ycorr(k).indFreqs = kk;
        Ycorr(k).AdjFreqCorr = zeros(length(kk), N, N);
        for i = 1:length(kk)
            Ytmp2(:, :) = envY(kk(i), :, :);
            Ycorr(k).AdjFreqCorr(i, :, :) = fast_corr2by2(Ytmp, Ytmp2, Ymean(:, k), Ymean(:, kk(i)), Yvar(:, k), Yvar(:, kk(i)));
        end
    end
    
end

%% Correla��o global
if must_do_globalcorr
    if debug
        disp('--- Correla��o global:')
    end

    Ptmp = (1:N).' * ones(1, unique_K); % Inicializa Ptmp. Pesquisar uma forma melhor de fazer isso...
    perm = Ptmp;
    
    centY = zeros(N, num_of_frames);
    tmpenvY = envY; % Serve para calcular a m�dia
    Ytmp = zeros(N, num_of_frames);
    Ytmp2 = zeros(unique_K, num_of_frames);
    tmp = zeros(1, n_perms);
    converged = false;

    while(~converged)
        for cn = 1:N
            Ytmp2(:, :) = tmpenvY(:, cn, :);
            centY(cn, :) = mean(Ytmp2, 1);
        end
        centmean = mean(centY, 2);
        centvar = var(centY, 0, 2);

        for k = find(~ind_conf)
            Ytmp(:, :) = envY(k, :, :);
            tmpRf = fast_corr2by2(Ytmp, centY, Ymean(:, k), centmean, Yvar(:, k), centvar);

            for i = 1:n_perms
                tmp(i) = sum(diag(tmpRf(poss_perms(i, :), :)));
            end

            [dummy tmpind] = max(tmp);
            perm(:, k) = poss_perms(tmpind, :).';
        end

        % Testando converg�ncia
        remaining_freqs = sum(sum(abs(perm(:, ~ind_conf) - Ptmp(:, ~ind_conf)), 1) ~= 0);
        if ~remaining_freqs
            converged = true;
        end

        % Atualizando as matrizes
        for k = find(~ind_conf)
            Ptmp(:, k) = perm(:, k); % Atualiza Ptmp
            tmpenvY(k, :, :) = envY(k, Ptmp(:, k), :); % Permuta envY de acordo com o resultado
        end
    end

    % Atualizando as matrizes, se global_corr for o �ltimo m�todo
    if global_corr_last
        % Como � a �ltima, n�o precisa atualizar muita coisa
        for k = find(~ind_conf)
            ind_conf(k) = true;
            P(:, k) = Ptmp(:, k);
            W(k, :, :) = W(k, P(:, k), :);
        end
        
        ind_solve{c_ind_solve} = ind_conf;
        c_ind_solve = c_ind_solve + 1;
    end
    
end

%% Correla��o local
if must_do_localcorr
    if debug
        disp('--- Correla��o local:')
    end

    converged = false;
    tmp = zeros(N, N); % Vari�vel tempor�ria para evitar o uso de squeeze
    perm = Ptmp;
    
    while(~converged)
 
        for k = find(~ind_conf)

            tmpRf = zeros(1, n_perms);
            for i = 1:n_perms

                tmptmp = zeros(N, N);
                
                % As frequ�ncias adjacentes s�o fixadas segundo a
                % permuta��o atual, e a frequ�ncia k em quest�o � permutada
                for kk =  1:length(Ycorr(k).indFreqs)
                    tmp(:, :) = Ycorr(k).AdjFreqCorr(kk, poss_perms(i, :), :);
                    tmptmp = tmptmp + tmp( :, perm(:, Ycorr(k).indFreqs(kk)) );
                end
                tmpRf(i) = sum(diag(tmptmp));

            end
            
            % Permuta��o que obteve maior correla��o. Perceba que a
            % altera��o na matriz perm de uma frequ�ncia tamb�m altera a
            % correla��o das adjacentes com ela
            [dummy tmpind] = max(tmpRf);
            perm(:, k) = poss_perms(tmpind, :).';
            
        end

        % Testando converg�ncia
        remaining_freqs = sum(sum(abs(perm(:, ~ind_conf) - Ptmp(:, ~ind_conf)), 1) ~= 0);
        if ~remaining_freqs
            converged = true;
        end

        % Atualizando as matrizes
        for k = find(~ind_conf)
            Ptmp(:, k) = perm(:, k); % Atualiza Ptmp
        end

    end
    
    % Atualizando as matrizes.
    for k = find(~ind_conf)
        ind_conf(k) = true;
        P(:, k) = Ptmp(:, k);
        W(k, :, :) = W(k, P(:, k), :);
        envY(k, :, :) = envY(k, P(:, k), :);
        Ymean(:, k) = Ymean(P(:, k), k);
        Yvar(:, k) = Yvar(P(:, k), k);
        Ycorr(k).AdjFreqCorr = Ycorr(k).AdjFreqCorr(:, P(:, k), :);
        
        % Atualiza a correla��o das frequ�ncias adjacentes
        ind_changed = false(1, unique_K);
        ind_changed( getInvCustomInd(k, corr_neighbor_freq, 1, unique_K) ) = true;
        for kk = find(ind_changed)
            ind_adjchanged = find(Ycorr(kk).indFreqs == k);
            if isempty(ind_adjchanged),     continue;   end
            Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, :) = Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, P(:, k));
        end
    end
        
    ind_solve{c_ind_solve} = ind_conf;
    
end

%% Correla��o com Threshold
if must_do_precorr
    if debug
        disp('--- M�todo Correla��o de Frequ�ncias Adjacentes com Threshold:')
    end
    
    tmp = zeros(N, N); % Vari�vel tempor�ria para evitar o uso de squeeze
    ind_changed = true(1, unique_K); % Inicializa vari�vel como se todas as permuta��es de todas as frequ�ncias tivessem mudado
    Rf = zeros(1, unique_K);
    
    % Enquanto houverem �ndices n�o confi�veis
    while ~isempty(find(~ind_conf, 1))

        % Encontra a correla��o de todas as frequ�ncias de permuta��es n�o 
        % confi�veis com suas adjacentes. O l�gico ind_changed otimiza
        % bastante o loop s� encontrando a correla��o em frequ�ncias que
        % foram modificadas e suas adjacentes
        for k = find(~ind_conf & ind_changed)
            
            tmpRf = zeros(1, n_perms);
            ind_tmpconf = ind_conf(Ycorr(k).indFreqs);

            for i = 1:n_perms
                tmp(:, :) = sum(Ycorr(k).AdjFreqCorr(ind_tmpconf, poss_perms(i, :), :), 1);
                tmpRf(i) = sum(diag(tmp));
            end
            
            [Rf(k) tmpind] = max(tmpRf);
            Ptmp(:, k) = poss_perms(tmpind, :).';
        end
        
        [dummy tmpind] = max(Rf);
        
        if dummy > corr_thre
            ind_conf(tmpind) = true;
            P(:, tmpind) = Ptmp(:, tmpind);
            Rf(tmpind) = 0;
            
            % Serve para otimiza��o
            ind_changed = false(1, unique_K);
            ind_changed( getAdjInd(tmpind, corr_neighbor_freq, 1, unique_K) ) = true;

            % Ymean e Yvar n�o precisariam ser atualizadas, mas podem ser �teis
            % em alguma implementa��o futura
            W(tmpind, :, :) = W(tmpind, P(:, tmpind), :);
            envY(tmpind, :, :) = envY(tmpind, P(:, tmpind), :);
            Ymean(:, tmpind) = Ymean(P(:, tmpind), tmpind);
            Yvar(:, tmpind) = Yvar(P(:, tmpind), tmpind);
            Ycorr(tmpind).AdjFreqCorr = Ycorr(tmpind).AdjFreqCorr(:, P(:, tmpind), :);
            
            % Atualiza a correla��o das frequ�ncias adjacentes
            for kk = find(ind_changed)
                ind_adjchanged = find(Ycorr(kk).indFreqs == tmpind);
                if isempty(ind_adjchanged),     continue;   end
                Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, :) = Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, P(:, tmpind));
            end
        else
            break;
        end
    end

    ind_solve{c_ind_solve} = ind_conf;
    c_ind_solve = c_ind_solve + 1;
    
    if debug
        disp( sprintf('N�mero de bins resolvidos: %.0f\n', sum(ind_conf)) )
    end
end

%% Correla��o Harm�nica
if must_do_harmonic
    if debug
        disp('--- M�todo Correla��o de Frequ�ncias Harm�nicas:')
    end

    env_f = zeros(N, num_of_frames);
    
    % Encontra a correla��o de todas as frequ�ncias de permuta��es n�o confi�veis com
    % suas harm�nicas
    for k = find(~ind_conf)
        env_f(:, :) = envY(k, :, :);
        
        ind_harm = false(size(ind_conf));
        if(k <= K/2 + 1) % Se a frequ�ncia for positiva ou -fs/2
            ind_harm(getCustomHarmInd(k, 1, K/2 + 1)) = true;
        else
            ind_harm(getCustomHarmInd(k, K + 1, K/2 + 1)) = true;
        end
        env_g = envY(ind_harm & ind_conf, :, :);

        % Corre as frequ�ncias adjacentes encontrando as correla��es
        if isempty(env_g)
            continue; % Se n�o houver harm�nicos com permuta��o confi�vel
        else
            [Rf Ptmp(:, k)] = maxcorr(Ytmp, env_g);
        end

        if Rf > harmonic_thre
            ind_conf(k) = true;
            P(:, k) = Ptmp(:, k);
            W(k, :, :) = W(k, P(:, k), :);
            envY(k, :, :) = envY(k, P(:, k), :);
            Ymean(:, k) = Ymean(P(:, k), k);
            Yvar(:, k) = Yvar(P(:, k), k);
            Ycorr(k).AdjFreqCorr = Ycorr(k).AdjFreqCorr(:, P(:, k), :);
            
            % Atualiza a correla��o das frequ�ncias adjacentes            
            ind_changed = false(1, unique_K);
            ind_changed( getAdjInd(tmpind, corr_neighbor_freq, 1, unique_K) ) = true;
            for kk = find(ind_changed)
                ind_adjchanged = find(Ycorr(kk).indFreqs == k);
                if isempty(ind_adjchanged),     continue;   end
                Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, :) = Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, P(:, k));
            end
        
        end
    end

    ind_solve{c_ind_solve} = ind_conf;
    c_ind_solve = c_ind_solve + 1;

    if debug
        disp( sprintf('N�mero de bins resolvidos: %.0f\n', sum(ind_conf)) )
    end
end

%% Correla��o sem Threshold
if must_do_corr 
    if debug
        disp('--- M�todo Correla��o de Frequ�ncias Adjacentes sem Threshold:')
    end
    
    tmp = zeros(N, N); % Vari�vel tempor�ria para evitar o uso de squeeze
    ind_changed = true(1, unique_K); % Inicializa vari�vel como se todas as permuta��es de todas as frequ�ncias tivessem mudado
    Rf = zeros(1, unique_K);
    
    % Enquanto houverem �ndices n�o confi�veis
    while ~isempty(find(~ind_conf, 1))

        % Encontra a correla��o de todas as frequ�ncias de permuta��es n�o 
        % confi�veis com suas adjacentes. O l�gico ind_changed otimiza
        % bastante o loop s� encontrando a correla��o em frequ�ncias que
        % foram modificadas e suas adjacentes
        for k = find(~ind_conf & ind_changed)
            
            tmpRf = zeros(1, n_perms);
            ind_tmpconf = ind_conf(Ycorr(k).indFreqs);

            if (corr_conf_condition) % Se somente devem ser calculadas as somas de correla��es para frequ�ncias com permuta��o j� resolvida...
                for i = 1:n_perms
                    tmp(:, :) = sum(Ycorr(k).AdjFreqCorr(ind_tmpconf, poss_perms(i, :), :), 1);
                    tmpRf(i) = sum(diag(tmp));
                end
            else % ... ou n�o
                for i = 1:n_perms
                    tmp(:, :) = sum(Ycorr(k).AdjFreqCorr(:, poss_perms(i, :), :), 1);
                    tmpRf(i) = sum(diag(tmp));
                end
            end
            
            [Rf(k) tmpind] = max(tmpRf);
            Ptmp(:, k) = poss_perms(tmpind, :).';
        end
        
        [dummy tmpind] = max(Rf);
        ind_conf(tmpind) = true;
        P(:, tmpind) = Ptmp(:, tmpind);
        Rf(tmpind) = 0;
        
        % Serve para otimiza��o
        ind_changed = false(1, unique_K);
        ind_changed( getInvCustomInd(tmpind, corr_neighbor_freq, 1, unique_K) ) = true;
        
        % Ymean e Yvar n�o precisariam ser atualizadas, mas podem ser �teis
        % em alguma implementa��o futura
        W(tmpind, :, :) = W(tmpind, P(:, tmpind), :);
        envY(tmpind, :, :) = envY(tmpind, P(:, tmpind), :);
        Ymean(:, tmpind) = Ymean(P(:, tmpind), tmpind);
        Yvar(:, tmpind) = Yvar(P(:, tmpind), tmpind);
        Ycorr(tmpind).AdjFreqCorr = Ycorr(tmpind).AdjFreqCorr(:, P(:, tmpind), :);
        
        % Atualiza a correla��o das frequ�ncias adjacentes
        for kk = find(ind_changed)
            ind_adjchanged = find(Ycorr(kk).indFreqs == tmpind);
            if isempty(ind_adjchanged),     continue;   end
            Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, :) = Ycorr(kk).AdjFreqCorr(ind_adjchanged, :, P(:, tmpind));
        end

    end
    
    ind_solve{c_ind_solve} = ind_conf;

end

%% Supervisionado
if must_do_supervised
    if debug
        disp('--- M�todo Supervisionado (by Victorio):')
    end
    
    for k = find(~ind_conf)

        % Compara o sinal encontrado com o original para tentar descobrir
        % se houve permuta��o ou n�o. A maior correla��o corresponde �
        % permuta��o correta
        env_f = envelope( squeeze(Y(k, :, :)), 1 );
        env_g(1, :, :) = envelope( squeeze(S(k, :, :)), 1 );
        [dummy P(:, k)] = maxcorr(env_f, env_g);
        
    end
end

%% MAXSIR (do Makino)
if must_do_maxSIR
    if debug
        disp('--- M�todo MaxSIR (Supervisionado by Makino):')
    end
    
    for k = find(~ind_conf)

        % Utiliza o m�todo de Makino de encontrar o tra�o m�ximo de uma
        % fun��o (perm*W*Q).^2
        [dummy P(:, k)] = maxSIR(squeeze(W(k, :, :)), squeeze(Q(k, :, :)));
        
    end
end

%% C�lculos finais
% Por causa da simetria da FFT (se for utilizada)
for k = unique_K+1:K
    P(:,k) = P(:,K+2-k);
end

% Organizando a sa�da ind_solve
for i = length(ind_solve):-1:2
    ind_solve{i} = xor(ind_solve{i}, ind_solve{i-1});
end
    
clear global SPEED_OF_SOUND

%% Functions obsoletas

%{
function indArray = getHarmInd(f, N)
% indArray = getHarmInd(f, N) retorna os �ndices dos harm�nicos
% da frequ�ncia cujo �ndice � 'f'. Considera-se que o primeiro elemento do
% vetor de frequ�ncias corresponde � frequ�ncia 0, e o segundo, a fs/'N',
% onde fs � a frequ�ncia de amostragem e 'N' o n�mero de frequ�ncias (ou
% de bins da FFT), o terceiro, a (2*fs)/'N' e assim por diante.
%
% A sa�da � um vetor LINHA
%
% Exemplos:
% getHarmInd(1, 16) retorna o vetor [], pois o �ndice 1 corresponde �
%                   frequ�ncia 0, que n�o possui harm�nicos
% getHarmInd(2, 16) retorna o vetor [3 4 5 6 7 8 9 10 11 12 13 14 15 16], que
%                  corresponde ao vetor inteiro
% getHarmInd(5, 16) retorna o vetor [9 13]


if f == 1
    indArray = [];
else
     % O n�mero de harm�nicos que uma dada frequ�ncia possui � o n�mero de bins entre a frequ�ncia m�xima e o bin espec�fico (N-f),
     % dividido pelo tamanho do pulo do harm�nico, que no caso, � igual ao �ndice da frequ�ncia (f-1, pois quando f � 1 o �ndice � 0)
    num_harm = floor( (N-f) / (f-1) );
    harmArray = 2:num_harm+1;
    indArray = (f - 1) * harmArray + ones(1, length(harmArray)); % Os harm�nicos s�o (f-1)*2 + 1, (f-1)*3 + 1, (f-1)*4 + 1, e assim por diante.
end
%}