%% PATH
Path = 'C:\Users\Hian\Documents\final-project\Matlab\commons\audio_files\';

% Cria arrays 1x2;
Sources = cell(1, 2);

% Obt�m os arquivos de �udi
Sources{1} = [Path 'female_src_1.wav'];
Sources{2} = [Path 'male_src_1.wav'];

%% PAR�METROS DA STFT

K = 4096;                                   % N�mero de bins da FFT utilizada (pontos)
windlen = 2048;                             % Comprimento da janela

Jc = cell(1,5);
Jc{1} = windlen / 2;
Jc{2} = windlen / 4;                        % Pulo da STFT
Jc{3} = windlen / 4;
Jc{4} = windlen / 4;
Jc{5} = windlen / 4;
Jc{6} = windlen;
Jc{7} = windlen / 2;
Jc{8} = windlen / 4;
J = Jc{8};

wind = cell(1,5);
wind{1} = hann(windlen, 'periodic').';      % Janelas que atendem � COLA se J = len/2, onde len � o comprimento da janela.
wind{2} = 0.5*hann(windlen, 'periodic').';  % Janelas que atendem quando J = len/4
wind{3} = 0.677*chebwin(windlen).';
wind{4} = 0.72*window(@blackmanharris, windlen).';
wind{5} = 0.71*window(@nuttallwin, windlen).';
wind{6} = ones(1,windlen);
wind{7} = 0.5*ones(1,windlen);
wind{8} = 0.25*ones(1,windlen);

winda = wind{8};                            % Janela de an�lise
winds = ones(1,windlen);                    % Janela de s�ntese
wdft_par = 0;                               % Se utilizada WDFT, coloque um valor diferente de 0, mas entre -1 e 1 exclusive.
debug = 1;                                  % Depura��o da rotina BSS_FD

%% PAR�METROS DO ICA
sep_meth = 'natica';                         % M�todo ICA utilizado
Num_It = 250;                               % N�mero m�ximo de itera��es do ICA
eta = .2;                                   % Passo de adapta��o do ICA
natica_meth = 'sign';                       % Par�metro do natica e conjica
nonholonomic = false;                       % Par�metro do natica e conjica
laplace_alpha = 0.1;                        % Par�metro do natica_laplace
sourcepdf_dev = 1;                          % Par�metro do natica (desvio padr�o aproximado da pdf do sinal da fonte)


%% PAR�METROS PARA A MATRIZ DE MISTURAS, ENTRADA PARA O SCRIPT BSS_READ
mixing_mode = 'ismbuild';                   % M�todo para achar as misturas. Ver script bss_read para informa��es
N = 2;                                      % N�mero de fontes
M = 2;                                      % N�mero de misturas
num_samp = 160000;                           % N�mero de amostras a ler
reverb_time = 0.1;                         % Tempo de reverbera��o
mics_struct = 'cluster2d';                  % Estrutura de montagem dos microfones
dist_scrmic = 1;                            % Dist�ncia de cada fonte at� os microfones, em metros
ang_src(1) = 45;                           % Se utilizado ISM, �ngulo da fonte 1, em graus
ang_src(2) = 120;                           % Se utilizado ISM, �ngulo da fonte 2, em graus
Source{1} = Sources{1};                     % Arquivo da fonte 1 
Source{2} = Sources{2};                     % Arquivo da fonte 2
plotroom_flag = 1;

%% PAR�METROS PARA RESOLVER A PERMUTA��O
perm_meth = 'tdoa';               % M�todo para resolver o problema. Digite help bss_fdpermsolve 
dist_mics = 0.04;                           % Dist�ncia entre os microfones, em metros (tamb�m � ENTRADA para o BSS_READ, se se utilizar simula��o)
                                            % Dist�ncia entre os microfones das pontas
%dist_max_mics = 0.04;                       % � sa�da da fun��o BSS_READ quando mixing_mode = 'ismbuild'. Anote quando rodar o build
dirpat_thre = 0;                          % Uma das condi��es do m�todo DOA. Melhor deixar -Inf e n�o utiliz�-la
corr_thre = 0.3*N*6;                        % Threshold que diz se o m�todo de correla��o entre frequ�ncias adjacentes � confi�vel. O valor m�ximo � N*2*NumAdjFrequencies, com N=2, � 12. Usei 30% do m�ximo
                                            % NumAdjFrequencies � um par�metro da fun��o bss_fdpermsolve, que deixei como 'default, ou seja, 3
corr_env = 'PowValue2';                      % Envelope para calcular a correla��o ('AbsValue' ou 'PowValue')
harm_thre = 0.1*N*6;                        % Threshold que diz se o m�todo de correla��o entre harm�nicos � confi�vel. O valor m�ximo � N*6. Usei 10% do valor m�ximo

%% SUAVIZANDO OS FILTROS
smoothFlag = 1;                             % Se deve suavizar os filtros
%smooth_filter = [0.25 0.5 0.25]; % Hanning window
smooth_filter = [0.003 0.0602 0.2516 0.3902 0.2516 0.0602 0.003]; % Chebyshev window
%smooth_filter = [0.01 0.0817 0.24 0.3363 0.24 0.0817 0.01]; % Blackman window
%smooth_filter = [0.0092 0.0795 0.2407 0.3409 0.2407 0.0795 0.0092]; % Nuttall window
%smooth_filter = [0.0014 0.0032 0.0129 0.9787 0.0129 0.0032 0.0014]; % Kaiser window
                                            % Filtro utilizado (padr�o [0.25 0.5 0.25])

%% EXECUTA A ROTINA

disp(perm_meth)

source_combs = nchoosek(1:8, N);

BSS_FD;

[SDR, SIRb, SAR, perm]=bss_eval_sources(x,s);
[SDR, SIR, SAR, perm]=bss_eval_sources(y,s);   disp(SIR - SIRb); disp(SDR); disp(SAR)

%[SDR,SIR,SAR,perm]=bss_eval_sources(yconv(:,1:48000),s);   disp(SIR); disp(SDR); disp(SAR)
%[SDR,SIR,SAR,perm]=bss_eval_sources(yconvt(:, 1:48000),s);   disp(SIR); disp(SDR); disp(SAR)

clear tmpc

%% RASCUNHO
%doa_acertou = metodo_acertou & ind_solve{1};        disp(sum(doa_acertou)/sum(ind_solve{1}))
%precorr_acertou = metodo_acertou & ind_solve{2};    disp(sum(precorr_acertou)/sum(ind_solve{2}))
%harm_acertou = metodo_acertou & ind_solve{3};       disp(sum(harm_acertou)/sum(ind_solve{3}))
%corr_acertou = metodo_acertou & ind_solve{4};       disp(sum(corr_acertou)/sum(ind_solve{4}))
