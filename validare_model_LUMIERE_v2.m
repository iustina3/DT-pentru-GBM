function validare_model_LUMIERE_v2(csv_path)

if nargin < 1
    [f, d] = uigetfile('*.csv','Selecteaza lumiere_volume_solid.csv');
    if f == 0, return; end
    csv_path = fullfile(d, f);
end

fprintf('\n============================================================\n');
fprintf('  Validare Model GBM v2 — rP personalizat + Pre-Tratament\n');
fprintf('============================================================\n');

T_tbl    = readtable(csv_path, 'VariableNamingRule','preserve');
pacienti = unique(T_tbl.('Patient'));
fprintf('Pacienti incarcati: %d\n\n', numel(pacienti));

%% Parametri model
rP_baza     = 0.025;    % Swanson et al. 2003
K_baza      = 70000;    % mm^3 — 70 cm^3 
aPH_LUMIERE = 0.0371;   % calibrat pe LUMIERE (Suter 2022)

%% Parametri calibrare
rP_MIN = 0.005;   % limita biologica minima [/zi] — Swanson 2003
rP_MAX = 0.080;   % limita biologica maxima [/zi] — Rockne 2010

%%  Prag pre-tratament: 60 zile 
% Rationale: RT incepe la ~4 sapt; primul ciclu TMZ adjuvant se termina la ~7 sapt.
% 60 zile = ~8.5 sapt captureaza faza pre-TMZ fara a include efectul TMZ.
T_PRETRAT = 60;  % [zile]

opts_ode  = odeset('RelTol',1e-5,'AbsTol',1e-7*ones(1,5),...
                   'MaxStep',0.5,'NonNegative',[1 2 3 4 5]);
opts_fmin = optimset('Display','off','TolX',1e-8,'TolFun',1e-8);

%% Vectori rezultate
V_mas_pop  = []; V_sim_pop  = [];
V_mas_pers = []; V_sim_pers = [];
rP_calibrat_vec = [];
n_pretrat_vec   = [];
pacienti_valizi = {};
cal_reusit_vec  = [];

fprintf('%-15s  %-5s  %-5s  %-8s  %-10s  %-10s  %s\n',...
        'Pacient','NrTP','NrPre','rP_cal','NRMSE_pop','NRMSE_per','Status');
fprintf('%s\n', repmat('-',1,73));

