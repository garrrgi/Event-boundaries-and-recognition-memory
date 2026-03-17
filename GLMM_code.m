%%Load data%%
dataPath = 'C:\Users\Gargi\Downloads\BRSM data csv (1)\BRSM data csv'; 
cd(dataPath);

files  = dir('sub*_*.csv');
nFiles = numel(files);
fprintf('Found %d participant files.\n', nFiles);

AllData = table;

%Loop through AB
AllData = table;

for i = 1:length(AB)

    T = AB(i).data;

    fname = string(T.target_img);
    valid = contains(fname,"_BB_") | contains(fname,"_EM_");

    fname = fname(valid);
    acc   = T.resp_corr(valid);

    % --- Extract RT properly ---
    rt_raw = string(T.resp_rt(valid));
    rt_raw = erase(rt_raw,"[");
    rt_raw = erase(rt_raw,"]");
    rt = str2double(rt_raw);

    pid  = repmat(i, length(acc),1);
    cond = repmat("AB", length(acc),1);

    boundary = strings(size(fname));
    boundary(contains(fname,"_BB_")) = "BB";
    boundary(contains(fname,"_EM_")) = "EM";

    movie = extractBetween(fname,"Vid","_");
    movie = "Vid" + movie;

    temp = table(pid, cond, movie, boundary, acc, rt, ...
        'VariableNames',{'Participant','Condition','Movie','Boundary','Accuracy','RT'});

    AllData = [AllData; temp];

end

%Loop through NB
offset = length(AB);

for i = 1:length(NB)

    T = NB(i).data;

    fname = string(T.target_img);
    valid = contains(fname,"_BB_") | contains(fname,"_EM_");

    fname = fname(valid);
    acc   = T.resp_corr(valid);

    rt_raw = string(T.resp_rt(valid));
    rt_raw = erase(rt_raw,"[");
    rt_raw = erase(rt_raw,"]");
    rt = str2double(rt_raw);

    pid  = repmat(i+offset, length(acc),1);
    cond = repmat("NB", length(acc),1);

    boundary = strings(size(fname));
    boundary(contains(fname,"_BB_")) = "BB";
    boundary(contains(fname,"_EM_")) = "EM";

    movie = extractBetween(fname,"Vid","_");
    movie = "Vid" + movie;

    temp = table(pid, cond, movie, boundary, acc, rt, ...
        'VariableNames',{'Participant','Condition','Movie','Boundary','Accuracy','RT'});

    AllData = [AllData; temp];

end

%Categorical conversion
AllData.Participant = categorical(AllData.Participant);
AllData.Condition   = categorical(AllData.Condition);
AllData.Movie       = categorical(AllData.Movie);
AllData.Boundary    = categorical(AllData.Boundary);
AllData.Accuracy    = double(AllData.Accuracy);
AllData.RT          = double(AllData.RT);

%Check
summary(AllData)

%Fit base GLMM
glme = fitglme(AllData, ...
'Accuracy ~ Boundary*Condition + (1|Participant) + (1|Movie)', ...
'Distribution','Binomial','Link','logit');
glme


%model predicted accuracies
% Get reference levels automatically from model
newData = table;

newData.Condition = categorical(["AB";"AB";"NB";"NB"]);
newData.Boundary  = categorical(["BB";"EM";"BB";"EM"]);

% Dummy placeholders for random effects (required by predict)
newData.Participant = categorical(ones(4,1));
newData.Movie       = categorical(ones(4,1));
%Get predicted log odds
logit_pred = predict(glme, newData, ...
    'Conditional',false);   % marginal (fixed effects only)
prob_pred = exp(logit_pred) ./ (1 + exp(logit_pred));

%plot
[logit_pred, CI] = predict(glme, newData,'Conditional',false);

% Convert to probability scale
prob_pred = exp(logit_pred)./(1+exp(logit_pred));

prob_low  = exp(CI(:,1))./(1+exp(CI(:,1)));
prob_high = exp(CI(:,2))./(1+exp(CI(:,2)));

