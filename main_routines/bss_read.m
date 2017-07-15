% ---------- PAR�METROS
%   num_samp - n�mero de amostras a pegar
%   mixing_mode - 'ism' - Image Source Method, com arquivos ISM_xxx.mat j� criados
%                 'ismbuild' - Image Source Method, cria os arquivos .mat segundo os par�metros configurados abaixo
%                 'real' - Utiliza um sinal real, ou seja, as fontes originais n�o s�o conhecidas
%                 'input' - Utiliza os arquivos de mistura Mix{n}
%   N - n�mero de fontes
%   num_samp - n�mero de amostras a ler
%   Source{n} - caminho completo do arquivo fonte n
%
%   ISM / ISMBUILD
%   M - n�mero de microfones
%   dist_mics - dist�ncia entre os microfones, em metros
%   dist_scrmic - dist�ncia das fontes at� o "centro de massa" dos
%                 microfones, em metros
%   mics_struct - estrutura dos microfones('line2d' ou 'cluster2d')
%   ang_src - vetor posi��o, de 1 a 4, com o �ngulo das fontes, em graus
%   reverb_time - tempo de reverbera��o (T-60)
%
%   INPUT
%   Mix{n} - caminho completo do arquivo parcial de mistura n (arquivo est�reo, onde cada canal corresponde � fonte segundo vista em um dos microfones)
%   M � SEMPRE IGUAL A 2

% ---------- SA�DAS
%   fs, s, q (2 primeiras linhas correspondem � primeira fonte, e as
%   duas �ltimas, � segunda), x, M(� sobrescrito se for 'input')
%   dist_max_mics - dist�ncia m�xima entre dois microfones (S� EM ISMBUILD)

clear s q x

% As misturas s�o vetores linha, ou seja:
% x(t) = [ x1(1) x1(2) x1(3) ... x1(num_samp)
%          x2(1) x2(2) x2(3) ... x2(num_samp) ]


% L� o conte�do da primeira fonte e coloca na primeira coluna da matriz s;
[s(:,1), fs] = wavread(Source{1}, num_samp);

% L� o conte�do da fonte n�mero "cn" coloca na coluna de n�mero "cn" da matriz s;
for cn = 2:N
    s(:,cn) = wavread(Source{cn}, num_samp);
end

% Faz um resample de 1/2 para a matriz que cont�m, nas colunas, a leitura
% das fontes
s = resample(s,1,2);
fs = fs/2;
s = s.';

%% Decide o m�todo de separa��o 
switch lower(mixing_mode)
    
    %% ISM
    case 'ism'
        q = zeros(size(s, 2), M*N);
        
        for cn = 1:N
            q(:, (cn-1)*M + 1 : cn*M) = ISM_AudioData(['ISM_' num2str(cn) '.mat'], s(cn,:)); % Fonte cn
        end
        x = sum( reshape(q, size(s, 2), M, N), 3);  x = x.';    q = q.';
    
    %% ISMBUILD
    case 'ismbuild'
        % Cria uma matriz de zeros onde:
        % O n�mero de linhas � dado pelo n�mero de colunas da matriz s
        % (quantidade de amostras dos sinais de �udio)
        % O n�mero de colunas � dado pelo produto da quantidade de fontes
        % por microfones (2x2 = 4)
        q = zeros(size(s, 2), M*N);

        ang_src = ang_src(:);   ang_src = ang_src(1:N);     % Formatando o vetor (coluna e tamanho)
        mics_center = [2 1.5 1.6]; % "Centro de massa" da estrutura de microfones (Altura 1.4???)
        
        % Matriz contendo os vetores linha (x,y,z) da posi��o das fontes.
        src_traj = [(mics_center(1) + dist_scrmic*sind(ang_src)) (mics_center(2) - dist_scrmic*cosd(ang_src)) mics_center(3)*ones(N,1)];
        SetupStruc.Fs = fs; % Frequ�ncia de amostragem
        SetupStruc.room = [4.45  3.55  2.5]; % Dimens�es da sala
        
        %% Decide a forma de organizar o arranjo dos microfones
        switch lower(mics_struct)
            
            case 'line2d'
                SetupStruc.mic_pos = [mics_center(1)*ones(M,1) (mics_center(2) - (M-1)*dist_mics/2 : dist_mics : mics_center(2) + (M-1)*dist_mics/2).' mics_center(3)*ones(M,1)];
            
            case 'cluster2d'
                mic_pos = zeros(M, 3);
                for cc = 1:M-1  % Cria um pol�gono de M-1 lados, com M v�rtices (microfones)
                    mic_pos(cc+1,:) = mic_pos(cc,:) + [dist_mics*[sin(cc*2*pi/M) cos(cc*2*pi/M)]  0];
                end
               
                % Pre MatLab 2008
                med_mic_pos = repmat(mean(mic_pos, 1) - mics_center, M, 1);
                mic_pos = mic_pos - med_mic_pos;

                SetupStruc.mic_pos = mic_pos;
        end
        SetupStruc.T60 = reverb_time; % Tempo de reverbera��o
        SetupStruc.abs_weights = [1  1  1  1  1  1]; % Coeficientes de absor��o das paredes (tudo 1 N�O � uma c�mara anec�ica. Para uma c�mara anec�ica, sete T60 como 0)

        % Realiza o plot da configura��o da sala.
        if plotroom_flag
            plot3(SetupStruc.mic_pos(:,1), SetupStruc.mic_pos(:,2), SetupStruc.mic_pos(:,3), 'x red'); hold;
            plot3(src_traj(:,1), src_traj(:,2), src_traj(:,3), 'o' ); title('Simulated Room');
            xlabel 'Width', ylabel 'Length', zlabel 'Height', grid on;
            xlim([0 SetupStruc.room(1)]); ylim([0 SetupStruc.room(2)]);
            
            legend('Sensors', 'Sources', 'TextColor', 'blue');
            
        end
        
        for cn = 1:N
            SetupStruc.src_traj = src_traj(cn, :);
            ISM_RIR_bank(SetupStruc,['ISM_' num2str(cn) '.mat']); % Cria o modelo da fonte cn
        end

        for cn = 1:N
            q(:, (cn-1)*M + 1 : cn*M) = ISM_AudioData(['ISM_' num2str(cn) '.mat'], s(cn,:)); % Fonte cn
        end
        
        %% Cria o vetor das misturas a partir do simulador de ambiente.
        x = sum( reshape(q, size(s, 2), M, N), 3);  x = x.';    q = q.';
        
        if M > 1
            tmpcombs = nchoosek(1:M, 2);
            tmpdist = zeros(1, size(tmpcombs, 1));
            for cc = 1:size(tmpcombs, 1)
                tmpdist(cc) = norm(SetupStruc.mic_pos(tmpcombs(cc,1), :) - SetupStruc.mic_pos(tmpcombs(cc,2), :));
            end

            dist_max_mics = max(tmpdist); % SA�DA
        else
            dist_max_mics = 0;
        end
        clear SetupStruc mics_center cc mic_pos tmpcombs tmpdist
        
end

clear cn cm plotroom_flag