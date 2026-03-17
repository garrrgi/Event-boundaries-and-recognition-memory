%%Load data%%
dataPath = 'C:\Users\Gargi\Downloads\BRSM data csv (1)\BRSM data csv'; 
cd(dataPath);

files  = dir('sub*_*.csv');
nFiles = numel(files);
fprintf('Found %d participant files.\n', nFiles);

% Containers for AB and NB
AB = struct();
NB = struct();

ab_count = 0;
nb_count = 0;

%% Load files into containers
for i = 1:nFiles

    filename = files(i).name;
    fullpath = fullfile(files(i).folder, filename);

    T = readtable(fullpath);

    % Determine condition
    if contains(filename, '_AB')

        ab_count = ab_count + 1;
        AB(ab_count).data     = T;
        AB(ab_count).filename = filename;

    elseif contains(filename, '_NB')

        nb_count = nb_count + 1;
        NB(nb_count).data     = T;
        NB(nb_count).filename = filename;

    else
        warning('Condition not identified for file: %s', filename);
    end

end

%% Vigilance Check
%AB Vigilance
fprintf('\nChecking vigilance for AB participants...\n');
AB_vigilance = zeros(length(AB),1);

for i = 1:length(AB)

    T = AB(i).data;

    start_time = T.('Videos_started')(1);
    stop_time  = T.('Videos_stopped')(1);

    duration_min = (stop_time - start_time) / 60;
    AB_vigilance(i) = duration_min;

    if duration_min > 30.85
        fprintf('AB %s FLAGGED (%.2f min)\n', AB(i).filename, duration_min);
    end

end

%NB vigilance
fprintf('\nChecking vigilance for NB participants...\n');
NB_vigilance = zeros(length(NB),1);

for i = 1:length(NB)

    T = NB(i).data;

    start_time = T.('Videos_started')(1);
    stop_time  = T.('Videos_stopped')(1);

    duration_min = (stop_time - start_time) / 60;
    NB_vigilance(i) = duration_min;

    if duration_min > 31.07
        fprintf('NB %s FLAGGED (%.2f min)\n', NB(i).filename, duration_min);
    end

end

%% ================= GLOBAL ACCURACY CHECK =================

AB_acc = zeros(length(AB),1);
NB_acc = zeros(length(NB),1);

%%Participant-wise accuracy (AB)
for i = 1:length(AB)

    T = AB(i).data;

    % Recognition trials
    valid_rows = ~isnan(T.resp_corr);
    acc = T.resp_corr(valid_rows);

    % Mean accuracy participant wise
    AB_acc(i) = mean(acc,'omitnan');

end

%%Participant-wise accuracy (NB)
for i = 1:length(NB)

    T = NB(i).data;

    valid_rows = ~isnan(T.resp_corr);
    acc = T.resp_corr(valid_rows);

    NB_acc(i) = mean(acc,'omitnan');

end


%%Descriptive stats
mean_AB = mean(AB_acc);
mean_NB = mean(NB_acc);

sd_AB = std(AB_acc);
sd_NB = std(NB_acc);

fprintf('\nAB Mean Accuracy = %.3f (SD = %.3f)\n', mean_AB, sd_AB);
fprintf('NB Mean Accuracy = %.3f (SD = %.3f)\n', mean_NB, sd_NB);

% Standard Error
se_AB = sd_AB / sqrt(length(AB_acc));
se_NB = sd_NB / sqrt(length(NB_acc));


%%Bar plot

figure; hold on;

bar([1 2], [mean_AB mean_NB]);   

errorbar([1 2], [mean_AB mean_NB], [se_AB se_NB], ...
    'LineStyle','none','LineWidth',1.5);

set(gca,'XTick',[1 2],'XTickLabel',{'AB','NB'});
ylabel('Mean Recognition Accuracy');
title('Overall Recognition Accuracy: Abrupt vs Natural Boundaries');

box off;
hold off;


%%DISTRIBUTION CHECK

figure;

subplot(1,2,1)
histogram(AB_acc);
title('AB Accuracy Distribution');
xlabel('Accuracy'); ylabel('Count');

subplot(1,2,2)
histogram(NB_acc);
title('NB Accuracy Distribution');
xlabel('Accuracy'); ylabel('Count');


%%Mann-whitney

[p,~,stats] = ranksum(NB_acc, AB_acc);

fprintf('\nMann–Whitney U Test:\n');
fprintf('U = %.3f, p = %.4f\n', stats.ranksum, p);


%%effect size (rank biserial r)

n1 = length(NB_acc);
n2 = length(AB_acc);

