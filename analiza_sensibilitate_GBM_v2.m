function analiza_sensibilitate_GBM_v2()

fprintf('\n========================================\n');
fprintf('  Analiza de Sensibilitate v2 — Digital Twin GBM\n');
fprintf('========================================\n\n');

%% Parametri de baza 
%  K = 70000 
p_ref = struct(...
    'rP',        0.025,    ... % rata proliferare [/zi] — Swanson 2003
    'K',         70000,    ... % capacitate biologica [mm^3] 
    'aPH',       0.0371,   ... % tranzitie hipoxica [/zi] — LUMIERE
    'efic',      0.60,     ... % eficienta tratament [0-1]
    'V0',        10000,    ... % volum initial [mm^3]
    'T',         400,      ... % durata simulare [zile]
    'Z',         30,       ... % zi start TMZ [zile]
    'dozaj',     150,      ... % dozaj TMZ [mg/m^2]
    'greutate',  70,       ... % greutate pacient standard [kg]
    'rCS',       0.00105,  ... %  auto-reinnoire CSC [/zi]
    'aCS_to_PS', 0.00048   ... %  diferentiere CSC→PS [/zi]
);

variatie = 0.20;  % ±20%

%%  Parametri analizati 
param_names  = {'rP',       'K',        'aPH',  'efic',          ...
                'V0',       'dozaj',    'rCS',  'aCS_to_PS'};
param_labels = {'r_P [/zi]',      'K [mm3]',     'alpha_PH [/zi]', ...
                'Eficienta (%)',  'V0 [mm3]',    'Dozaj [mg/m2]', ...
                'r_CS [/zi]',    'aCS-PS [/zi]'};

N_params = numel(param_names);

%% === Initializare rezultate ===
V_final_ref   = NaN;
V_final_plus  = NaN(N_params, 1);
V_final_minus = NaN(N_params, 1);
red_ref       = NaN;
red_plus      = NaN(N_params, 1);
red_minus     = NaN(N_params, 1);

traiectorii.t_ref   = [];
traiectorii.V_ref   = [];
traiectorii.t_plus  = cell(N_params, 1);
traiectorii.V_plus  = cell(N_params, 1);
traiectorii.t_minus = cell(N_params, 1);
traiectorii.V_minus = cell(N_params, 1);

%% === Simulare referinta ===
fprintf('Simulare de referinta... ');
[t_r, V_r, red_r] = ruleaza_simulare_v2(p_ref);
V_final_ref = V_r(end);
red_ref     = red_r;
traiectorii.t_ref = t_r;
traiectorii.V_ref = V_r;
fprintf('V_final=%.2f cm^3, Reducere=%.1f%%\n', V_final_ref/1000, red_ref);

%% === Simulari variatii ±20% ===
fprintf('\nVariatii ±20% per parametru:\n');
fprintf('%-28s  %-14s  %-14s  %-10s  %-10s\n', ...
        'Parametru', 'V_final+ [cm3]', 'V_final- [cm3]', 'Red+%', 'Red-%');
fprintf('%s\n', repmat('-',1,80));

for i = 1:N_params
    pn = param_names{i};

    % Variatie +20%
    p_plus = p_ref;
    p_plus.(pn) = p_ref.(pn) * (1 + variatie);
    [t_p, V_p, red_p] = ruleaza_simulare_v2(p_plus);
    V_final_plus(i)    = V_p(end);
    red_plus(i)        = red_p;
    traiectorii.t_plus{i} = t_p;
    traiectorii.V_plus{i} = V_p;

    % Variatie -20%
    p_minus = p_ref;
    p_minus.(pn) = p_ref.(pn) * (1 - variatie);
    [t_m, V_m, red_m] = ruleaza_simulare_v2(p_minus);
    V_final_minus(i)   = V_m(end);
    red_minus(i)       = red_m;
    traiectorii.t_minus{i} = t_m;
    traiectorii.V_minus{i} = V_m;

    fprintf('%-28s  %-14.2f  %-14.2f  %-10.1f  %-10.1f\n', ...
            param_labels{i}, ...
            V_final_plus(i)/1000, V_final_minus(i)/1000, ...
            red_plus(i), red_minus(i));
end

%%  Indici de sensibilitate normalizati

S_idx = abs(V_final_plus - V_final_minus) / (2 * variatie * V_final_ref) * 100;

fprintf('\nIndici sensibilitate normalizati (%%output / %%input):\n');
for i = 1:N_params
    fprintf('  S(%s) = %.2f%%\n', param_labels{i}, S_idx(i));
end