p_AB_BB = prob_pred(1);
p_AB_EM = prob_pred(2);
p_NB_BB = prob_pred(3);
p_NB_EM = prob_pred(4);

low_AB_BB = prob_low(1);
low_AB_EM = prob_low(2);
low_NB_BB = prob_low(3);
low_NB_EM = prob_low(4);

high_AB_BB = prob_high(1);
high_AB_EM = prob_high(2);
high_NB_BB = prob_high(3);
high_NB_EM = prob_high(4);

figure; hold on;

x = [1 2]; % AB, NB

% BB line
plot(x,[p_AB_BB p_NB_BB],'-o','LineWidth',2);

% EM line
plot(x,[p_AB_EM p_NB_EM],'-o','LineWidth',2);

% Add error bars manually
errorbar(1,p_AB_BB,...
    p_AB_BB-low_AB_BB,...
    high_AB_BB-p_AB_BB,'k','linestyle','none');

errorbar(2,p_NB_BB,...
    p_NB_BB-low_NB_BB,...
    high_NB_BB-p_NB_BB,'k','linestyle','none');

errorbar(1,p_AB_EM,...
    p_AB_EM-low_AB_EM,...
    high_AB_EM-p_AB_EM,'k','linestyle','none');

errorbar(2,p_NB_EM,...
    p_NB_EM-low_NB_EM,...
    high_NB_EM-p_NB_EM,'k','linestyle','none');

set(gca,'XTick',[1 2],'XTickLabel',{'AB','NB'});
ylabel('Predicted Accuracy');
xlabel('Condition');
legend({'BB','EM'},'Location','northwest');
ylim([0.65 0.80])
title('GLMM Estimated accuracy (BB reference)');
box off;
exportgraphics(gcf,'figure.pdf','ContentType','vector')
%odds ratio and CI
beta  = glme.Coefficients.Estimate;
SE    = glme.Coefficients.SE;
names = glme.CoefficientNames;

OR      = exp(beta);
CI_low  = exp(beta - 1.96*SE);
CI_high = exp(beta + 1.96*SE);

AccuracyTable = table(names', beta, SE, OR, CI_low, CI_high, ...
    'VariableNames',{'Effect','LogOdds','SE','OddsRatio','CI_low','CI_high'});

AccuracyTable

%%
%RT GLMM
RTData = AllData(AllData.Accuracy==1,:);

RTData.logRT = log(RTData.RT);

lmeRT = fitlme(RTData, ...
'logRT ~ Boundary*Condition + (1|Participant) + (1|Movie)');
lmeRT

%Plot
newData = table;

newData.Condition = categorical(["AB";"AB";"NB";"NB"]);
newData.Boundary  = categorical(["BB";"EM";"BB";"EM"]);

newData.Participant = categorical(ones(4,1));
newData.Movie       = categorical(ones(4,1));
%predict logRT
logRT_pred = predict(lmeRT, newData, 'Conditional',false);
%convert to seconds
RT_pred = exp(logRT_pred);

RT_AB_BB = RT_pred(1);
RT_AB_EM = RT_pred(2);
RT_NB_BB = RT_pred(3);
RT_NB_EM = RT_pred(4);

figure; hold on;

x = [1 2]; % AB, NB

plot(x,[RT_AB_BB RT_NB_BB],'-o','LineWidth',2);
plot(x,[RT_AB_EM RT_NB_EM],'-o','LineWidth',2);

set(gca,'XTick',[1 2],'XTickLabel',{'AB','NB'});
xlabel('Condition');
ylabel('Predicted RT (seconds)');
legend({'BB','EM'},'Location','northwest');
ylim([4.4 5.1])
title('GLMM-Predicted Reaction Time (AB reference)');
box off;
%%
%Overall summary table
AccCoef = glme.Coefficients;

