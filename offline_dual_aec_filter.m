clear
close all
clc

dir = './test_audio/speech/2';
kalman_out = audioread([dir, '/laec_withpost_out.wav']);
[nlms_out,fs] = audioread([dir, '/aec_nlms.wav']);
Lk = length(kalman_out);
Ln = length(nlms_out);
Lmin = min(Lk,Ln);
kalman_out = kalman_out(1:Lmin);
nlms_out = nlms_out(1:Lmin);


frame_size = 128;
kalman_sp = stft(kalman_out,"FFTLength",2*frame_size,"FrequencyRange","onesided");
nlms_sp = stft(nlms_out,"FFTLength",2*frame_size,"FrequencyRange","onesided");

kalman_sp_am = abs(kalman_sp);
nlms_sp_am = abs(nlms_sp);

min_sp = kalman_sp;
min_sp(nlms_sp_am<kalman_sp_am) = nlms_sp(nlms_sp_am<kalman_sp_am);

min_out = istft(min_sp,"FFTLength",2*frame_size,"FrequencyRange","onesided");

audiowrite([dir,'/dual_aec_out.wav'], min_out, fs);