U = stats.ranksum - n1*(n1+1)/2;  
r = 1 - (2*U)/(n1*n2);

fprintf('Effect size (rank-biserial r) = %.3f\n', r);

%% ================= BB vs EM ACCURACY =================

AB_BB = zeros(length(AB),1);
AB_EM = zeros(length(AB),1);

NB_BB = zeros(length(NB),1);
NB_EM = zeros(length(NB),1);

%%BB and EM accuracy (AB)
for i = 1:length(AB)

    T = AB(i).data;

    % Recognition trials only
    valid = ~isnan(T.resp_corr);

    stim = T.target_img(valid);
    corr = T.resp_corr(valid);

    % Identify trial type
    isBB = contains(stim,'_BB_');
    isEM = contains(stim,'_EM_');

    % Mean accuracy within participant
    AB_BB(i) = mean(corr(isBB),'omitnan');
    AB_EM(i) = mean(corr(isEM),'omitnan');

end


%%BB and EM accuracy (NB)
for i = 1:length(NB)

    T = NB(i).data;

    valid = ~isnan(T.resp_corr);

    stim = T.target_img(valid);
    corr = T.resp_corr(valid);

    isBB = contains(stim,'_BB_');
    isEM = contains(stim,'_EM_');

    NB_BB(i) = mean(corr(isBB),'omitnan');
    NB_EM(i) = mean(corr(isEM),'omitnan');

end

% Wilcoxon Signed-Rank Test (BB vs EM within each condition)

% AB
[p_AB,~,stats_AB] = signrank(AB_BB, AB_EM);

fprintf('\nAB Condition: BB vs EM\n');
fprintf('Signed-rank p = %.4f\n', p_AB);

% NB
[p_NB,~,stats_NB] = signrank(NB_BB, NB_EM);

fprintf('\nNB Condition: BB vs EM\n');
fprintf('Signed-rank p = %.4f\n', p_NB);


%%EFFECT SIZE (r = Z / sqrt(N))

z_AB = stats_AB.zval;
r_AB = z_AB / sqrt(length(AB_BB));

z_NB = stats_NB.zval;
r_NB = z_NB / sqrt(length(NB_BB));

fprintf('Effect size r (AB) = %.3f\n', r_AB);
fprintf('Effect size r (NB) = %.3f\n', r_NB);


%%DESCRIPTIVE MEANS

mean_AB_BB = mean(AB_BB);
mean_AB_EM = mean(AB_EM);

mean_NB_BB = mean(NB_BB);
mean_NB_EM = mean(NB_EM);

plot_data = [
    mean_AB_BB  mean_AB_EM;
    mean_NB_BB  mean_NB_EM
];


%%Plots

figure;
bar(plot_data);

set(gca,'XTick',1:2);
set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});

legend({'Boundary (BB)','Event-Middle (EM)'},'Location','northwest');

ylabel('Recognition Accuracy');
title('Boundary Advantage Within Each Condition');

box off;


%%BB effects
[p_BB,~,stats_BB] = ranksum(NB_BB, AB_BB);

fprintf('\nBB Accuracy Comparison (NB vs AB):\n');
fprintf('U = %.3f, p = %.4f\n', stats_BB.ranksum, p_BB);
n1 = length(NB_BB);
n2 = length(AB_BB);

U = stats_BB.ranksum - n1*(n1+1)/2;
r_BB = 1 - (2*U)/(n1*n2);

fprintf('Effect size r = %.3f\n', r_BB);

%EM effects
[p_EM,~,stats_EM] = ranksum(NB_EM, AB_EM);

fprintf('\nEM Accuracy Comparison (NB vs AB):\n');
fprintf('U = %.3f, p = %.4f\n', stats_EM.ranksum, p_EM);

n1 = length(NB_EM);
n2 = length(AB_EM);

U = stats_EM.ranksum - n1*(n1+1)/2;
r_EM = 1 - (2*U)/(n1*n2);

fprintf('Effect size r = %.3f\n', r_EM);

%%PLots
mean_AB = [mean(AB_BB) mean(AB_EM)];
mean_NB = [mean(NB_BB) mean(NB_EM)];
se_AB = [std(AB_BB)/sqrt(length(AB_BB))  std(AB_EM)/sqrt(length(AB_EM))];
se_NB = [std(NB_BB)/sqrt(length(NB_BB))  std(NB_EM)/sqrt(length(NB_EM))];

plot_means = [
    mean_AB;
    mean_NB
];

plot_se = [
    se_AB;
    se_NB
];

figure;
b = bar(plot_means);  % grouped bars
hold on;
[ngroups, nbars] = size(plot_means);