Acc_OR      = exp(AccCoef.Estimate);
Acc_CI_low  = exp(AccCoef.Estimate - 1.96*AccCoef.SE);
Acc_CI_high = exp(AccCoef.Estimate + 1.96*AccCoef.SE);

AccSummary = table( ...
    AccCoef.Name, ...
    Acc_OR, ...
    Acc_CI_low, ...
    Acc_CI_high, ...
    AccCoef.pValue, ...
    'VariableNames',{'Effect','OddsRatio','CI_low','CI_high','pValue'});

RTCoef = lmeRT.Coefficients;

RT_percent = (exp(RTCoef.Estimate) - 1) * 100;

RTSummary = table( ...
    RTCoef.Name, ...
    RT_percent, ...
    RTCoef.pValue, ...
    'VariableNames',{'Effect','PercentChange','pValue'});

FinalSummary = table;

FinalSummary.Effect = ["Condition_NB"; ...
                       "Boundary_EM"; ...
                       "Condition_NB:Boundary_EM"];

% Accuracy
FinalSummary.Accuracy_OR = Acc_OR(2:4);
FinalSummary.Acc_CI_low  = Acc_CI_low(2:4);
FinalSummary.Acc_CI_high = Acc_CI_high(2:4);
FinalSummary.Acc_p       = AccCoef.pValue(2:4);

% RT
FinalSummary.RT_percentChange = RT_percent(2:4);
FinalSummary.RT_p             = RTCoef.pValue(2:4);

FinalSummary

%%
%Participant level differences
BoundaryAcc = varfun(@mean, AllData, ...
    'InputVariables','Accuracy', ...
    'GroupingVariables',{'Participant','Condition','Boundary'});
%split by codition
AB_data = BoundaryAcc(BoundaryAcc.Condition=="AB",:);
NB_data = BoundaryAcc(BoundaryAcc.Condition=="NB",:);

%Plot for AB
figure; hold on;

participants = unique(AB_data.Participant);

for i = 1:length(participants)

    p = participants(i);

    temp = AB_data(AB_data.Participant==p,:);

    % Ensure correct order: BB first, EM second
    BB_val = temp.mean_Accuracy(temp.Boundary=="BB");
    EM_val = temp.mean_Accuracy(temp.Boundary=="EM");

    plot([1 2],[BB_val EM_val],'-o','Color',[0.6 0.6 0.6], ...
        'MarkerSize',4);

end

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('Mean Accuracy');
title('Within-Participant Boundary Effect (AB)');
ylim([0.6 1]);
box off;
mean_BB = mean(AB_data.mean_Accuracy(AB_data.Boundary=="BB"));
mean_EM = mean(AB_data.mean_Accuracy(AB_data.Boundary=="EM"));

plot([1 2],[mean_BB mean_EM],'k-','LineWidth',3);

%Plot for NB
figure; hold on;

participants = unique(NB_data.Participant);

for i = 1:length(participants)

    p = participants(i);

    temp = NB_data(NB_data.Participant==p,:);

    BB_val = temp.mean_Accuracy(temp.Boundary=="BB");
    EM_val = temp.mean_Accuracy(temp.Boundary=="EM");

    plot([1 2],[BB_val EM_val],'-o','Color',[0.6 0.6 0.6], ...
        'MarkerSize',4);

end

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('Mean Accuracy');
title('Within-Participant Boundary Effect (NB)');
ylim([0.6 1]);
box off;

mean_BB = mean(NB_data.mean_Accuracy(NB_data.Boundary=="BB"));
mean_EM = mean(NB_data.mean_Accuracy(NB_data.Boundary=="EM"));

plot([1 2],[mean_BB mean_EM],'k-','LineWidth',3);




%% ---------- RT (Correct Trials Only) ----------

RT_correct = AllData(AllData.Accuracy==1,:);
BoundaryRT = varfun(@mean, RT_correct, ...
    'InputVariables','RT', ...
    'GroupingVariables',{'Participant','Condition','Boundary'});

