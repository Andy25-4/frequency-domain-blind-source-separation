%
% Implementa��o de BSS
%
% por Luiz Victorio de M. Laporte. Atualizado por Hian Castilho - 2017


% ---------- PAR�METROS
%   dist_mics - dist�ncia, em metros, entre os sensores
%   N - n�mero de fontes
%   M - n�mero de misturas
%   num_samp - n�mero de amostras a se ler de cada arquivo de som
%   K - comprimento da janela hann para realizar a STFT, i.e, n�mero de pontos da STFT
%   J - salto entre cada janela
%   winda - janela utilizada para a stft
%   winds - janela utilizada para a istft
%   Num_It - n�mero de itera��es
%   eta - passo de adapta��o do algoritmo natural ICA (.1 normalmente)
%   alfa - passo de adapta��o da fun��o score(tanh) do algoritmo natural ICA (10^4 normalmente)
%   sep_meth - m�todo utilizado para separa��o ('natica', 'natica_gauss', 'efica', 'conjica', 'fastica')
%   perm_meth - m�todo utilizado para resolver o problema da permuta��o (ver help bss_fdpermsolve)
%   corr_thre - threshold de correla��o (s� � utilizado se o m�todo de correla��o para resolver o problema da permuta��o for utilizado)
%   corr_env - envelope da peermuta��o ('AbsValue' ou 'PowValue')
%   dist_mics - dist�ncia entre um microfone e outro, dispostos em uma linha, no caso de utilizar DOA
%   dist_max_mics - dist�ncia m�xima entre os microfones
%   debug - '1' se quiser um n�vel de depura��o maior


% ---------- SA�DAS
%   s, x, y


%% LENDO ARQUIVOS DE SOM E GERANDO AS MISTURAS
bss_read;


%% PASSANDO PARA O DOM�NIO DA FREQU�NCIA
if debug,   disp('Passando para o dom�nio da frequ�ncia...');       end

% Na matriz X, temos:
% i = o �ndice da mistura (2 para o caso de 2 microfones e 2 fontes).
% j = a quantidade de amostras para cada uma das fontes no dom�nio da frequ�ncia(4098).
% k = a quantidade de deslocamentos que a janela de STFT realizou.

[X, num_of_frames] = stft(x, K, J, winda, wdft_par, 'zeropad'); % MATRIZ X - cada linha � uma frequ�ncia e as fontes est�o na 3� dimens�o

S = stft(s, K, J, winda, wdft_par, 'zeropad'); % Sinal das fontes na frequ�ncia
S = permute(S, [2 1 3]); % A 3� dimens�o � a das frequ�ncias, assim como W e Y

Q = stft(q, K, J, winda, wdft_par, 'zeropad'); % Sinal das fontes como vistas em cada microfone na frequ�ncia
Q = permute(Q, [2 1 3]); % A 3� dimens�o � a das frequ�ncias, assim como W e Y


%% BRANQUEAMENTO
if debug,   disp('Branqueando os sinais...');                       end

V = zeros(K, N, M); % MATRIZ V - Conjunto das matrizes branqueadoras V onde a dimens�o 3 � o �ndice delas
W = zeros(K, N, M); % MATRIZ W - Conjunto das matrizes W (separadoras) onde a dimens�o 3 � o �ndice delas
Y = zeros(K, N, num_of_frames); % MATRIZ Y - cada linha � uma fonte e na 3� dimens�o est�o as frequ�ncias
                                % ATENC�O! No fim do script a 3� dimens�o se torna a dimens�o das fontes, para entrar na fun��o stft
Z = zeros(K, N, num_of_frames); % MATRIZ Z - sinais branqueados

for ck = 1:K
    % o "squeeze" faz com que a matriz 2x4096x154 se torne, para cada
    % itera��o de ck (1 � 4096), uma matriz 4096x154.
    X(:, ck, :) = pre_centering(squeeze( X(:, ck, :) ));
    [Z(ck, :, :), V(ck, :, :)] = pre_whitening(squeeze( X(:, ck, :) ));
end

clear ck