x = nan(nbars, ngroups);
for i = 1:nbars
    x(i,:) = b(i).XEndPoints;
end

errorbar(x', plot_means, plot_se, 'k', 'linestyle','none','LineWidth',1.2);
set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});

legend({'Boundary (BB)','Event-Middle (EM)'}, 'Location','northwest');

ylabel('Recognition Accuracy');
title('Recognition Accuracy by Condition and Frame Type');

ylim([0.5 1]);   % adjust if needed
box off;

%%D-prime
AB_hit_BB = [];
AB_hit_EM = [];
AB_FA     = [];
AB_dBB    = [];
AB_dEM    = [];

NB_hit_BB = [];
NB_hit_EM = [];
NB_FA     = [];
NB_dBB    = [];
NB_dEM    = [];

%AB
for i = 1:length(AB)

    T = AB(i).data;

    valid = ~isnan(T.resp_corr);
    stim  = T.target_img(valid);
    corr  = T.resp_corr(valid);

    isBB   = contains(stim,'_BB_');
    isEM   = contains(stim,'_EM_');
    isLure = contains(stim,'_L');   % lure trials

    % Counts
    nBB   = sum(isBB);
    nEM   = sum(isEM);
    nLure = sum(isLure);

    hitsBB = sum(corr(isBB));
    hitsEM = sum(corr(isEM));
    FA     = sum(corr(isLure)==0); % lure incorrect = false alarm

    % Log-linear correction
    hitRate_BB = (hitsBB + 0.5) / (nBB + 1);
    hitRate_EM = (hitsEM + 0.5) / (nEM + 1);
    FARate     = (FA + 0.5)     / (nLure + 1);

    % Store rates
    AB_hit_BB(end+1,1) = hitRate_BB;
    AB_hit_EM(end+1,1) = hitRate_EM;
    AB_FA(end+1,1)     = FARate;

    % d-prime
    AB_dBB(end+1,1) = norminv(hitRate_BB) - norminv(FARate);
    AB_dEM(end+1,1) = norminv(hitRate_EM) - norminv(FARate);

end

%NB
for i = 1:length(NB)

    T = NB(i).data;

    valid = ~isnan(T.resp_corr);
    stim  = T.target_img(valid);
    corr  = T.resp_corr(valid);

    isBB   = contains(stim,'_BB_');
    isEM   = contains(stim,'_EM_');
    isLure = contains(stim,'_L');

    nBB   = sum(isBB);
    nEM   = sum(isEM);
    nLure = sum(isLure);

    hitsBB = sum(corr(isBB));
    hitsEM = sum(corr(isEM));
    FA     = sum(corr(isLure)==0);

    hitRate_BB = (hitsBB + 0.5) / (nBB + 1);
    hitRate_EM = (hitsEM + 0.5) / (nEM + 1);
    FARate     = (FA + 0.5)     / (nLure + 1);

    NB_hit_BB(end+1,1) = hitRate_BB;
    NB_hit_EM(end+1,1) = hitRate_EM;
    NB_FA(end+1,1)     = FARate;

    NB_dBB(end+1,1) = norminv(hitRate_BB) - norminv(FARate);
    NB_dEM(end+1,1) = norminv(hitRate_EM) - norminv(FARate);

end

%Boundary advantage within AB
[p_AB_d,~,stats_AB_d] = signrank(AB_dBB, AB_dEM);

fprintf('\nAB Condition (d-prime): BB vs EM\n');
fprintf('p = %.4f\n', p_AB_d);

z = stats_AB_d.zval;
r = z / sqrt(length(AB_dBB));

fprintf('Effect size r = %.3f\n', r);

%boundary advantage within NB
[p_BB,~,stats_BB] = ranksum(NB_dBB, AB_dBB);

z = stats_BB.zval;
N = length(NB_dBB) + length(AB_dBB);

r_BB = z / sqrt(N);

fprintf('Effect size r (Z-based) = %.3f\n', r_BB);

%Comparing boundary frames
[p_BB_d,~,stats_BB_d] = ranksum(NB_dBB, AB_dBB);

fprintf('\nd-prime BB: NB vs AB\n');
fprintf('U = %.3f, p = %.4f\n', stats_BB_d.ranksum, p_BB_d);
n1 = length(NB_dBB);
n2 = length(AB_dBB);

U = stats_BB_d.ranksum - n1*(n1+1)/2;
r = 1 - (2*U)/(n1*n2);
fprintf('Effect size r = %.3f\n', r);

%Event middle
[p_EM_d,~,stats_EM_d] = ranksum(NB_dEM, AB_dEM);

