% Make some curves for expected intercept range


pTx = [0.1, 0.3, 0.5, 0.7, 0.9]; 
nCPI = 1000; 

doTx = zeros(nCPI, length(pTx)); 
maxRange = zeros(nCPI, length(pTx)); 
for i = 1:nCPI
    doTx(i,:) = rand(size(pTx)) < pTx; 
    % maxRange(i,:) = R_I(doTx(i,:)); 
    maxRange(i,:) = R_I(doTx(i,:)); 
end
% 
% figure; 
% plot(pTx, mean(maxRange)); 
% 
% figure; 
% plot(pTx, R_I(mean(doTx))); 


figure; 
for i = 1:length(pTx)
    [f, x] = ecdf(maxRange(:,i)); 
    semilogx(x, f, 'linewidth', 2, 'DisplayName', '$P(Tx) = ' + string(pTx(i)) + '$')
    hold on
end
legend('interpreter', 'latex', 'fontsize', 12, 'location', 'best')
xlabel('Max Intercept Range', 'interpreter', 'latex', 'fontsize', 12)
ylabel('$P($Range$ \leq X)$', 'interpreter', 'latex', 'fontsize', 12)



function range = R_I(P)
    % Approximates max intercept range for LPI radar
    % Default parameters: 
    G_t = 10^(((20*rand) + 10)/10); % Gain in direction of IRX, 30dB
    G_I = 10^(30/10); % 30dB
    fc = 9.375e9; 
    lambda = physconst('Lightspeed')/fc; 
    k = physconst('Boltzmann');
    T_0 = 290; 
    B = 60e6; 
    F1 = 10^(5/10); 
    % SNR_dB = 0:35; 
    SNR_dB=10; 
    SNR = 10.^(SNR_dB./10); 

    range = sqrt((P * G_t * G_I * lambda^2) ./ (4*pi*k*T_0*F1*B.*SNR)); 
end