AB_rt = BoundaryRT(BoundaryRT.Condition=="AB",:);
NB_rt = BoundaryRT(BoundaryRT.Condition=="NB",:);

% Get global RT limits across both conditions
allRT_means = [AB_rt.mean_RT; NB_rt.mean_RT];

ymin = min(allRT_means);
ymax = max(allRT_means);

% Add small padding
padding = 0.05 * (ymax - ymin);
ymin = ymin - padding;
ymax = ymax + padding;
% ----- RT AB -----
subplot(2,2,3); hold on;
participants = unique(AB_rt.Participant);

for i = 1:length(participants)
    p = participants(i);
    temp = AB_rt(AB_rt.Participant==p,:);
    BB_val = temp.mean_RT(temp.Boundary=="BB");
    EM_val = temp.mean_RT(temp.Boundary=="EM");
    plot([1 2],[BB_val EM_val],'-', ...
    'Color',AB_light, ...
    'LineWidth',1);
end

mean_BB = mean(AB_rt.mean_RT(AB_rt.Boundary=="BB"));
mean_EM = mean(AB_rt.mean_RT(AB_rt.Boundary=="EM"));
plot([1 2],[mean_BB mean_EM],'-','Color',AB_color,'LineWidth',4);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('RT (seconds)');
ylim([ymin ymax]);
title('Reaction Time — AB');
box off;


% ----- RT NB -----
subplot(2,2,4); hold on;
participants = unique(NB_rt.Participant);

for i = 1:length(participants)
    p = participants(i);
    temp = NB_rt(NB_rt.Participant==p,:);
    BB_val = temp.mean_RT(temp.Boundary=="BB");
    EM_val = temp.mean_RT(temp.Boundary=="EM");
    plot([1 2],[BB_val EM_val],'-', ...
    'Color',NB_light, ...
    'LineWidth',1);
end

mean_BB = mean(NB_rt.mean_RT(NB_rt.Boundary=="BB"));
mean_EM = mean(NB_rt.mean_RT(NB_rt.Boundary=="EM"));
plot([1 2],[mean_BB mean_EM],'-','Color',NB_color,'LineWidth',4);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylim([ymin ymax]);
title('Reaction Time — NB');
box off;

writetable(AllData, 'combined_data.csv')

%GLM with EM reference
%Fit base GLMM
AllData.Boundary = reordercats(AllData.Boundary, ["EM","BB"]);
glme_EMref = fitglme(AllData, ...
'Accuracy ~ Boundary*Condition + (1|Participant) + (1|Movie)', ...
'Distribution','Binomial','Link','logit');

glme_EMref

newData = table;

newData.Condition = categorical(["AB";"AB";"NB";"NB"]);
newData.Boundary  = categorical(["EM";"BB";"EM";"BB"]);  % EM first now

% Dummy placeholders (required)
newData.Participant = categorical(ones(4,1));
newData.Movie       = categorical(ones(4,1));

% Predict log-odds and CI
[logit_pred, CI] = predict(glme_EMref, newData,'Conditional',false);

% Convert to probability scale
prob_pred = exp(logit_pred)./(1+exp(logit_pred));
prob_low  = exp(CI(:,1))./(1+exp(CI(:,1)));
prob_high = exp(CI(:,2))./(1+exp(CI(:,2)));

p_AB_EM = prob_pred(1);
p_AB_BB = prob_pred(2);
p_NB_EM = prob_pred(3);
p_NB_BB = prob_pred(4);

low_AB_EM = prob_low(1);
low_AB_BB = prob_low(2);
low_NB_EM = prob_low(3);
low_NB_BB = prob_low(4);

high_AB_EM = prob_high(1);
high_AB_BB = prob_high(2);
high_NB_EM = prob_high(3);
high_NB_BB = prob_high(4);

figure; hold on;
set(gcf,'Color','w');

x = [1 2]; % AB, NB

% EM line
plot(x,[p_AB_EM p_NB_EM],'-o','LineWidth',2);