for i = 1:numel(pacienti)
    %% Pregatire date pacient
    pac_data = T_tbl(strcmp(T_tbl.('Patient'), pacienti{i}), :);
    pac_data = sortrows(pac_data, 'week_num');
    [t_u, ~, ic] = unique(pac_data.('week_num'));
    V_u = accumarray(ic, pac_data.('V_solid_mm3'), [], @mean);

    if numel(t_u) < 2 || V_u(1) <= 0 || V_u(1) >= K_baza, continue; end

    t_zile = t_u * 7;
    V0     = V_u(1);

    %% Identificare timepoints pre-tratament
    idx_pretrat = t_zile <= T_PRETRAT;
    if sum(idx_pretrat) < 2, continue; end

    t_pretrat = t_zile(idx_pretrat);
    V_pretrat = V_u(idx_pretrat);

    %% FAZA 1 — Calibrare rP pe primele max 4 timepoints pre-tratament
    n_cal = min(4, sum(idx_pretrat));
    t_cal = t_pretrat(1:n_cal);
    V_cal = V_pretrat(1:n_cal);

    if V_cal(end) <= V_cal(1) * 0.90
        rP_local   = rP_baza;
        cal_reusit = false;
        status_txt = 'scadere→pop';
    else
        fun_rP = @(log_rP) eroare_rP_v2(exp(log_rP), t_cal, V_cal, ...
                                         V0, aPH_LUMIERE, K_baza, opts_ode);
        try
            log_opt  = fminbnd(fun_rP, log(rP_MIN), log(rP_MAX), opts_fmin);
            rP_local = exp(log_opt);
            cal_reusit = true;
            if rP_local < rP_MIN*1.01 || rP_local > rP_MAX*0.99
                rP_local   = rP_baza;
                cal_reusit = false;
                status_txt = 'limita→pop';
            else
                status_txt = 'OK';
            end
        catch
            rP_local   = rP_baza;
            cal_reusit = false;
            status_txt = 'eroare→pop';
        end
    end

    %% aPH consistent cu rP
    aPH_pers = calc_aPH(rP_local, V0, K_baza, aPH_LUMIERE);
    aPH_pop  = calc_aPH(rP_baza,  V0, K_baza, aPH_LUMIERE);

    %%  Conditii initiale realiste dependente de V0
    y0_pop  = conditii_initiale(V0);
    y0_pers = conditii_initiale(V0);  % identice (V0 acelasi)

    %% FAZA 2 — Simulare pe intervalul pre-tratament
    tspan_val = [0, max(t_pretrat)];

    % Model populational
    p_pop = build_params_v2(rP_baza, K_baza, aPH_pop);
    try
        [ts1, Ys1] = ode15s(@(t,y) ode_GBM_v2(t,y,p_pop), tspan_val, y0_pop, opts_ode);

        %%  Verificare: integrarea acopera intervalul necesar
        if ts1(end) < t_pretrat(end) - 1
            warning('Pac %s: integrare incompleta (%.1f < %.1f zile). Sarit.', ...
                    pacienti{i}, ts1(end), t_pretrat(end));
            continue;
        end
        
        V_pop_i = max(interp1(ts1, sum(Ys1,2), t_pretrat, 'linear'), 0);
    catch ME
        warning('Pac %s pop: %s', pacienti{i}, ME.message);
        continue;
    end

    % Model personalizat
    p_pers = build_params_v2(rP_local, K_baza, aPH_pers);
    try
        [ts2, Ys2] = ode15s(@(t,y) ode_GBM_v2(t,y,p_pers), tspan_val, y0_pers, opts_ode);

        %%  Verificare interval integrare
        if ts2(end) < t_pretrat(end) - 1
            warning('Pac %s: integrare incompleta (pers). Sarit.', pacienti{i});
            continue;
        end
        V_pers_i = max(interp1(ts2, sum(Ys2,2), t_pretrat, 'linear'), 0);
    catch ME
        warning('Pac %s pers: %s', pacienti{i}, ME.message);
        continue;
    end

    %% FAZA 3 — Metrici: NRMSE = RMSE / mean(V_mas) uniform
    NRMSE_pop  = calc_NRMSE_v2(V_pretrat(:), V_pop_i(:))  * 100;
    NRMSE_pers = calc_NRMSE_v2(V_pretrat(:), V_pers_i(:)) * 100;

    V_mas_pop  = [V_mas_pop;  V_pretrat(:)]; 
    V_sim_pop  = [V_sim_pop;  V_pop_i(:)];  
    V_mas_pers = [V_mas_pers; V_pretrat(:)]; 
    V_sim_pers = [V_sim_pers; V_pers_i(:)]; 
    rP_calibrat_vec(end+1) = rP_local;      
    n_pretrat_vec(end+1)   = sum(idx_pretrat); 
    cal_reusit_vec(end+1)  = cal_reusit;    
    pacienti_valizi{end+1} = pacienti{i};   

    fprintf('%-15s  %-5d  %-5d  %-8.5f  %-10.1f  %-10.1f  %s\n', ...
            pacienti{i}, numel(t_u), sum(idx_pretrat), ...
            rP_local, NRMSE_pop, NRMSE_pers, status_txt);
end

fprintf('\nPacienti inclusi in validare: %d\n', numel(pacienti_valizi));
fprintf('Din care cu rP calibrat reusit: %d (%.0f%%)\n', ...
        sum(cal_reusit_vec), 100*mean(cal_reusit_vec));
if ~isempty(n_pretrat_vec)
    fprintf('Timepoints pre-tratament: mediana=%d per pacient\n', ...
            round(median(n_pretrat_vec)));
end

if isempty(V_mas_pop)
    error('Niciun pacient valid. Verifica CSV-ul sau pragul T_PRETRAT=%d zile.', T_PRETRAT);
end

%% Raport metrici — definitie unica NRMSE = RMSE/mean
print_metrici_v2('MODEL POPULATIONAL  (rP=0.025 fix, pre-tratament)', ...
                 V_mas_pop,  V_sim_pop);
print_metrici_v2('MODEL PERSONALIZAT  (rP calibrat,  pre-tratament)', ...
                 V_mas_pers, V_sim_pers);