%% ALGORITMO DE SEPARA��O
switch lower(sep_meth)
    case 'natica'
        if debug,       disp('Natural ICA...');                     end

        error = cell(1, K);
        iter = zeros(1, K);

        if nonholonomic
            for k = 1:K
                [Y(k, :, :), W(k, :, :), error{k}, iter(k)] = natICA(squeeze(X(:, k, :)), 'InitSepMat', squeeze(V(k, :, :)), 'InitSourceSig', squeeze(Z(k, :, :)), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', natica_meth, 'estFuncDev', sourcepdf_dev, 'nonHolonomic');
            end
        else
            for k = 1:K
               [Y(k, :, :), W(k, :, :), error{k}, iter(k)] = natICA(squeeze(X(:, k, :)), 'InitSepMat', squeeze(V(k, :, :)), 'InitSourceSig', squeeze(Z(k, :, :)), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', natica_meth, 'estFuncDev', sourcepdf_dev);
            end
        end
        
        clear k 

    case 'nlpca'
        if debug,       disp('Non Linear PCA...');                     end
        
        for k = 1:K
            [Y(k, :, :), a] = nlpca(squeeze(X(:,k,:)), 2);
        end
        
    case 'natica_gauss'
        if debug,       disp('Natural ICA com Gaussiana Generalizada...'); 
                                                                    end

        tmp_scorefunc = 'genGaussian';
        error = cell(1, K);
        iter = zeros(1, K);
        
        for k = 1:K
            kurt = 0;
            for cn = 1:N
                kurt = kurt + kurtosis(abs( squeeze(Z(k, cn, :)) ));
            end
            kurt = kurt/N;
            
            if kurt < 3,            r_gauss = 4;
            elseif kurt < 10,        r_gauss = 1;
            else                    r_gauss = 0.5;
            end
            
            [Y(k, :, :), W(k, :, :), error{k}, iter(k)] = natICA(squeeze(X(:, k, :)), 'InitSepMat', squeeze(V(k, :, :)), 'InitSourceSig', squeeze(Z(k, :, :)), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', tmp_scorefunc, 'estFuncDev', sourcepdf_dev, 'gaussExp', r_gauss);
        end
        
        clear cn k kurt r_gauss tmp_scorefunc

    case 'natica_laplace'
        if debug,       disp('Natural ICA com Laplace Generalizada...'); 
        end

        tmp_scorefunc = 'genLaplace';
        error = cell(1, K);
        iter = zeros(1, K);
        
        for k = 1:K
            [Y(k, :, :), W(k, :, :), error{k}, iter(k)] = natICA(squeeze(X(:, k, :)), 'InitSepMat', squeeze(V(k, :, :)), 'InitSourceSig', squeeze(Z(k, :, :)), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', tmp_scorefunc, 'estFuncDev', sourcepdf_dev, 'laplaceShape', laplace_alpha);
        end
        
        clear k tmp_scorefunc
        
    case 'efica' 
        if debug,       disp('Efficient Fast ICA...');              end

        ISR = cell(1, K);
        for k = 1:K 
            [dummyW, dummyISR, W(k, :, :), ISR{k}, dummystatus, Y(k, :, :)] = efica(squeeze( Z(k, :, :) ));
            W(k, :, :) = squeeze(W(k, :, :)) * squeeze(V(k, :, :));
        end

        clear k dummyW dummyISR dummystatus

    case 'conjica'
        if debug,       disp('Conjugated ICA (FastICA + Natural ICA)...');   end
        
        error = cell(1, K);
        iter = zeros(1, K);

        for k = 1:K
            [Y(k, :, :), W(k, :, :), error{k}, tmpit1] = cunICA(squeeze( Z(k, :, :) ));
            W(k, :, :) = squeeze(W(k, :, :)) * squeeze(V(k, :, :));
            if nonholonomic
                [Y(k, :, :), W(k, :, :), error{k}, tmpit2] = natICA(squeeze( X(:, k, :) ), 'InitSepMat', squeeze( W(k, :, :) ), 'InitSourceSig', squeeze( Y(k, :, :) ), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', natica_meth, 'estFuncDev', sourcepdf_dev, 'nonHolonomic');
            else
                [Y(k, :, :), W(k, :, :), error{k}, tmpit2] = natICA(squeeze( X(:, k, :) ), 'InitSepMat', squeeze( W(k, :, :) ), 'InitSourceSig', squeeze( Y(k, :, :) ), 'MaxIter', Num_It, 'eta', eta, 'ScoreFunction', natica_meth, 'estFuncDev', sourcepdf_dev);
            end
            
            iter(k) = tmpit1 + tmpit2;
        end
        
        clear k Wtmp

    case 'jade'
        if debug,       disp('JADE...');   end
        
        error = cell(1, K);
        iter = zeros(1, K);

        for k = 1:K
            [W(k, :, :)] = jade(squeeze( Z(k, :, :) ));
            W(k, :, :) = squeeze(W(k, :, :)) * squeeze(V(k, :, :));
        end
        
        clear k Wtmp
    otherwise
        disp(['BSS_FD - M�todo de separa��o n�o reconhecido: ' sep_meth])
        disp('Aperte CTRL+C...')
        pause
        
end


%% RESOLVENDO O PROBLEMA DA PERMUTA��O
if debug,   disp('Resolvendo problema da permuta��o...');           end

preW = W;

%Preal = bss_fdpermsolve(W, Y, 'Method', 'supervised', 'SourceSignal', S);

switch lower(perm_meth)
    case 'doa'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'useSymmetry');

    case 'tdoa'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'tdoa', 'SampFrequency', fs, 'MaxDistBetweenSensors', dist_max_mics, 'useSymmetry');

    case 'conjcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'conjcorr', 'Envelope', corr_env, 'useSymmetry');

    case 'globalcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'globalcorr', 'Envelope', corr_env, 'useSymmetry');
        
    case 'localcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'localcorr', 'Envelope', corr_env, 'useSymmetry');
        
    case 'allcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'allcorr', 'Envelope', corr_env, 'useSymmetry');
        
    case 'doa_adjcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa_adjcorr', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'Envelope', corr_env, 'useSymmetry');    

    case 'doa_globalcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa_globalcorr', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'Envelope', corr_env, 'useSymmetry');    

    case 'doa_allcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa_allcorr', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'Envelope', corr_env, 'useSymmetry');    

    case 'doa_harmcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa_harmcorr', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'CorrThreshold', corr_thre, 'Envelope', corr_env, 'HarmonicThreshold', harm_thre, 'useSymmetry');

    case 'harmcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'harmcorr', 'SampFrequency', fs,  'CorrThreshold', corr_thre, 'Envelope', corr_env, 'HarmonicThreshold', harm_thre, 'useSymmetry');

    case 'doa_conjcorr'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'doa_conjcorr', 'SampFrequency', fs, 'DistanceBetweenSensors', dist_mics, 'DirPatternThreshold', dirpat_thre, 'Envelope', corr_env, 'useSymmetry');    

    case 'supervised'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'supervised', 'SourceSignal', S, 'MicSourceComponents', Q);

    case 'maxsir'
        [P ind_solve] = bss_fdpermsolve(W, Y, 'Method', 'maxSIR', 'MicSourceComponents', Q);

    otherwise
        disp(['BSS_FD - M�todo para resolver a permuta��o n�o reconhecido: ' perm_meth])
        disp('Aperte CTRL+C...')
        pause

