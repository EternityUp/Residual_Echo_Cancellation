clc; clear all;

dir = './test_audio/speech/2';
echo_file = [dir, '/1-mic1-dc.wav'];
far_file = [dir , '/c-07.wav'];
laec_out_file = [dir, '/laec_out.wav'];               % 线性aec输出
laec_post_out_file = [dir, '/laec_withpost_out.wav']; % 带约束线性aec输出
naec_out_file = [dir, '/naec_out_speex.wav'];         % 非线性nlp输出
[mic, fs1] = audioread(echo_file,'native');
[spk, fs2] = audioread(far_file, 'native');

mic = double(mic);
spk = double(spk);

aec_ref = audioread('E:\DSP\Residual_Echo_Cancellation\test_audio\speech\2\2-aecOut.wav','native');
aec_refd = double(aec_ref);
aaa=gccphat(mic(1:fs1*30),aec_refd(1:fs1*30));
audiowrite([dir,'/aec_nlms.wav'],aec_ref(257:end),fs1);

if (fs1~=16000)||(fs2~=16000)
    error('only support 16kHz sampling rate');
end

% static 
frame_size = 256;
mdf_block_num = 16;
out_len = min(length(mic),length(spk));
laec_out = zeros(out_len,1);
naec_out = zeros(out_len,1);
out_num = floor(out_len/frame_size);

% mode 
% 1. webrtc
% 2. speex
mode = 2;

% init 
st = main_init(frame_size, mdf_block_num, mode);

% process
for i = 1:out_num
    echo_frame = mic(1+(i-1)*frame_size:i*frame_size);
    far_frame = spk(1+(i-1)*frame_size:i*frame_size);
    %  process
    if mode==1
        [st, lout_frame] = mdf_kalman(st, echo_frame, far_frame);
        [st, nout_frame] = webrtc(st, lout_frame, echo_frame, far_frame);
    elseif mode==2
        [st, lout_frame] = mdf_kalman(st, echo_frame, far_frame);
        [st, nout_frame] = speex(st, lout_frame);
    end
    %out
    laec_out(1+(i-1)*frame_size:i*frame_size) = lout_frame;
    naec_out(1+(i-1)*frame_size:i*frame_size) = nout_frame;

end

% post process
S_in = stft(mic,"FFTLength",2*frame_size,"FrequencyRange","onesided");
S_out = stft(laec_out,"FFTLength",2*frame_size,"FrequencyRange","onesided");
S_in_amp = abs(S_in);
S_out_amp = abs(S_out);
S_out(S_in_amp<S_out_amp) = S_in(S_in_amp<S_out_amp);
laec_out_post = istft(S_out,"FFTLength",2*frame_size,"FrequencyRange","onesided");



% write file
audiowrite(laec_out_file, laec_out'/32768, fs1);
audiowrite(laec_post_out_file, laec_out_post'/32768, fs1);
audiowrite(naec_out_file, naec_out'/32768, fs1);

function st = main_init(frame_size, mdf_block_num, mode)
        st.win_size = frame_size * 2;
        st.half_bin = frame_size + 1;
        st.frame_size = frame_size;
        st.update_cnt = 0;
        st.M = mdf_block_num;
        st.mode = mode;
        % buffer
        st.x = zeros(st.win_size,1);
        st.X = zeros(st.half_bin, st.M);
        st.Y = zeros(st.half_bin, 1);

        % DC
        st.notch_radius = .982;
        st.notch_mem = zeros(2,1);
        st.memX = 0;
        st.memD = 0;
        st.memE = 0;
        
        % kalman
        st.err_adf = zeros(st.half_bin,1);
        st.coef_adf = zeros(st.half_bin,st.M);
        st.P_initial = 20;
        st.P = ones(st.half_bin, st.M) * st.P_initial;
        st.A = 0.999;
        st.A2 = st.A.^2;
        st.P_MIN = 1e-6;
        st.P_MAX = 5;
        st.Psi_s = 1e-4;
        st.psi_w = ones(st.half_bin, st.M) * 1e-2;
        % nlp
        if mode==1
            st.ee = zeros(st.win_size,1);
            st.dd = zeros(st.win_size,1);
            st.xx = zeros(st.win_size,1);
            st.XX = zeros(st.half_bin,st.M);
            st.window = sqrt(hanning(st.win_size));
            st.webrtc_buf = zeros(st.win_size,1);
            st.Se = zeros(st.half_bin,1);
            st.Sd = zeros(st.half_bin,1);
            st.Sx = zeros(st.half_bin,1);
            st.Sxd = zeros(st.half_bin,1);
            st.Sed = zeros(st.half_bin,1);
        elseif mode==2
            st.ee = zeros(st.win_size,1);
            st.yy = zeros(st.win_size,1); 
            st.et = zeros(st.win_size,1);
            st.yt = zeros(st.win_size,1); 
            st.Yh = zeros(st.half_bin, 1);
            st.Eh = zeros(st.half_bin, 1);
            st.window = sqrt(hanning(st.win_size));
            st.spec_average = st.frame_size/16000;
            st.beta0 = 2*st.frame_size/16000;
            st.beta_max = st.beta0/4;
            st.Pey = 1;
            st.Pyy = 1;
            st.MIN_LEAK = 0.005;
            st.echo_noise = zeros(st.half_bin,1);
            st.old_ps = zeros(st.half_bin,1);
            st.gain = zeros(st.half_bin,1);
            st.speex_buf =  zeros(st.win_size,1);
        end
end




    