fprintf('\nd-prime EM: NB vs AB\n');
fprintf('U = %.3f, p = %.4f\n', stats_EM_d.ranksum, p_EM_d);
n1 = length(NB_dEM);
n2 = length(AB_dEM);

U = stats_EM_d.ranksum - n1*(n1+1)/2;
r = 1 - (2*U)/(n1*n2);

fprintf('Effect size r = %.3f\n', r);

%Plots
%% Means
mean_AB = [mean(AB_dBB) mean(AB_dEM)];
mean_NB = [mean(NB_dBB) mean(NB_dEM)];

%% Standard Error of the Mean (SEM)
se_AB = [std(AB_dBB)/sqrt(length(AB_dBB))  std(AB_dEM)/sqrt(length(AB_dEM))];
se_NB = [std(NB_dBB)/sqrt(length(NB_dBB))  std(NB_dEM)/sqrt(length(NB_dEM))];

plot_means = [
    mean_AB;
    mean_NB
];

plot_se = [
    se_AB;
    se_NB
];

figure;
b = bar(plot_means);   % grouped bars
hold on;
[ngroups, nbars] = size(plot_means);

x = nan(nbars, ngroups);
for i = 1:nbars
    x(i,:) = b(i).XEndPoints;
end

errorbar(x', plot_means, plot_se, 'linestyle','none','LineWidth',1.2);
set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});

legend({'Boundary (BB)','Event-Middle (EM)'}, 'Location','northwest');

ylabel('d-prime');
title('d′ by Condition and Frame Type');

box off;

%%FA rates
mean_FA_AB = mean(AB_FA);
mean_FA_NB = mean(NB_FA);

se_FA_AB = std(AB_FA) / sqrt(length(AB_FA));
se_FA_NB = std(NB_FA) / sqrt(length(NB_FA));
figure;
b = bar([1 2], [mean_FA_AB mean_FA_NB]);
hold on;
errorbar([1 2], [mean_FA_AB mean_FA_NB], ...
         [se_FA_AB se_FA_NB], ...
         'linestyle','none','LineWidth',1.2);
set(gca,'XTick',[1 2]);
set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});

ylabel('False Alarm Rate');
title('Response Bias Check: False Alarm Rates by Condition');

ylim([0 1]);
box off;

%%RESPONSE TIME ANALYSIS
%AB
AB_RT_BB = [];
AB_RT_EM = [];

for i = 1:length(AB)

    T = AB(i).data;

    % --- Clean RT strings like "[4.404]" ---
    rt_txt = string(T.resp_rt);
    rt_txt = erase(rt_txt,'[');
    rt_txt = erase(rt_txt,']');

    rt_all = str2double(rt_txt);   % now converts properly

    valid = ~isnan(rt_all) & T.resp_corr==1;

    stim = T.target_img(valid);
    rt   = rt_all(valid);

    isBB = contains(stim,'_BB_');
    isEM = contains(stim,'_EM_');

    AB_RT_BB(end+1,1) = median(rt(isBB),'omitnan');
    AB_RT_EM(end+1,1) = median(rt(isEM),'omitnan');

end
%NB
NB_RT_BB = [];
NB_RT_EM = [];

for i = 1:length(NB)

    T = NB(i).data;

    rt_txt = string(T.resp_rt);
    rt_txt = erase(rt_txt,'[');
    rt_txt = erase(rt_txt,']');

    rt_all = str2double(rt_txt);

    valid = ~isnan(rt_all) & T.resp_corr==1;

    stim = T.target_img(valid);
    rt   = rt_all(valid);

    isBB = contains(stim,'_BB_');
    isEM = contains(stim,'_EM_');

    NB_RT_BB(end+1,1) = median(rt(isBB),'omitnan');
    NB_RT_EM(end+1,1) = median(rt(isEM),'omitnan');

end

%RT exclusion
AB_RT_BB(AB_RT_BB < 0.3) = NaN;
AB_RT_EM(AB_RT_EM < 0.3) = NaN;

NB_RT_BB(NB_RT_BB < 0.3) = NaN;
NB_RT_EM(NB_RT_EM < 0.3) = NaN;

%Within condition: BB recognized faster than EM?
%AB
paired_AB = ~isnan(AB_RT_BB) & ~isnan(AB_RT_EM);

AB_RT_BB_clean = AB_RT_BB(paired_AB);
AB_RT_EM_clean = AB_RT_EM(paired_AB);

[p_AB_RT,~,stats_AB_RT] = signrank(AB_RT_BB_clean, AB_RT_EM_clean);

