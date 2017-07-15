function [X, n_frames] = stft(x, K, J, varargin)
% [X, n_frames] = stft(x, K, J) 
% [X, n_frames] = stft(x, K, J, 'zeropad')
% [X, n_frames] = stft(x, K, J, wind)
% [X, n_frames] = stft(x, K, J, wind, 'zeropad')
% [X, n_frames] = stft(x, K, J, wind, wdft_par) 
% [X, n_frames] = stft(x, K, J, wind, wdft_par, 'zeropad') 
%         gera os frames da STFT de um ou mais sinais no dom�nio do tempo, 
%         onde
%
%         x - sinal(is) de entrada(s), no dom�nio do tempo. O sinal deve ser
%             vetores linha, onde as colunas s�o as amostras, e cada linha �
%             um sinal
%         K - n�mero de 'bins' na frequ�ncia. Se n�o for especificada nenhuma
%             janela, corresponde ao tamanho do frame da STFT 
%         J - salto entre cada frame da STFT
%         wind - janela que ser� utilizada. � um vetor linha, que ser� 
%                multiplicado por cada frame antes de aplicar a DFT. Em
%                condi��es normais, o tamanho de wind � igual a K, a n�o
%                ser que se deseje "oversampling"
%         'zeropad' - indica que ser� feito zero-padding. Por default as
%                   �ltimas amostras ser�o descartadas (se o n�mero de
%                   amostras do final n�o for suficiente para gerar um frame
%                   completo). Com este modificador, a fun��o acrescenta
%                   zeros ao final do vetor antes de passar para o dom�nio
%                   da frequ�ncia
%         wdft_par - Se for 0, � aplicada a FFT comum em cada frame, e se
%         for maior que 0, � aplicada a WDFT
%
% Sa�das
%     Ao final, � gerada uma matriz X de 3 dimens�es, onde os frames s�o as
%     colunas, cada linha representa um bin de frequ�ncia, e na outra dimens�o
%     est�o representados os sinais
% X =   [ X1(1) X2(1) X3(1) ... Xnum_of_frames(1)
%         X1(2) X2(2) X3(2) ... Xnum_of_frames(2)
%         X1(3) X2(3) X3(3) ... Xnum_of_frames(3)
%                ...                 ...
%         X1(K) X2(K) X3(K) ... Xnum_of_frames(K) ] <- FFT da primeira linha de x
%
%       [ X1(1) X2(1) X3(1) ... Xnum_of_frames(1)
%         X1(2) X2(2) X3(2) ... Xnum_of_frames(2)
%         X1(3) X2(3) X3(3) ... Xnum_of_frames(3)
%                ...                 ...
%         X1(K) X2(K) X3(K) ... Xnum_of_frames(K) ] <- FFT da segunda linha de x
%
% n_frames � o n�mero de frames gerado
%
%
% ATEN��O! Algumas amostras do final do vetor x de entrada podem ser
% descartadas no processo, ou seja, a DFT inversa da matriz X N�O GERAR�
% exatamente o vetor x. Para evitar o descarte, utilize 'zeropad'.

% �ltima atualiza��o: 23/07/2010

%% Processando as entradas e sa�das

% Argumentos padr�o
zeropad = 0;
wdft_par = 0;
wind = ones(1, K);
    
if numel(varargin)
    if find( strcmp('zeropad', varargin) , 1),  zeropad = 1;        end

    optargin = size(varargin, 2) - zeropad; % zeropad � sempre o �ltimo argumento, se existir
    
    if optargin > 0
        wind = varargin{1};
        if optargin > 1
            wdft_par = varargin{2};
            if optargin > 2
                error('Excesso de argumentos de entrada')
            end
        end
    end
end

N = size(wind, 2); % Tamanho do frame
M = size(x, 1); % n�mero de sinais
num_samp = size(x, 2); % n�mero de amostras

if J > N
    error('STFT - O salto J n�o pode ser maior que o tamanho do frame.')
end

if N > K
    error('STFT - O tamanho do frame n�o pode ser maior do que o n�mero de bins da DFT. Diminua o tamanho da janela utilizada.')
end

if N < K
    warning('STFT - Oversampling: o tamanho da DFT � maior que o n�mero de amostras por frame.')
end

%% Zero-Padding
if zeropad
% Se mod(num_samp-N, J for maior que zero, sobrou um resto, ent�o o n�mero
% de frames deve ser igual a floor((num_samp - N) / J) + 2, e devem ser 
% adicionados zeros ao final da amostra para que a conta feche. O n�mero de
% zeros adicionados � o tamanho do pulo menos o resto, ou seja, 
% J-mod(num_samp - N, J)
    if mod(num_samp - N, J)
        x = [x zeros(M, J - mod(num_samp - N, J))];

% Se o mod(num_samp - N, J) for zero, quer dizer que nenhuma amostra ser�
% descartada, e o n�mero de frames � igual a floor((size(x,2) - N) / J) + 1,
% ou seja, zeropad deve ser 0
    else
        zeropad = 0;
    end
end

%% Aplicando a FFT ou WDFT frame a frame
n_frames = floor((num_samp - N) / J) + 1 + zeropad;
X = zeros(M, K, n_frames);
if wdft_par
    
    A = cell(1, N);
    A_tilde = cell(1, N);
    A{1} = 1;           A{2} = [-wdft_par; 1];
    A_tilde{1} = 1;     A_tilde{2} = [1; -wdft_par];
    A_1 = A{2};     A_tilde_1 = A_tilde{2};
    for i = 3:N
        A{i} = conv(A{i-1}, A_1);
        A_tilde{i} = conv(A_tilde{i-1}, A_tilde_1);
    end
    Q = zeros(N);
    for i = 1:N
        Q(:, i) = conv(A_tilde{N-i+1}, A{i});
    end
    
    D = fft(A_tilde{N}, K);
    
    for ci = 1:M
        for frame = 1:n_frames
            X(ci, :, frame) = wdft(x( ci, 1 + (frame-1)*J : (frame-1)*J + N ) .* wind, wdft_par, K, 1, Q, D).';
        end 
    end
else
    for ci = 1:M
        for frame = 1:n_frames
            X(ci, :, frame) = fft(x( ci, 1 + (frame-1)*J : (frame-1)*J + N ) .* wind, K).';
        end 
    end
end