rP_ok = rP_calibrat_vec(logical(cal_reusit_vec));
fprintf('\nDistributie rP calibrat (pacienti cu calibrare reusita):\n');
if ~isempty(rP_ok)
    fprintf('  N       = %d\n',       numel(rP_ok));
    fprintf('  Mediana = %.5f /zi\n', median(rP_ok));
    fprintf('  Medie   = %.5f /zi\n', mean(rP_ok));
    fprintf('  Std     = %.5f /zi\n', std(rP_ok));
    fprintf('  Min/Max = %.5f / %.5f /zi\n', min(rP_ok), max(rP_ok));
else
    fprintf('  Niciun pacient cu calibrare reusita.\n');
    fprintf('  Recomandare: mareste T_PRETRAT sau verifica datele.\n');
end

%% Grafice
figure('Name','Validare GBM v2 — Pre-tratament: Populational vs Personalizat',...
       'NumberTitle','off','Position',[30 30 1600 620]);

R2_pop  = calc_R2_v2(V_mas_pop,  V_sim_pop);
R2_pers = calc_R2_v2(V_mas_pers, V_sim_pers);
NR_pop  = calc_NRMSE_v2(V_mas_pop,  V_sim_pop) * 100;
NR_pers = calc_NRMSE_v2(V_mas_pers, V_sim_pers) * 100;

subplot(2,3,1);
plot_scatter_v2(V_mas_pop, V_sim_pop, ...
    sprintf('Populational — Faza pre-TMZ\nR²=%.3f  NRMSE=%.1f%%', R2_pop, NR_pop), ...
    [0.2 0.4 0.8]);

subplot(2,3,2);
plot_scatter_v2(V_mas_pers, V_sim_pers, ...
    sprintf('Personalizat (rP calibrat) — Faza pre-TMZ\nR²=%.3f  NRMSE=%.1f%%', R2_pers, NR_pers), ...
    [0.8 0.3 0.2]);

subplot(2,3,3);
if ~isempty(rP_ok)
    histogram(rP_ok, 12, 'FaceColor',[0.3 0.6 0.3],'EdgeColor','white');
    xline(median(rP_ok), '--r', sprintf('Med=%.4f', median(rP_ok)), 'LineWidth',2);
    xline(rP_baza, ':b', sprintf('rP_{pop}=%.3f', rP_baza), 'LineWidth',1.5);
else
    text(0.5,0.5,'Fara calibrare reusita','HorizontalAlignment','center',...
         'Units','normalized','FontSize',12);
end
xlabel('rP calibrat [/zi]'); ylabel('Nr. pacienti');
title({'Distributie rP personalizat'; ...
       sprintf('N=%d  Prag pretrat=%d zile', numel(rP_ok), T_PRETRAT)});
grid on;

subplot(2,3,4);
plot_bland_altman_v2(V_mas_pop, V_sim_pop, ...
    sprintf('Bland-Altman — Populational\n(t \x2264 %d zile)', T_PRETRAT), [0.2 0.4 0.8]);

subplot(2,3,5);
plot_bland_altman_v2(V_mas_pers, V_sim_pers, ...
    sprintf('Bland-Altman — Personalizat\n(t \x2264 %d zile)', T_PRETRAT), [0.8 0.3 0.2]);

subplot(2,3,6);
plot_traiectorii_v2(T_tbl, pacienti_valizi, rP_calibrat_vec, ...
                    aPH_LUMIERE, K_baza, T_PRETRAT, opts_ode);

sgtitle(sprintf(['Validare Digital Twin GBM v2 — Pre-Tratament (t\x2264%d zile)\n' ...
                 'Populational: R\xb2=%.3f  NRMSE=%.1f%%   ' ...
                 'Personalizat: R\xb2=%.3f  NRMSE=%.1f%%'], ...
                T_PRETRAT, R2_pop, NR_pop, R2_pers, NR_pers), ...
        'FontSize',11,'FontWeight','bold');

end % functia principala


%% 
%  Martinez-Gonzalez et al. 2012; Brat et al. 2004

function y0 = conditii_initiale(V0)
    if V0 < 5000          % tumori mici (< 5 cm^3)
        frac_P = 0.45; frac_H = 0.25; frac_N = 0.15;
    elseif V0 < 30000     % tipic la diagnostic (5-30 cm^3)
        frac_P = 0.30; frac_H = 0.20; frac_N = 0.40;
    else                  % tumori mari (> 30 cm^3)
        frac_P = 0.20; frac_H = 0.18; frac_N = 0.50;
    end
    % CSC = 2% din celulele vii 
    frac_live = frac_P + frac_H;
    CS_frac   = 0.02 * frac_live;
    frac_P    = frac_P - CS_frac;  % ajustare pentru suma = 1

    y0 = [frac_P*0.90*V0;   % PS
          frac_P*0.10*V0;   % PR
          frac_H*V0;         % H
          frac_N*V0;         % N
          CS_frac*V0];       % CS