fprintf('\nAB RT: BB vs EM\n');
fprintf('N = %d, p = %.4f\n', length(AB_RT_BB_clean), p_AB_RT);

z = stats_AB_RT.zval;
r = z / sqrt(length(AB_RT_BB_clean));

fprintf('Effect size r = %.3f\n', r);

%NB
paired_NB = ~isnan(NB_RT_BB) & ~isnan(NB_RT_EM);

NB_RT_BB_clean = NB_RT_BB(paired_NB);
NB_RT_EM_clean = NB_RT_EM(paired_NB);

[p_NB_RT,~,stats_NB_RT] = signrank(NB_RT_BB_clean, NB_RT_EM_clean);

fprintf('\nNB RT: BB vs EM\n');
fprintf('N = %d, p = %.4f\n', length(NB_RT_BB_clean), p_NB_RT);

z = stats_NB_RT.zval;
r = z / sqrt(length(NB_RT_BB_clean));

fprintf('Effect size r = %.3f\n', r);

%%Between condition: AB vs NB
%BB
AB_BB_valid = AB_RT_BB(~isnan(AB_RT_BB));
NB_BB_valid = NB_RT_BB(~isnan(NB_RT_BB));

[p_BB_RT,~,stats] = ranksum(NB_BB_valid, AB_BB_valid);

fprintf('\nRT Comparison (BB): NB vs AB\n');
fprintf('N_AB = %d, N_NB = %d, p = %.4f\n', length(AB_BB_valid), length(NB_BB_valid), p_BB_RT);

%EM
AB_EM_valid = AB_RT_EM(~isnan(AB_RT_EM));
NB_EM_valid = NB_RT_EM(~isnan(NB_RT_EM));

[p_EM_RT,~,stats] = ranksum(NB_EM_valid, AB_EM_valid);

fprintf('\nRT Comparison (EM): NB vs AB\n');
fprintf('N_AB = %d, N_NB = %d, p = %.4f\n', length(AB_EM_valid), length(NB_EM_valid), p_EM_RT);

%Plot
figure;

means = [
    mean(AB_RT_BB_clean) mean(AB_RT_EM_clean);
    mean(NB_RT_BB_clean) mean(NB_RT_EM_clean)
];

bar(means);

set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});
legend({'Boundary (BB)','Event-Middle (EM)'});

ylabel('Median RT (seconds)');
title('Recognition Reaction Times');

box off;

%%Speed accuracy tradeoff
AB_RT_overall = nanmedian([AB_RT_BB AB_RT_EM],2);
NB_RT_overall = nanmedian([NB_RT_BB NB_RT_EM],2);
%AB
% Keep only participants with both RT and accuracy
valid_AB = ~isnan(AB_RT_overall) & ~isnan(AB_acc);

rt_AB  = AB_RT_overall(valid_AB);
acc_AB = AB_acc(valid_AB);

% Convert to ranks (Spearman step)
rt_rank  = tiedrank(rt_AB);
acc_rank = tiedrank(acc_AB);

% Pearson correlation on the ranks
[R_AB,P_AB] = corrcoef(rt_rank, acc_rank);

rho_AB = R_AB(1,2);
p_AB   = P_AB(1,2);

fprintf('AB Speed–Accuracy:\n');
fprintf('rho = %.3f, p = %.4f, N = %d\n', rho_AB, p_AB, length(rt_AB));
%NB
valid_NB = ~isnan(NB_RT_overall) & ~isnan(NB_acc);

rt_NB  = NB_RT_overall(valid_NB);
acc_NB = NB_acc(valid_NB);

rt_rank  = tiedrank(rt_NB);
acc_rank = tiedrank(acc_NB);

[R_NB,P_NB] = corrcoef(rt_rank, acc_rank);

rho_NB = R_NB(1,2);
p_NB   = P_NB(1,2);

fprintf('\nNB Speed–Accuracy:\n');
fprintf('rho = %.3f, p = %.4f, N = %d\n', rho_NB, p_NB, length(rt_NB));

%Plot
figure;

%% ---------- AB ----------
subplot(1,2,1)

valid_AB = ~isnan(AB_RT_overall) & ~isnan(AB_acc);

scatter(AB_RT_overall(valid_AB), AB_acc(valid_AB), 'filled');
hold on;

lsline;   % visual trend line only

xlabel('Median RT (s)');
ylabel('Recognition Accuracy');
title('Abrupt Condition (AB)');

box off;


%% ---------- NB ----------
subplot(1,2,2)

valid_NB = ~isnan(NB_RT_overall) & ~isnan(NB_acc);