%%  GRAFICE 
figure('Name','Analiza Sensibilitate v2 — Digital Twin GBM', ...
       'NumberTitle','off','Position',[50 50 1600 650]);

%% Plot 1: Grafic Tornado 
subplot(1,3,1);
[S_sort, idx_sort] = sort(S_idx);
labels_sort = param_labels(idx_sort);

barh(1:N_params, S_sort, 'FaceColor',[0.25 0.5 0.75],'EdgeColor','white');
set(gca,'YTick',1:N_params,'YTickLabel',labels_sort,'FontSize',9);
xlabel('Indice sensibilitate [%]','FontSize',11);
title({'Grafic Tornado v2'; 'Impact parametri pe V_{final}'},'FontSize',11);
grid on;

%% Plot 2: Impact pe volum final (bara dubla ±20%)
subplot(1,3,2);
delta_plus  = (V_final_plus  - V_final_ref) / 1000;
delta_minus = (V_final_minus - V_final_ref) / 1000;

hold on;
for i = 1:N_params
    c_p = [0.8 0.2 0.2]; if delta_plus(i)  < 0, c_p = [0.2 0.6 0.2]; end
    c_m = [0.8 0.4 0.4]; if delta_minus(i) < 0, c_m = [0.4 0.7 0.4]; end
    bar(i + 0.15, delta_plus(i),  0.25, 'FaceColor', c_p, 'EdgeColor','none');
    bar(i - 0.15, delta_minus(i), 0.25, 'FaceColor', c_m, 'EdgeColor','none');
end
yline(0,'k-','LineWidth',1.5);
set(gca,'XTick',1:N_params,'XTickLabel',param_labels,'XTickLabelRotation',35,'FontSize',8);
ylabel('\Delta V_{final} [cm^3]','FontSize',11);
title({'Variatie volum final';'(vs referinta, ±20% parametri)'},'FontSize',11);
legend({'+20% parametru','-20% parametru'},'Location','best','FontSize',9);
grid on; hold off;

%% Plot 3: Traiectorii spaghetti — fara tratament
subplot(1,3,3);
hold on;
culori = lines(N_params);

plot(traiectorii.t_ref, traiectorii.V_ref/1000, 'k-', 'LineWidth',2.5, ...
     'DisplayName','Referinta');

for i = 1:N_params
    plot(traiectorii.t_plus{i},  traiectorii.V_plus{i}/1000,  '--', ...
         'Color', culori(i,:), 'LineWidth', 1.0, ...
         'DisplayName', [param_labels{i} ' +20%']);
    plot(traiectorii.t_minus{i}, traiectorii.V_minus{i}/1000, ':', ...
         'Color', culori(i,:), 'LineWidth', 1.0, ...
         'HandleVisibility','off');
end

xlabel('Timp [zile]','FontSize',11);
ylabel('Volum tumoral [cm^3]','FontSize',11);
title({'Traiectorii posibile'; '(fara tratament)'},'FontSize',11);
legend('Location','northwest','FontSize',7);
grid on; hold off;

sgtitle(sprintf('Analiza de Sensibilitate v2 — Digital Twin GBM (±20%%)  [K=%.0f mm^3, %d parametri]', ...
                p_ref.K, N_params), 'FontSize',12,'FontWeight','bold');

fprintf('\nAnaliza completa. Graficele au fost generate.\n');
end


%% 
%  FUNCTIE SIMULARE v2 

