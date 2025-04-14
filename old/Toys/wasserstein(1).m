% Look at difference between Wasserstein distance and Lp norm
clc;clear;close all

% Make up distributions
u = normpdf(-10:10); 
v = normpdf(-10:10, -5); 

% Space we're defined over
x = -10:10; 

figure; 
hold on
plot(x, u); 
plot(x, v); 

for i = 1:length(x)
    v = normpdf(x, x(i)); 

    l(i) = lp(u, v, 1); 
    w(i) = wass(u, v, 1); 
end

figure; 
hold on
plot(x, l)
plot(x, w)



function d = lp(u, v, p)
    if nargin < 3
        p = 2; 
    end
    d = (sum(abs(u-v).^p))^(1/p); 
end

function d = wass(u, v, p)
    if nargin < 3
        p = 2; 
    end
    d = (1/length(u) * sum(abs(u - v).^p))^(1/p); 
end