scatter(NB_RT_overall(valid_NB), NB_acc(valid_NB), 'filled');
hold on;

lsline;

xlabel('Median RT (s)');
ylabel('Recognition Accuracy');
title('Natural Condition (NB)');

box off;

%%CONFIDENCE RARING ANALYSIS
%AB
AB_conf = [];

for i = 1:length(AB)

    T = AB(i).data;

    conf = str2double(string(T.conf_radio_response));  % convert safely

    % keep only trials where a confidence response exists
    conf = conf(~isnan(conf));

    AB_conf(end+1,1) = mean(conf,'omitnan');

end

%NB
NB_conf = [];

for i = 1:length(NB)

    T = NB(i).data;

    conf = str2double(string(T.conf_radio_response));

    conf = conf(~isnan(conf));

    NB_conf(end+1,1) = mean(conf,'omitnan');

end

[p_conf,~,stats_conf] = ranksum(NB_conf, AB_conf);

fprintf('Confidence Comparison (NB vs AB):\n');
fprintf('U = %.3f, p = %.4f\n', stats_conf.ranksum, p_conf);
n1 = length(NB_conf);
n2 = length(AB_conf);

U = stats_conf.ranksum - n1*(n1+1)/2;
r = 1 - (2*U)/(n1*n2);

fprintf('Effect size r = %.3f\n', r);
%Plot
figure;

means = [mean(AB_conf) mean(NB_conf)];
bar(means);
hold on;

se = [std(AB_conf)/sqrt(length(AB_conf)) ...
      std(NB_conf)/sqrt(length(NB_conf))];

errorbar([1 2], means, se, 'linestyle','none','LineWidth',1.2);

set(gca,'XTick',[1 2]);
set(gca,'XTickLabel',{'Abrupt (AB)','Natural (NB)'});

ylabel('Mean Confidence Rating');
title('Confidence by Condition');

box off;

%%Does confidence track accuracy differently in AB vs NB?
%AB
AB_meta = [];

for i = 1:length(AB)

    T = AB(i).data;

    conf = string(T.conf_radio_response);
    conf(conf=="None" | conf=="") = missing;
    conf = str2double(conf);

    corrv = double(T.resp_corr);

    valid = ~isnan(conf) & ~isnan(corrv);
    conf  = conf(valid);
    corrv = corrv(valid);

    if numel(conf) >= 10 && numel(unique(corrv)) > 1

        conf_rank = tiedrank(conf);
        corr_rank = tiedrank(corrv);

        R = corrcoef(conf_rank, corr_rank);
        rho = R(1,2);

        AB_meta(end+1,1) = rho;

    end

end
%NB
NB_meta = [];

for i = 1:length(NB)

    T = NB(i).data;

    % --- Clean confidence column ---
    conf = string(T.conf_radio_response);
    conf(conf=="None" | conf=="") = missing;
    conf = str2double(conf);

    % --- Correctness ---
    corrv = double(T.resp_corr);

    % --- Keep valid rows only ---
    valid = ~isnan(conf) & ~isnan(corrv);
    conf  = conf(valid);
    corrv = corrv(valid);

    % Need enough trials AND variability
    if numel(conf) >= 10 && numel(unique(corrv)) > 1

        % ----- Manual Spearman -----
        conf_rank  = tiedrank(conf);
        corr_rank  = tiedrank(corrv);

        R = corrcoef(conf_rank, corr_rank);
        rho = R(1,2);

        NB_meta(end+1,1) = rho;

    end

end

[p_meta,~,stats_meta] = ranksum(NB_meta, AB_meta);

fprintf('Confidence accuracy relationship');
fprintf('U = %.3f, p = %.4f\n', stats_meta.ranksum, p_meta);
%Plot
mAB = mean(AB_meta,'omitnan');
mNB = mean(NB_meta,'omitnan');

seAB = std(AB_meta,'omitnan') / sqrt(sum(~isnan(AB_meta)));
seNB = std(NB_meta,'omitnan') / sqrt(sum(~isnan(NB_meta)));
figure; hold on;

bar([1 2],[mAB mNB],0.6);

errorbar([1 2],[mAB mNB],[seAB seNB], ...
    'k','linestyle','none','LineWidth',1.2);

scatter(ones(size(AB_meta))*1, AB_meta,20,'filled','MarkerFaceAlpha',0.35);
scatter(ones(size(NB_meta))*2, NB_meta,20,'filled','MarkerFaceAlpha',0.35);

set(gca,'XTick',[1 2],'XTickLabel',{'Abrupt (AB)','Natural (NB)'});
ylabel('Confidence–Accuracy Correlation (Spearman \rho)');
title('Confidence-Accuracy relationship comparison between AB and NB');