% BB line
plot(x,[p_AB_BB p_NB_BB],'-o','LineWidth',2);

% Error bars EM
errorbar(1,p_AB_EM,...
    p_AB_EM-low_AB_EM,...
    high_AB_EM-p_AB_EM,'k','linestyle','none');

errorbar(2,p_NB_EM,...
    p_NB_EM-low_NB_EM,...
    high_NB_EM-p_NB_EM,'k','linestyle','none');

% Error bars BB
errorbar(1,p_AB_BB,...
    p_AB_BB-low_AB_BB,...
    high_AB_BB-p_AB_BB,'k','linestyle','none');

errorbar(2,p_NB_BB,...
    p_NB_BB-low_NB_BB,...
    high_NB_BB-p_NB_BB,'k','linestyle','none');

set(gca,'XTick',[1 2],'XTickLabel',{'AB','NB'});
ylabel('Predicted Accuracy');
xlabel('Condition');

legend({'EM','BB'},'Location','northwest');
ylim([0.65 0.80])   % adjust if needed

title('GLMM Estimated Accuracy (EM Reference)');
box off;

%Refit RT for NB refernce
RTData.Condition = reordercats(RTData.Condition, ["NB","AB"]);
categories(RTData.Condition)
categories(RTData.Boundary)

lmeRT_NBref = fitlme(RTData, ...
'logRT ~ Boundary*Condition + (1|Participant) + (1|Movie)');

lmeRT_NBref

newData = table;

newData.Condition = categorical(["NB";"NB";"AB";"AB"]);
newData.Boundary  = categorical(["BB";"EM";"BB";"EM"]);

newData.Participant = categorical(ones(4,1));
newData.Movie       = categorical(ones(4,1));

logRT_pred = predict(lmeRT_NBref, newData, 'Conditional',false);
RT_pred = exp(logRT_pred);

RT_NB_BB = RT_pred(1);
RT_NB_EM = RT_pred(2);
RT_AB_BB = RT_pred(3);
RT_AB_EM = RT_pred(4);

figure; hold on;
set(gcf,'Color','w');

x = [1 2]; % AB, NB

% BB line
plot(x,[RT_AB_BB RT_NB_BB],'-o','LineWidth',2);

% EM line
plot(x,[RT_AB_EM RT_NB_EM],'-o','LineWidth',2);

set(gca,'XTick',[1 2],'XTickLabel',{'AB','NB'});
xlabel('Condition');
ylabel('Predicted RT (seconds)');
legend({'BB','EM'},'Location','northwest');

ylim([4.4 5.1])
title('GLMM-Predicted Reaction Time (NB Reference)');
box off;

%Accuracy: EM vs BB within NB
AllData.Condition = reordercats(AllData.Condition, ["NB","AB"]);
AllData.Boundary  = reordercats(AllData.Boundary, ["BB","EM"]);

glme_NBref = fitglme(AllData, ...
'Accuracy ~ Boundary*Condition + (1|Participant) + (1|Movie)', ...
'Distribution','Binomial','Link','logit');

glme_NBref

%EM vs BB within AB
AllData.Condition = reordercats(AllData.Condition, ["AB","NB"]);
AllData.Boundary  = reordercats(AllData.Boundary, ["BB","EM"]);

glme_ABref = fitglme(AllData, ...
'Accuracy ~ Boundary*Condition + (1|Participant) + (1|Movie)', ...
'Distribution','Binomial','Link','logit');

glme_ABref

%PLot
newData = table;

newData.Condition = categorical(["NB";"NB";"AB";"AB"]);
newData.Boundary  = categorical(["BB";"EM";"BB";"EM"]);

newData.Participant = categorical(ones(4,1));
newData.Movie       = categorical(ones(4,1));

[logit_pred, CI] = predict(glme_NBref, newData,'Conditional',false);