end

%metodo_acertou = (Preal(1,:) - P(1,:) == 0);

for k = 1:K
    Wtmp = squeeze( W(k, :, :) );           W(k, :, :) = Wtmp(P(:, k), :);
end


clear k Wtmp 

%% UTILIZANDO O PRINC�PIO DA M�NIMA DISTOR��O PARA RESOLVER O PROBLEMA DO ESCALAMENTO
if debug,   disp('Resolvendo problema do escalamento...');          end

posW = W;

for k = 1:K
    Wtmp = squeeze( W(k, :, :) );
    W(k, :, :) = diag( diag( inv(Wtmp) ) ) * Wtmp;
end

clear k Wtmp

%% SUAVIZANDO OS FILTROS
if smoothFlag
    if debug,   disp('Suavizando os filtros...');            end

    smooth_lag = (length(smooth_filter) - 1)/2;
    for cn = 1:N
        for cm = 1:M
            Wtmp = filter(smooth_filter, 1, [fftshift(squeeze(W(:, cn, cm))); zeros(smooth_lag, 1)]);
            W(:, cn, cm) = ifftshift(Wtmp(1+smooth_lag:K+smooth_lag));
        end
    end

    clear cn cm Wtmp
end

%% VOLTANDO PARA O DOM�NIO DO TEMPO
if debug,   disp('Voltando para o dom�nio do tempo...');            end

Y = zeros(N, K, num_of_frames);
for k = 1:K
    Y(:, k, :) = squeeze( W(k, :, :) ) * squeeze( X(:, k, :) );
end

y = istft(Y, J, winds, wdft_par, size(x,2)); % Eliminando as amostras extras, resultantes do zero-padding

%w11 = iwdft(W(:, 1, 1), wdft_par);     w11t = iwdft(W(:, 1, 1), wdft_par, length(winda));
%w12 = iwdft(W(:, 1, 2), wdft_par);     w12t = iwdft(W(:, 1, 2), wdft_par, length(winda));
%w21 = iwdft(W(:, 2, 1), wdft_par);     w21t = iwdft(W(:, 2, 1), wdft_par, length(winda));
%w22 = iwdft(W(:, 2, 2), wdft_par);     w22t = iwdft(W(:, 2, 2), wdft_par, length(winda));

%clear yconv
%yconv(1, :) = conv(w11, x(1, :)) + conv(w12, x(2, :)); 
%yconv(2, :) = conv(w21, x(1, :)) + conv(w22, x(2, :));

%clear yconvt
%yconvt(1, :) = conv(w11t, x(1, :)) + conv(w12t, x(2, :)); 
%yconvt(2, :) = conv(w21t, x(1, :)) + conv(w22t, x(2, :));

clear k

clear V%Z X Y S W Q