yline(0,'--','HandleVisibility','off');
xlim([0.5 2.5]);
box off;

%HIGH Confidence accuracy
%AB
AB_highAcc = [];

for i = 1:length(AB)

    T = AB(i).data;

    conf  = str2double(string(T.conf_radio_response));
    corrv = double(T.resp_corr);

    valid = ~isnan(conf) & ~isnan(corrv);

    conf  = conf(valid);
    corrv = corrv(valid);

    high = conf == 5;   % <-- define high confidence properly

    if sum(high) >= 5   % ensure stability
        AB_highAcc(end+1,1) = mean(corrv(high));
    else
        AB_highAcc(end+1,1) = NaN;
    end

end

%NB
NB_highAcc = [];

for i = 1:length(NB)

    T = NB(i).data;

    conf  = str2double(string(T.conf_radio_response));
    corrv = double(T.resp_corr);

    valid = ~isnan(conf) & ~isnan(corrv);

    conf  = conf(valid);
    corrv = corrv(valid);

    high = conf == 5;

    if sum(high) >= 5
        NB_highAcc(end+1,1) = mean(corrv(high));
    else
        NB_highAcc(end+1,1) = NaN;
    end

end

%ABvs NB
[p_high,~,stats_high] = ranksum(NB_highAcc, AB_highAcc);

fprintf('High-Confidence Accuracy Comparison:\n');
fprintf('U = %.3f, p = %.4f\n', stats_high.ranksum, p_high);

%Plot
figure; hold on;

mAB = mean(AB_highAcc,'omitnan');
mNB = mean(NB_highAcc,'omitnan');

seAB = std(AB_highAcc,'omitnan')/sqrt(sum(~isnan(AB_highAcc)));
seNB = std(NB_highAcc,'omitnan')/sqrt(sum(~isnan(NB_highAcc)));

bar([1 2],[mAB mNB],0.6);
errorbar([1 2],[mAB mNB],[seAB seNB],'k','linestyle','none','LineWidth',1.2);

set(gca,'XTick',[1 2],'XTickLabel',{'Abrupt (AB)','Natural (NB)'});
ylabel('Accuracy (Confidence = 5)');
title('High-Confidence Recognition Accuracy');

box off;

%Spaghetti plots
%% Spaghetti + Raincloud Plots

figure;
set(gcf,'Color','w');

x = [1 2]; % BB, EM

% Colorblind friendly palette (Okabe–Ito)
col_AB = [0 114 178]/255;    % dark blue
col_NB = [213 94 0]/255;     % dark vermillion  
grey   = [0.75 0.75 0.75];

%% ================= AB =================
subplot(1,2,1); hold on;

% ----- Raincloud KDE -----
[fBB,xiBB] = ksdensity(AB_BB,'Bandwidth',0.03);
[fEM,xiEM] = ksdensity(AB_EM,'Bandwidth',0.03);

patch(1 - fBB*0.15, xiBB, col_AB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_AB,'FaceAlpha',0.25,'EdgeColor','none');

% ----- Jittered data points -----
scatter(1 + (rand(size(AB_BB))-0.5)*0.08, AB_BB, ...
    25, col_AB,'filled','MarkerFaceAlpha',0.6);

scatter(2 + (rand(size(AB_EM))-0.5)*0.08, AB_EM, ...
    25, col_AB,'filled','MarkerFaceAlpha',0.6);

% ----- Spaghetti lines -----
for i = 1:length(AB_BB)

    if ~isnan(AB_BB(i)) && ~isnan(AB_EM(i))
        plot(x,[AB_BB(i) AB_EM(i)],'-','Color',grey);
    end

end

% ----- Mean line -----
mean_AB = [mean(AB_BB,'omitnan') mean(AB_EM,'omitnan')];

plot(x,mean_AB,'-o',...
    'Color',col_AB,...
    'MarkerFaceColor',col_AB,...
    'LineWidth',3,...
    'MarkerSize',8);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('Recognition Accuracy');
title('Abrupt Condition (AB)');
ylim([0.5 1]);
box off;


%% ================= NB =================
subplot(1,2,2); hold on;

% ----- Raincloud KDE -----
[fBB,xiBB] = ksdensity(NB_BB,'Bandwidth',0.03);
[fEM,xiEM] = ksdensity(NB_EM,'Bandwidth',0.03);

patch(1 - fBB*0.15, xiBB, col_NB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_NB,'FaceAlpha',0.25,'EdgeColor','none');