prob_pred = exp(logit_pred)./(1+exp(logit_pred));
prob_low  = exp(CI(:,1))./(1+exp(CI(:,1)));
prob_high = exp(CI(:,2))./(1+exp(CI(:,2)));

% Extract
NB_BB = prob_pred(1);
NB_EM = prob_pred(2);
AB_BB = prob_pred(3);
AB_EM = prob_pred(4);

NB_BB_low = prob_low(1); NB_BB_high = prob_high(1);
NB_EM_low = prob_low(2); NB_EM_high = prob_high(2);
AB_BB_low = prob_low(3); AB_BB_high = prob_high(3);
AB_EM_low = prob_low(4); AB_EM_high = prob_high(4);

figure;
set(gcf,'Color','w');

x = [1 2]; % BB, EM

% colourblind-safe palette
col_AB = [0 114 178]/255;    % dark blue
col_NB = [213 94 0]/255;     % dark vermillion
grey   = [0.85 0.85 0.85];

%% ================= NB PANEL =================
subplot(1,2,1); hold on;

valid_NB = ~isnan(NB_BB) & ~isnan(NB_EM);
NB_BB_clean = NB_BB(valid_NB);
NB_EM_clean = NB_EM(valid_NB);

% --- Raincloud ---
[fBB,xiBB] = ksdensity(NB_BB_clean);
[fEM,xiEM] = ksdensity(NB_EM_clean);

patch(1 - fBB*0.15, xiBB, col_NB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_NB,'FaceAlpha',0.25,'EdgeColor','none');

% --- Boxplot ---
boxplot([NB_BB_clean NB_EM_clean],...
    'Positions',[1 2],...
    'Widths',0.25,...
    'Colors',col_NB,...
    'Symbol','');

% --- Paired lines ---
for i = 1:length(NB_BB_clean)
    plot(x,[NB_BB_clean(i) NB_EM_clean(i)],'-','Color',grey);
end

% --- Jittered points ---
scatter(1+(rand(size(NB_BB_clean))-0.5)*0.08, NB_BB_clean,20,...
    col_NB,'filled','MarkerFaceAlpha',0.6);

scatter(2+(rand(size(NB_EM_clean))-0.5)*0.08, NB_EM_clean,20,...
    col_NB,'filled','MarkerFaceAlpha',0.6);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
ylabel('Recognition Accuracy');
title('Natural Condition (NB)');
ylim([0.5 1]);
box off;



%% ================= AB PANEL =================
subplot(1,2,2); hold on;

valid_AB = ~isnan(AB_BB) & ~isnan(AB_EM);
AB_BB_clean = AB_BB(valid_AB);
AB_EM_clean = AB_EM(valid_AB);

% --- Raincloud ---
[fBB,xiBB] = ksdensity(AB_BB_clean);
[fEM,xiEM] = ksdensity(AB_EM_clean);

patch(1 - fBB*0.15, xiBB, col_AB,'FaceAlpha',0.25,'EdgeColor','none');
patch(2 + fEM*0.15, xiEM, col_AB,'FaceAlpha',0.25,'EdgeColor','none');

% --- Boxplot ---
boxplot([AB_BB_clean AB_EM_clean],...
    'Positions',[1 2],...
    'Widths',0.25,...
    'Colors',col_AB,...
    'Symbol','');

% --- Paired lines ---
for i = 1:length(AB_BB_clean)
    plot(x,[AB_BB_clean(i) AB_EM_clean(i)],'-','Color',grey);
end

% --- Jittered points ---
scatter(1+(rand(size(AB_BB_clean))-0.5)*0.08, AB_BB_clean,20,...
    col_AB,'filled','MarkerFaceAlpha',0.6);

scatter(2+(rand(size(AB_EM_clean))-0.5)*0.08, AB_EM_clean,20,...
    col_AB,'filled','MarkerFaceAlpha',0.6);

set(gca,'XTick',[1 2],'XTickLabel',{'BB','EM'});
title('Abrupt Condition (AB)');
ylim([0.5 1]);
box off;