end


%% 
%  aPH consistent cu rP si V0

function aPH = calc_aPH(rP, V0, K, aPH_LUM)
    rata_neta = rP * (1 - V0/K);
    if rata_neta <= aPH_LUM
        aPH = max(0.40 * rata_neta, 0.50 * aPH_LUM);  % [FIX 2.2]
    else
        aPH = aPH_LUM;
    end
end


%% 
%  FUNCTIE EROARE pentru fminbnd

function e = eroare_rP_v2(rP, t_zile, V_obs, V0, aPH_LUM, K, opts_ode)
    aPH = calc_aPH(rP, V0, K, aPH_LUM);
    p   = build_params_v2(rP, K, aPH);
    y0  = conditii_initiale(V0);  
    try
        [ts, Y] = ode15s(@(t,y) ode_GBM_v2(t,y,p), [0,max(t_zile)], y0, opts_ode);
        
        if ts(end) < max(t_zile) - 1
            e = 1e12; return;
        end
        Vi = max(interp1(ts, sum(Y,2), t_zile, 'linear'), 0);
        e  = sum(((Vi(:) - V_obs(:)) ./ max(V_obs(:), 1)).^2);
    catch
        e = 1e12;
    end
end


%% 

function p = build_params_v2(rP, K, aPH)
    p = struct('rP', rP, 'K', K, 'aPH', aPH, ...
               'aHN', 0.004, 'dN', 0.001, ...
               'mu_SR_base', 3e-4, 'mu_RS', 5e-6, ...
               'mu_SR_factor', 3, 'mgmt_SR', 0.70, ...
               'muP_S', 0, 'muP_R', 0, 'muP_CS', 0, ...
               'rCS', 0.00105, 'aCS_to_PS', 0.00048, ...  % [FIX 3.1] identici cu GUI
               't_PK', [0 1], 'u_t', [0 0], 'u_t_redus', [0 0], ...
               'cu_tratament', false);
end


%% 

function dydt = ode_GBM_v2(~, y, p)
    PS = y(1); PR = y(2); Hc = y(3); N = y(4); CS = y(5);
    V  = max(PS + PR + Hc + N + CS, eps);
    lf = max(0, 1 - V / p.K);
    sf = (Hc + N) / V;

    mu_SR = (p.mu_SR_base + p.mu_SR_factor * p.mu_SR_base * sf) * p.mgmt_SR;

    dPS = p.rP * PS * lf - p.aPH * PS - mu_SR * PS + p.mu_RS * PR + p.aCS_to_PS * CS;
    dPR = p.rP * PR * lf - p.aPH * PR + mu_SR * PS  - p.mu_RS * PR;
    dH  = p.aPH * (PS + PR) - p.aHN * Hc;
    dN  = p.aHN * Hc - p.dN * N;
    dCS = p.rCS * CS * lf  - p.aCS_to_PS * CS;

    dydt = [dPS; dPR; dH; dN; dCS];
end


%% 

function NR = calc_NRMSE_v2(Vm, Vs)
    % [FIX 3.4] NRMSE standard = RMSE / mean(V_masurate)
    RMSE = sqrt(mean((Vs(:) - Vm(:)).^2));
    NR   = RMSE / max(mean(Vm), eps);
end

function R2 = calc_R2_v2(Vm, Vs)
    ss_res = sum((Vs(:) - Vm(:)).^2);
    ss_tot = sum((Vm(:) - mean(Vm(:))).^2);
    R2 = max(0, 1 - ss_res / max(ss_tot, eps));
end

function print_metrici_v2(titlu, V_mas, V_sim)
    e     = V_sim(:) - V_mas(:);
    RMSE  = sqrt(mean(e.^2));
    NRMSE = RMSE / max(mean(V_mas), eps) * 100;  % [FIX 3.4]
    bias  = mean(e);
    R2    = calc_R2_v2(V_mas, V_sim);
    fprintf('\n=== %s ===\n', titlu);
    fprintf('  N observatii = %d\n', numel(V_mas));
    fprintf('  RMSE         = %.2f mm^3  (%.3f cm^3)\n', RMSE, RMSE/1000);
    fprintf('  NRMSE        = %.1f%%  [definitie: RMSE/mean(V_mas)]\n', NRMSE);
    fprintf('  Bias         = %.2f mm^3\n', bias);
    fprintf('  R^2          = %.4f\n', R2);