% ----- Jittered points -----
scatter(1 + (rand(size(NB_BB))-0.5)*0.08, NB_BB, ...
    25, col_NB,'filled','MarkerFaceAlpha',0.6);

scatter(2 + (rand(size(NB_EM))-0.5)*0.08, NB_EM, ...
    25, col_NB,'filled','MarkerFaceAlpha',0.6);

% ----- Spaghetti lines -----
for i = 1:length(NB_BB)

    if ~isnan(NB_BB(i)) && ~isnan(NB_EM(i))
        plot(x,[NB_BB(i) NB_EM(i)],'-','Color',grey);
    end

end

% ----- Mean line -----
mean_NB = [mean(NB_BB,'omitnan') mean(NB_EM,'omitnan')];

plot(x,mean_NB,'-o',...
    'Color',col_NB,...
    'MarkerFaceColor',col_NB,...
    'LineWidth',3,...
    'MarkerSize',8);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
title('Natural Condition (NB)');
ylim([0.5 1]);
box off;

%% Spaghetti Plot: RT (BB vs EM) for AB and NB

%% Raincloud + Spaghetti Plot: RT (BB vs EM)

figure;
set(gcf,'Color','w');

x = [1 2]; % BB, EM

% Colourblind-safe palette
col_AB = [0 114 178]/255;    % dark blue
col_NB = [213 94 0]/255;     % dark vermillion
grey   = [0.85 0.85 0.85];

%% ================= AB =================
subplot(1,2,1); hold on;

valid_AB = ~isnan(AB_RT_BB) & ~isnan(AB_RT_EM);

AB_BB_clean = AB_RT_BB(valid_AB);
AB_EM_clean = AB_RT_EM(valid_AB);

% --- Raincloud KDE ---
[fBB,xiBB] = ksdensity(AB_BB_clean,'Bandwidth',0.2);
[fEM,xiEM] = ksdensity(AB_EM_clean,'Bandwidth',0.2);

patch(1 - fBB*0.15, xiBB, col_AB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_AB,'FaceAlpha',0.25,'EdgeColor','none');

% --- Jittered points ---
scatter(1 + (rand(size(AB_BB_clean))-0.5)*0.08, AB_BB_clean, ...
    25, col_AB,'filled','MarkerFaceAlpha',0.6);

scatter(2 + (rand(size(AB_EM_clean))-0.5)*0.08, AB_EM_clean, ...
    25, col_AB,'filled','MarkerFaceAlpha',0.6);

% --- Spaghetti lines ---
for i = 1:length(AB_BB_clean)
    plot(x,[AB_BB_clean(i) AB_EM_clean(i)],'-','Color',grey);
end

% --- Mean line ---
mean_AB = [mean(AB_BB_clean) mean(AB_EM_clean)];

plot(x,mean_AB,'-o',...
    'Color',col_AB,...
    'MarkerFaceColor',col_AB,...
    'LineWidth',3,...
    'MarkerSize',8);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('Median RT (seconds)');
ylim([2 9])
title('Abrupt Condition (AB)');
box off;



%% ================= NB =================
subplot(1,2,2); hold on;

valid_NB = ~isnan(NB_RT_BB) & ~isnan(NB_RT_EM);

NB_BB_clean = NB_RT_BB(valid_NB);
NB_EM_clean = NB_RT_EM(valid_NB);

% --- Raincloud KDE ---
[fBB,xiBB] = ksdensity(NB_BB_clean,'Bandwidth',0.2);
[fEM,xiEM] = ksdensity(NB_EM_clean,'Bandwidth',0.2);

patch(1 - fBB*0.15, xiBB, col_NB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_NB,'FaceAlpha',0.25,'EdgeColor','none');

% --- Jittered points ---
scatter(1 + (rand(size(NB_BB_clean))-0.5)*0.08, NB_BB_clean, ...
    25, col_NB,'filled','MarkerFaceAlpha',0.6);

scatter(2 + (rand(size(NB_EM_clean))-0.5)*0.08, NB_EM_clean, ...
    25, col_NB,'filled','MarkerFaceAlpha',0.6);

% --- Spaghetti lines ---
for i = 1:length(NB_BB_clean)
    plot(x,[NB_BB_clean(i) NB_EM_clean(i)],'-','Color',grey);
end

% --- Mean line ---
mean_NB = [mean(NB_BB_clean) mean(NB_EM_clean)];

plot(x,mean_NB,'-o',...
    'Color',col_NB,...
    'MarkerFaceColor',col_NB,...
    'LineWidth',3,...
    'MarkerSize',8);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylim([2 9])
title('Natural Condition (NB)');
box off;