function [t_out, V_no_out, reducere] = ruleaza_simulare_v2(p)
    V0      = p.V0;
    T       = p.T;
    Z       = p.Z;
    efic    = p.efic;
    dozaj   = p.dozaj;
    greutate = p.greutate;
    BSA     = 1.85;   % BSA standard [m^2] pentru analiza de sensibilitate

    %% 
    kel_d    = log(2) / (1.8/24);    % T1/2=1.8h → kel=9.24 /zi
    Vd       = 0.4 * greutate;       % volum distributie [L] (FDA TMZ 2005)
    F        = 1.0;                   % biodisponibilitate 100%
    Emax     = 0.85;
    EC50     = 0.6;                   % [mg/L] (Baker et al. 1999)

    dt_pk    = 0.1;                   % [zile] — orice valoare, solutie exacta
    t_PK     = 0 : dt_pk : T;
    C_pl     = zeros(size(t_PK));
    dose_mg  = dozaj * BSA;
    C_inf    = F * dose_mg / (Vd * kel_d);  % concentratie de echilibru [mg/L]
    exp_k    = exp(-kel_d * dt_pk);

    for i = 2:length(t_PK)
        tnow = t_PK(i);
        in_w = (tnow >= Z) && (mod(tnow - Z, 28) <= 5);
        if in_w
            C_pl(i) = C_pl(i-1) * exp_k + C_inf * (1 - exp_k);
        else
            C_pl(i) = C_pl(i-1) * exp_k;
        end
        C_pl(i) = max(C_pl(i), 0);
    end

    u_t       = Emax * (C_pl ./ (EC50 + C_pl)) * efic;
    u_t_redus = u_t * 0.25;

    %%  Conditii initiale 
    y0 = conditii_initiale_v2(V0);

    %% Parametri ODE 
    pm = struct(...
        'rP', p.rP, 'K', p.K, 'aPH', p.aPH, ...
        'aHN', 0.004, 'dN', 0.001, ...
        'mu_SR_base', 3e-4, 'mu_RS', 5e-6, 'mu_SR_factor', 3, ...
        'mgmt_SR', 0.70, ...
        'muP_S', 0.012, 'muP_R', 0.0006, 'muP_CS', 5e-5, ...
        'rCS', p.rCS, 'aCS_to_PS', p.aCS_to_PS, ...  % [FIX 3.7] din parametri
        't_PK', t_PK, 'u_t', u_t, 'u_t_redus', u_t_redus, ...
        'cu_tratament', true);

    pm_no              = pm;
    pm_no.cu_tratament = false;

    %%  ode15s 
    opts = odeset('RelTol',1e-5,'AbsTol',1e-7*ones(1,5),...
                  'MaxStep',0.5,'NonNegative',[1 2 3 4 5]);
    tspan = [0, T];

    try
        [t_no, Y_no] = ode15s(@(t,y) gbm_ode_v2(t,y,pm_no), tspan, y0, opts);
        [t_tr, Y_tr] = ode15s(@(t,y) gbm_ode_v2(t,y,pm),    tspan, y0, opts);

        V_no = sum(Y_no, 2);
        V_tr = sum(Y_tr, 2);

        t_com    = linspace(0, T, 300);
        V_no_i   = interp1(t_no, V_no, t_com, 'linear', 'extrap');
        V_tr_i   = interp1(t_tr, V_tr, t_com, 'linear', 'extrap');

        t_out    = t_com(:)';
        V_no_out = V_no_i(:)';
        reducere = 100 * (V_no_i(end) - V_tr_i(end)) / max(V_no_i(end), eps);
    catch ME
        warning('ruleaza_simulare_v2: %s', ME.message);
        t_out    = linspace(0, T, 300);
        V_no_out = V0 * ones(1, 300);
        reducere = 0;
    end
end


%% 

function y0 = conditii_initiale_v2(V0)
    if V0 < 5000
        frac_P = 0.45; frac_H = 0.25; frac_N = 0.15;
    elseif V0 < 30000
        frac_P = 0.30; frac_H = 0.20; frac_N = 0.40;
    else
        frac_P = 0.20; frac_H = 0.18; frac_N = 0.50;
    end
    frac_live = frac_P + frac_H;
    CS_frac   = 0.02 * frac_live;
    frac_P    = frac_P - CS_frac;

    y0 = [frac_P*0.90*V0; frac_P*0.10*V0; frac_H*V0; frac_N*V0; CS_frac*V0];
end


%% 

function dydt = gbm_ode_v2(t, y, p)
    PS = y(1); PR = y(2); Hc = y(3); N = y(4); CS = y(5);
    V_tot = max(PS + PR + Hc + N + CS, eps);
    lf    = max(0, 1 - V_tot / p.K);

    if p.cu_tratament
        u_now     = interp1(p.t_PK, p.u_t,       t, 'linear', 0);
        u_red_now = interp1(p.t_PK, p.u_t_redus, t, 'linear', 0);
    else
        u_now = 0; u_red_now = 0;
    end

    sf    = (Hc + N) / V_tot;
    mu_SR = (p.mu_SR_base + p.mu_SR_factor * p.mu_SR_base * sf) * p.mgmt_SR;

    dPS = p.rP*PS*lf - p.aPH*PS - mu_SR*PS + p.mu_RS*PR - p.muP_S*u_now*PS + p.aCS_to_PS*CS;
    dPR = p.rP*PR*lf - p.aPH*PR + mu_SR*PS  - p.mu_RS*PR - p.muP_R*u_now*PR;
    dH  = p.aPH*(PS+PR) - p.aHN*Hc - 0.004*u_red_now*Hc;
    dN  = p.aHN*Hc - p.dN*N;
    dCS = p.rCS*CS*lf  - p.aCS_to_PS*CS - p.muP_CS*u_now*CS;

    dydt = [dPS; dPR; dH; dN; dCS];
end