end


%%
%  FUNCTII GRAFICE

function plot_scatter_v2(Vm, Vs, titlu, col)
    m = Vm/1000; s = Vs/1000;
    scatter(m, s, 22, col, 'filled', 'MarkerFaceAlpha', 0.55);
    hold on;
    lim = max([m; s]) * 1.08;
    if lim <= 0, lim = 10; end
    plot([0 lim],[0 lim], 'r-', 'LineWidth', 2, 'DisplayName', 'Identitate (y=x)');
    if numel(m) > 2
        c  = polyfit(m, s, 1);
        xf = linspace(0, lim, 100);
        plot(xf, polyval(c,xf), 'k--', 'LineWidth', 1.2, ...
             'DisplayName', sprintf('Regresie (slope=%.2f)', c(1)));
    end
    xlim([0 lim]); ylim([0 lim]);
    xlabel('V_{masurat} RMN [cm^3]', 'FontSize', 10);
    ylabel('V_{simulat} model [cm^3]', 'FontSize', 10);
    title(titlu, 'FontSize', 10);
    legend('Location', 'northwest', 'FontSize', 8);
    grid on; axis square; hold off;
end

function plot_bland_altman_v2(Vm, Vs, titlu, col)
    m = Vm/1000; s = Vs/1000;
    med = (m + s) / 2; dif = s - m;
    b = mean(dif); sd = std(dif);
    scatter(med, dif, 22, col, 'filled', 'MarkerFaceAlpha', 0.55);
    hold on;
    yline(b,            'r-',  sprintf('Bias: %.2f cm^3', b),         'LineWidth', 2);
    yline(b + 1.96*sd,  'b--', sprintf('+1.96SD: %.2f', b+1.96*sd),   'LineWidth', 1.5);
    yline(b - 1.96*sd,  'b--', sprintf('-1.96SD: %.2f', b-1.96*sd),   'LineWidth', 1.5);
    yline(0, 'k:', 'LineWidth', 1);
    xlabel('Medie (sim+mas)/2 [cm^3]', 'FontSize', 10);
    ylabel('Diferenta (sim-mas) [cm^3]', 'FontSize', 10);
    title(titlu, 'FontSize', 10); grid on; hold off;
end

function plot_traiectorii_v2(T_tbl, pac_list, rP_vec, aPH_LUM, K, T_PRE, opts)
    hold on;
    cul    = lines(min(5, numel(pac_list)));
    n_plot = min(5, numel(pac_list));
    for k = 1:n_plot
        pd = T_tbl(strcmp(T_tbl.('Patient'), pac_list{k}), :);
        pd = sortrows(pd, 'week_num');
        [tu,~,ic] = unique(pd.('week_num'));
        Vu = accumarray(ic, pd.('V_solid_mm3'), [], @mean);
        tz = tu * 7; V0 = Vu(1);
        idx = tz <= T_PRE;
        if sum(idx) < 2, continue; end
        tz_pre = tz(idx); Vu_pre = Vu(idx);

        rPk = rP_vec(k);
        aPH = calc_aPH(rPk, V0, K, aPH_LUM);
        p   = build_params_v2(rPk, K, aPH);
        y0  = conditii_initiale(V0);
        try
            [ts, Ys] = ode15s(@(t,y) ode_GBM_v2(t,y,p), [0,max(tz_pre)], y0, opts);
            
            if ts(end) < max(tz_pre) - 1, continue; end
            tf = linspace(0, max(tz_pre), 200);
            Vf = interp1(ts, sum(Ys,2), tf, 'linear');
            plot(tz_pre, Vu_pre/1000, 'o', 'Color', cul(k,:), 'MarkerSize', 8, 'LineWidth', 1.5);
            plot(tf, Vf/1000, '-', 'Color', cul(k,:), 'LineWidth', 1.8, ...
                 'DisplayName', pac_list{k});
        catch; continue; end
    end
    xlabel('Timp [zile]', 'FontSize', 10);
    ylabel('Volum solid [cm^3]', 'FontSize', 10);
    title(sprintf('Traiectorii pre-tratament (t\x2264%d zile)', T_PRE), 'FontSize', 10);
    legend('Location', 'best', 'FontSize', 8); grid on; hold off;
end