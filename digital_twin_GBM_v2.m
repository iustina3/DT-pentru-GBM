function digital_twin_GBM_v2()

% Referinte:
%   - Swanson et al., 2003 (model proliferare-infiltrare GBM)
%   - Stupp et al., 2005; Hegi et al., 2005 (protocol TMZ + OS)
%   - Stabellini et al., Front. Oncol. 2021 (HR sex = 1.11)
%   - CBTRUS Statistical Report 2024 (incidenta pe varsta)
%   - FDA TMZ Label, 2005 (PK: Vd=0.4 L/kg, T1/2=1.8h, F=100%)
%   - Baker et al., 1999 (PD: Emax=0.85, EC50=0.6)
%   - Suter et al., Scientific Data 2022 (LUMIERE, aPH=0.0371/zi)
%   - Lathia et al., Cell Stem Cell 2015 (CSC 1-5% celule vii)
%   - Martinez-Gonzalez et al., Bull.Math.Biol. 2012 (fractii histopatologice)
%   - Roman et al., 2019 (K clinic ≈ 70 cm^3)

%% --- FEREASTRA PRINCIPALA ---
fig = uifigure('Name','Simularea computațională a GBM:un DT personalizat',...
               'Position',[100 100 1200 950],...
               'WindowState','maximized');

mainGrid = uigridlayout(fig,[1 2]);
mainGrid.RowHeight   = {'1x'};
mainGrid.ColumnWidth = {450, '1x'};

%% --- COLOANA STANGA: INPUT ---
panelInput = uipanel(mainGrid,'Title','');
panelInput.Layout.Row    = 1;
panelInput.Layout.Column = 1;

g = uigridlayout(panelInput,[4 1]);
g.RowHeight   = {40, 270, 200, 80};
g.ColumnWidth = {'1x'};

uilabel(g,'Text','Simularea computațională a GBM:un DT personalizat',...
        'FontWeight','bold','FontSize',17,...
        'HorizontalAlignment','center');

%% --- Panou date pacient ---
panelDate = uipanel(g,'Title','DATE PACIENT');
panelDate.FontWeight = 'bold';

gd = uigridlayout(panelDate,[5 4]);
gd.RowHeight   = {40 40 40 40 40};
gd.ColumnWidth = {'1x' '1x' '1x' '1x'};

uilabel(gd,'Text','Varsta:');
ageField = uieditfield(gd,'numeric','Value',60,'Limits',[0 140]);
uilabel(gd,'Text','Sex:');
sexField = uidropdown(gd,'Items',{'M','F'},'Value','M');

uilabel(gd,'Text','Greutate (kg):');
weightField = uieditfield(gd,'numeric','Value',70,'Limits',[30 200]);
uilabel(gd,'Text','Inaltime (m):');
heightField = uieditfield(gd,'numeric','Value',1.75,'Limits',[1.0 2.5]);

uilabel(gd,'Text','Stres ridicat:');
stressField = uidropdown(gd,'Items',{'da','nu'},'Value','da');
uilabel(gd,'Text','Somn bun:');
sleepField = uidropdown(gd,'Items',{'da','nu'},'Value','nu');

uilabel(gd,'Text','Alimentatie:');
dietField = uidropdown(gd,'Items',{'buna','slaba'},'Value','slaba');
uilabel(gd,'Text','Localizare:');
locField  = uidropdown(gd,'Items',...
    {'frontal','temporal','parietal','occipital','cerebel','talamus','trunchi'},...
    'Value','frontal');

uilabel(gd,'Text','MGMT:');
MGMTField = uidropdown(gd,'Items',{'metilat','nemetilat'},'Value','metilat');
uilabel(gd,'Text',''); uilabel(gd,'Text','');

%% --- Panou parametri simulare ---
panelSim = uipanel(g,'Title','PARAMETRI SIMULARE');
panelSim.FontWeight = 'bold';

gs = uigridlayout(panelSim,[3 4]);
gs.RowHeight   = {45, 45, 45};
gs.ColumnWidth = {'1x' '1x' '1x' '1x'};

uilabel(gs,'Text','Volum initial (mm^3):');
V0Field = uieditfield(gs,'numeric','Value',10000,'Limits',[1 Inf]);
V0Field.ValueDisplayFormat = '%.2f';

uilabel(gs,'Text','Durata simulare (zile):');
TField = uieditfield(gs,'numeric','Value',400,'Limits',[10 Inf]);

uilabel(gs,'Text','Zi tratament start:');
ZField = uieditfield(gs,'numeric','Value',30,'Limits',[0 Inf]);

uilabel(gs,'Text','Dozaj (mg/m^2):');
DField = uieditfield(gs,'numeric','Value',150,'Limits',[50 Inf]);

uilabel(gs,'Text','Eficienta tratament (0-1):');
EField = uieditfield(gs,'numeric','Value',0.6,'Limits',[0 1]);

importBtn = uibutton(gs,'Text','Import Date RMN',...
    'FontWeight','bold','BackgroundColor',[0.9 0.9 1]);
importBtn.Layout.Row    = 3;
importBtn.Layout.Column = [1 2];
importBtn.ButtonPushedFcn = @(btn,evt) importMRI_Callback(fig);

%% --- Buton start ---
startBtn = uibutton(g,'Text','Pornire simulare',...
    'FontSize',16,'FontWeight','bold');
startBtn.Layout.Row          = 4;
startBtn.Layout.Column       = 1;
startBtn.HorizontalAlignment = 'center';
startBtn.VerticalAlignment   = 'center';

%% --- COLOANA DREAPTA: GRAFIC + SLIDERE + INFO ---
panelDreapta = uipanel(mainGrid,'Title','');
panelDreapta.Layout.Row    = 1;
panelDreapta.Layout.Column = 2;

gdreapta = uigridlayout(panelDreapta,[4 1]);
gdreapta.RowHeight   = {40, '1x', 160, 80};
gdreapta.ColumnWidth = {'1x'};

uilabel(gdreapta,'Text','Evolutia tumorii',...
        'FontWeight','bold','FontSize',14,...
        'HorizontalAlignment','center');

ax = uiaxes(gdreapta);
ax.Layout.Row    = 2;
ax.Layout.Column = 1;
ax.XLabel.String = 'Timp [zile]';
ax.YLabel.String = 'Volum tumoral [cm^3]';

% Slidere
panelSl = uipanel(gdreapta,'Title','');
gs2 = uigridlayout(panelSl,[2 3]);
gs2.RowHeight   = {40, 40};
gs2.ColumnWidth = {200,'1x',120};

uilabel(gs2,'Text','Eficienta tratament (%)');
sEff   = uislider(gs2,'Limits',[0 100],'Value',60);
lblEff = uilabel(gs2,'Text','60 %','HorizontalAlignment','center');

uilabel(gs2,'Text','Dozaj (mg/m^2)');
sDose   = uislider(gs2,'Limits',[100 250],'Value',150);
lblDose = uilabel(gs2,'Text','150 mg/m^2','HorizontalAlignment','center');

% Panou info rezultate (randul 4) — 3 randuri pentru mai multa informatie
panelInfo = uipanel(gdreapta,'Title','');
panelInfo.Layout.Row    = 4;
panelInfo.Layout.Column = 1;

gInfo = uigridlayout(panelInfo,[3 1]);
gInfo.RowHeight   = {15, 15, 15};
gInfo.ColumnWidth = {'1x'};

infoLabel = uilabel(gInfo,...
    'Text','Apasa "Pornire simulare" pentru a incepe',...
    'HorizontalAlignment','center','FontSize',11);

warnLabel = uilabel(gInfo,...
    'Text','',...
    'HorizontalAlignment','center','FontSize',10,...
    'FontColor',[0.7 0.4 0.0]);

osLabel = uilabel(gInfo,...
    'Text','',...
    'HorizontalAlignment','center','FontSize',12,...
    'FontWeight','bold','FontColor',[0.1 0.4 0.1]);

%% --- HANDLES ---
handles.ax          = ax;
handles.info        = infoLabel;
handles.warnLabel   = warnLabel;
handles.osLabel     = osLabel;
handles.sEff        = sEff;     handles.sDose   = sDose;
handles.lblEff      = lblEff;   handles.lblDose = lblDose;
handles.ageField    = ageField;
handles.sexField    = sexField;
handles.weightField = weightField;
handles.heightField = heightField;
handles.stressField = stressField;
handles.sleepField  = sleepField;
handles.MGMTField   = MGMTField;
handles.dietField   = dietField;
handles.locField    = locField;
handles.V0Field     = V0Field;
handles.TField      = TField;
handles.ZField      = ZField;
handles.EField      = EField;
handles.DField      = DField;
setappdata(fig,'H',handles);

%% --- CALLBACKS ---
sEff.ValueChangingFcn    = @(s,ev) updateLabel(fig, ev);
sEff.ValueChangedFcn     = @(s,ev) updateSliders(fig, ev);
sDose.ValueChangingFcn   = @(s,ev) updateLabel(fig, ev);
sDose.ValueChangedFcn    = @(s,ev) updateSliders(fig, ev);
startBtn.ButtonPushedFcn = @(btn,evt) startSim(fig);

end % digital_twin_GBM_v2



%% 
function updateLabel(fig, ev)
    H = getappdata(fig, 'H');
    if ev.Source == H.sEff
        H.lblEff.Text = sprintf('%d %%', round(ev.Value));
    elseif ev.Source == H.sDose
        H.lblDose.Text = sprintf('%d mg/m^2', round(ev.Value));
    end
    drawnow limitrate;
end



%% 
function updateSliders(fig, ev)
    H = getappdata(fig, 'H');
    if ev.Source == H.sEff
        H.lblEff.Text  = sprintf('%d %%', round(ev.Value));
        H.EField.Value = ev.Value / 100;
    elseif ev.Source == H.sDose
        H.lblDose.Text = sprintf('%d mg/m^2', round(ev.Value));
        H.DField.Value = ev.Value;
    end
    startSim(fig);
end



%% 
function startSim(fig)
    H = getappdata(fig,'H');

    [ok, msg] = validateInputs(fig);
    if ~ok
        if ~isempty(msg)
            uialert(fig, msg, 'Date invalide', 'Icon','error');
        end
        return;
    end

    try
        H.warnLabel.Text = '';

        %% 1. Date pacient
        pac.varsta      = H.ageField.Value;
        pac.sex         = H.sexField.Value;
        pac.greutate    = H.weightField.Value;
        pac.inaltime    = H.heightField.Value;
        pac.stil_stres  = strcmp(H.stressField.Value,'da');
        pac.somn_bun    = strcmp(H.sleepField.Value,'da');
        pac.alimentatie = H.dietField.Value;
        pac.localizare  = H.locField.Value;
        pac.MGMT        = H.MGMTField.Value;

        %% 2. Factori MGMT (Hegi et al. 2005; Stabellini 2021)
        if strcmpi(pac.MGMT,'metilat')
            mgmt_factor_kill = 1.50;
            mgmt_factor_SR   = 0.70;
        else
            mgmt_factor_kill = 0.70;
            mgmt_factor_SR   = 1.60;
        end

        %% 3. Parametri simulare
        V0        = H.V0Field.Value;
        Tfinal    = H.TField.Value;
        Z         = H.ZField.Value;
        dozaj_val = H.sDose.Value;
        efic      = H.sEff.Value / 100;
        BSA       = 0.007184 * pac.greutate^0.425 * (pac.inaltime*100)^0.725;

        %% 4. Parametri model de baza
        %  K_baza = 70 cm^3 (Roman et al. 2019; prag clinic fatal)
        aPH_LUMIERE = 0.0371;   % Suter et al. 2022 (mediana LUMIERE, N=15)
        rP_baza     = 0.025;    % Swanson et al. 2003
        K_baza      = 70000;    % mm^3 — 70 cm^3 

        %% 5. Personalizare parametri — factori conservatori
       
        %  rP_max = 0.031/zi .
        %
        % Varsta: impact conservator pe rP (CBTRUS 2024 raporteaza rate incidenta,
        %         nu rate proliferative directe)
        if     pac.varsta < 50, age_factor = 0.95;
        elseif pac.varsta < 65, age_factor = 1.00;
        elseif pac.varsta < 70, age_factor = 1.05;
        else,                   age_factor = 1.10;
        end

        % Sex: HR=1.11 convertit la impact rP ≈ 3% (Stabellini 2021)
        if strcmpi(pac.sex,'F'), sex_factor = 0.97;
        else,                    sex_factor = 1.00;
        end

        % Stil de viata: impact redus pe rP (KPS influenteaza mai ales OS)
        if ~pac.stil_stres && pac.somn_bun && strcmpi(pac.alimentatie,'buna')
            lifestyle_factor = 0.95;
        else
            lifestyle_factor = 1.05;
        end

        r = rP_baza * age_factor * sex_factor * lifestyle_factor;

        % trunchi/talamus: K redus (spatiu anatomic mic) > efect pe rP
        switch lower(pac.localizare)
            case 'frontal',   loc_factor = 1.00; K_factor = 1.00;
            case 'temporal',  loc_factor = 1.00; K_factor = 1.00;
            case 'parietal',  loc_factor = 1.02; K_factor = 1.00;
            case 'occipital', loc_factor = 0.98; K_factor = 1.00;
            case 'cerebel',   loc_factor = 1.05; K_factor = 0.55;
            case 'talamus',   loc_factor = 1.10; K_factor = 0.40;
            case 'trunchi',   loc_factor = 1.15; K_factor = 0.30;
            otherwise,        loc_factor = 1.00; K_factor = 0.60;
        end

        r = r * loc_factor;
        K = K_baza * K_factor;

        if V0 >= K
            error(['Volumul initial (%.0f mm^3) depaseste capacitatea biologica ' ...
                   'pentru localizarea %s (K=%.0f mm^3). Reduceti V0.'], ...
                   V0, pac.localizare, K);
        end

        %% 6. Garantare conditie biologica de crestere 
        % Conditie: rP*(1-V0/K) > aPH
      
        rata_neta = r * (1 - V0/K);
        warn_txt  = '';

        if rata_neta <= aPH_LUMIERE
            %  max(0.40*rata_neta, 0.50*aPH_LUMIERE) 
            aPH_final = max(0.40 * rata_neta, 0.50 * aPH_LUMIERE);
            warn_txt  = sprintf(['AVERTISMENT: rata_neta (%.4f) < aPH_LUMIERE (%.4f). '...
                                 'aPH ajustat la %.4f. Calibrare rP recomandata.'],...
                                 rata_neta, aPH_LUMIERE, aPH_final);
        else
            aPH_final = aPH_LUMIERE;
        end

        H.warnLabel.Text = warn_txt;
        params_final = struct('rP', r, 'K', K, 'aPH', aPH_final);

        %% 7. Rulare simulare si plot
        [reducere, warnings_sim] = run_and_plot(pac, params_final, V0, Tfinal, Z, ...
                                                efic, dozaj_val, BSA, ...
                                                H.ax, H.info, ...
                                                mgmt_factor_kill, mgmt_factor_SR);

        if ~isempty(warnings_sim) && isempty(warn_txt)
            H.warnLabel.Text = warnings_sim;
        end

        %% 8. Estimare supravietuire globala (OS) — model log-hazard 
        % Baza: Hegi et al. 2005 pentru MGMT metilat (23 luni),
        %       Stupp et al. 2005 pentru nemetilat (12.6 luni)
        if strcmpi(pac.MGMT,'metilat')
            OS_baza = 23.0;   % Hegi et al. 2005
        else
            OS_baza = 12.6;   % Stupp et al. 2005
        end

        
        log_HR = 0;

        % Varsta (CBTRUS 2024 — HR raportat per decada)
        if     pac.varsta >= 70, log_HR = log_HR + log(1.65);
        elseif pac.varsta >= 60, log_HR = log_HR + log(1.20);
        end

        % Sex (Stabellini 2021 — HR=1.11 pentru supravietuire)
        if strcmpi(pac.sex,'M')
            log_HR = log_HR + log(1.11);
        end

        % Localizare (Oncology Reports 2024)
        if ismember(lower(pac.localizare), {'talamus','trunchi'})
            log_HR = log_HR + log(1.60);
        end

        % Stil de viata (impact moderat pe OS, nu pe rP)
        if pac.stil_stres || ~pac.somn_bun || strcmpi(pac.alimentatie,'slaba')
            log_HR = log_HR + log(1.12);
        end

        % Raspuns tumoral la tratament (Ellingson et al. 2017)
        if reducere > 30,     log_HR = log_HR - log(1.15);   % raspuns bun
        elseif reducere < 5,  log_HR = log_HR + log(1.15);   % raspuns slab
        end

        OS_estimat = OS_baza * exp(-log_HR);
        OS_estimat = max(OS_estimat, 4.0);   % minim biologic

        H.osLabel.Text = sprintf(...
            'OS estimat: %.1f luni  (ref Stupp/Hegi 2005: %.1f luni, MGMT %s)',...
            OS_estimat, OS_baza, pac.MGMT);

    catch ME
        uialert(fig, ME.message, 'Eroare simulare');
    end
end



%%
function [reducere, warn_txt] = run_and_plot(pac, params_final, V0_mm3, T_final, ...
                                             zi_trat, efic, dozaj_std, BSA, ...
                                             ax, infoLabel, mgmt_kill, mgmt_SR)
    warn_txt = '';

    %% Profil farmacocinetic TMZ — model bicompartimental oral 
 
    %  toate unitatile in ZILE, Vd explicit (FDA TMZ 2005)
    %
    % Referinte PK: FDA TMZ Label 2005 (Vd=0.4 L/kg, T1/2=1.8h, F≈100%)
    %               Baker et al. 1999 (Emax=0.85, EC50=0.6 mg/L)

    kel_d   = log(2) / (1.8/24);  % T1/2=1.8h → kel=9.24 /zi
    Vd      = 0.4 * pac.greutate; % volum distributie [L] (FDA TMZ 2005)
    F       = 1.0;                 % biodisponibilitate orala ≈100%
    Emax    = 0.85;                % efect maxim (Baker et al. 1999)
    EC50    = 0.6;                 % conc. semi-efectiva [mg/L] (Baker et al. 1999)

    
    dt_pk   = 0.1;                 % [zile] — oricat de mare, solutie exacta
    t_PK    = 0 : dt_pk : T_final;
    C_pl    = zeros(size(t_PK));
    dose_mg = dozaj_std * BSA;     % doza zilnica [mg]
    C_inf   = F * dose_mg / (Vd * kel_d); % concentratie de echilibru [mg/L]
    exp_k   = exp(-kel_d * dt_pk); % factor de eliminare per pas (precompilat)

    for i = 2:length(t_PK)
        tnow = t_PK(i);
        in_window = (tnow >= zi_trat) && (mod(tnow - zi_trat, 28) <= 5);
        if in_window
            % Infuzie continua: C tinde catre C_inf = R/(Vd*kel)
            C_pl(i) = C_pl(i-1) * exp_k + C_inf * (1 - exp_k);
        else
            % Eliminare pura
            C_pl(i) = C_pl(i-1) * exp_k;
        end
        C_pl(i) = max(C_pl(i), 0);
    end

    u_t       = Emax * (C_pl ./ (EC50 + C_pl)) * efic;
    u_t_redus = u_t * 0.25;  % celule hipoxice: permeabilitate TMZ redusa

    %% Parametri compartimente S/R si CSC
    mu_SR_base  = 3e-4;
    mu_RS       = 5e-6;
    muP_S       = 0.008  * mgmt_kill;
    muP_R       = 0.0004 * mgmt_kill;

    if pac.stil_stres,  stress_mult = 1.8; else, stress_mult = 1.0; end
    if pac.varsta > 60, age_mult = 0.7;
    elseif pac.varsta < 35, age_mult = 1.2;
    else, age_mult = 1.0; end
    if pac.somn_bun && strcmpi(pac.alimentatie,'buna')
        diff_mult = 1.5;
    else
        diff_mult = 0.8;
    end

    rCS          = 0.0015  * age_mult * stress_mult;
    aCS_to_PS    = 0.0006  * diff_mult;
    muP_CS       = 5e-5    * (1/diff_mult) * (1/age_mult);
    mu_SR_factor = 3       * stress_mult;

    %% Conditii initiale dependente de V0 
   
    %  CSC = 2% din celulele vii 
    %           Lathia et al. 2015: fractia CD133+ ≈ 1-5% din celulele vii
    [frac_P, frac_H, frac_N] = compartiment_fractii(V0_mm3);
    frac_live  = frac_P + frac_H;
    CS_frac    = 0.02 * frac_live;   % 2% din celulele vii

    % Ajustare pentru a suma la 1
    frac_P_adj = frac_P - CS_frac;

    PS0 = frac_P_adj * 0.90 * V0_mm3;
    PR0 = frac_P_adj * 0.10 * V0_mm3;
    H0  = frac_H * V0_mm3;
    N0  = frac_N * V0_mm3;
    CS0 = CS_frac * V0_mm3;
    y0  = [PS0; PR0; H0; N0; CS0];

    %% Struct parametri ODE [FIX 3.1] — parametri identici cu validare_model
    p_baza = struct(...
        'rP',           params_final.rP,   ...
        'K',            params_final.K,    ...
        'aPH',          params_final.aPH,  ...
        'aHN',          0.004,             ...
        'dN',           0.001,             ...
        'mu_SR_base',   mu_SR_base,        ...
        'mu_RS',        mu_RS,             ...
        'mu_SR_factor', mu_SR_factor,      ...
        'mgmt_SR',      mgmt_SR,           ...
        'muP_S',        muP_S,             ...
        'muP_R',        muP_R,             ...
        'muP_CS',       muP_CS,            ...
        'rCS',          rCS,               ...
        'aCS_to_PS',    aCS_to_PS,         ...
        't_PK',         t_PK,              ...
        'u_t',          u_t,               ...
        'u_t_redus',    u_t_redus,         ...
        'cu_tratament', true               ...
    );

    p_no              = p_baza;
    p_no.cu_tratament = false;

    %% Integrare ode15s
    opts  = odeset('RelTol',1e-5,'AbsTol',1e-7*ones(1,5),...
                   'MaxStep',0.5,'NonNegative',[1 2 3 4 5]);
    tspan = [0, T_final];

    [t_tr, Y_tr] = ode15s(@(t,y) gbm_ode_unificat(t,y,p_baza), tspan, y0, opts);
    [t_no, Y_no] = ode15s(@(t,y) gbm_ode_unificat(t,y,p_no),   tspan, y0, opts);

    PS_tr = Y_tr(:,1); PR_tr = Y_tr(:,2);
    H_tr  = Y_tr(:,3); N_tr  = Y_tr(:,4); CS_tr = Y_tr(:,5);
    V_tr  = sum(Y_tr, 2);
    V_no  = sum(Y_no, 2);

    %% Calcul reducere pe grila comuna
    t_com  = linspace(0, T_final, 500);
    V_no_i = interp1(t_no, V_no, t_com, 'linear');
    V_tr_i = interp1(t_tr, V_tr, t_com, 'linear');
    reducere = 100*(V_no_i(end) - V_tr_i(end)) / max(V_no_i(end), eps);

    %% Plot
    cla(ax); hold(ax,'on');

    plot(ax, t_no, V_no/1000,  '-',  'LineWidth',2.2,'Color',[0.2 0.4 0.8]);
    plot(ax, t_tr, V_tr/1000,  '-',  'LineWidth',2.2,'Color',[0.8 0.2 0.2]);
    plot(ax, t_tr, PS_tr/1000, '--', 'LineWidth',1.0,'Color',[0.9 0.7 0.1]);
    plot(ax, t_tr, PR_tr/1000, '--', 'LineWidth',1.0,'Color',[0.7 0.1 0.7]);
    plot(ax, t_tr, H_tr/1000,  '--', 'LineWidth',1.0,'Color',[0.1 0.7 0.3]);
    plot(ax, t_tr, N_tr/1000,  '--', 'LineWidth',1.0,'Color',[0.4 0.4 0.4]);
    plot(ax, t_tr, CS_tr/1000, '--', 'LineWidth',1.0,'Color',[1.0 0.4 0.1]);

    xline(ax, zi_trat,'--m','Start TMZ','LabelVerticalAlignment','bottom');
    legend(ax,{'Fara tratament','Cu tratament','P_S','P_R','H','N','CS'},...
           'Location','northwest','FontSize',9);

    ax.Title.String  = sprintf(...
        'Digital Twin GBM v2 — rP=%.4f, K=%.0f mm^3, aPH=%.4f /zi',...
        params_final.rP, params_final.K, params_final.aPH);
    ax.XLabel.String = 'Timp [zile]';
    ax.YLabel.String = 'Volum tumoral [cm^3]';
    grid(ax,'on');
    hold(ax,'off');

    infoLabel.Text = sprintf(...
        'Volum final  |  Fara TMZ: %.2f cm^3   Cu TMZ: %.2f cm^3   Reducere: %.1f%%',...
        V_no_i(end)/1000, V_tr_i(end)/1000, reducere);
end



%% 
function [frac_P, frac_H, frac_N] = compartiment_fractii(V0_mm3)
    if V0_mm3 < 5000          % tumori mici (< 5 cm^3), posibil pre-chirurgical
        frac_P = 0.45;
        frac_H = 0.25;
        frac_N = 0.15;
    elseif V0_mm3 < 30000     % dimensiune tipica la diagnostic (5-30 cm^3)
        frac_P = 0.30;
        frac_H = 0.20;
        frac_N = 0.40;
    else                      % tumori mari (> 30 cm^3)
        frac_P = 0.20;
        frac_H = 0.18;
        frac_N = 0.50;
    end
    % Verificare suma (fara CS care e dedus din frac_live)
    total = frac_P + frac_H + frac_N;
    if total > 1.0
        frac_N = 1.0 - frac_P - frac_H;  % ajustare necroza
    end
end



%% 
function dydt = gbm_ode_unificat(t, y, p)
% Compartimente: y = [PS; PR; H; N; CS]

    PS = y(1); PR = y(2); Hc = y(3); N = y(4); CS = y(5);

    V_tot = PS + PR + Hc + N + CS;
    if V_tot <= 0, V_tot = eps; end

    limit_factor = max(0, 1 - V_tot / p.K);

    if p.cu_tratament
        u_now     = interp1(p.t_PK, p.u_t,       t, 'linear', 0);
        u_red_now = interp1(p.t_PK, p.u_t_redus, t, 'linear', 0);
    else
        u_now     = 0;
        u_red_now = 0;
    end

    stress_factor = (Hc + N) / V_tot;
    mu_SR = (p.mu_SR_base + p.mu_SR_factor * p.mu_SR_base * stress_factor) ...
            * p.mgmt_SR;

    dPS = p.rP  * PS * limit_factor ...
          - p.aPH  * PS ...
          - mu_SR  * PS ...
          + p.mu_RS * PR ...
          - p.muP_S * u_now * PS ...
          + p.aCS_to_PS * CS;

    dPR = p.rP  * PR * limit_factor ...
          - p.aPH  * PR ...
          + mu_SR  * PS ...
          - p.mu_RS * PR ...
          - p.muP_R * u_now * PR;

    dH  = p.aPH * (PS + PR) ...
          - p.aHN * Hc ...
          - 0.004 * u_red_now * Hc;

    dN  = p.aHN * Hc - p.dN * N;

    dCS = p.rCS * CS * limit_factor ...
          - p.aCS_to_PS * CS ...
          - p.muP_CS * u_now * CS;

    dydt = [dPS; dPR; dH; dN; dCS];
end


%% 
%  VALIDARE INTRARI

function [ok, msg] = validateInputs(fig)
    H  = getappdata(fig,'H');
    ok = true; msgs = {}; show_alert = false;

    campuri = {H.ageField, H.V0Field, H.weightField, H.heightField,...
               H.TField, H.ZField, H.DField, H.EField};
    for k = campuri
        k{1}.BackgroundColor = [1 1 1];
    end

    checks = {
        H.ageField,    'Varsta',                      [0   140];
        H.V0Field,     'Volumul initial (V0)',         [1   Inf];
        H.weightField, 'Greutatea',                    [30  200];
        H.heightField, 'Inaltimea',                    [1.0 2.5];
        H.TField,      'Durata simularii (T)',          [10  Inf];
        H.ZField,      'Ziua de start tratament',      [0   Inf];
        H.DField,      'Dozajul (D)',                   [50  Inf];
    };

    for i = 1:size(checks,1)
        fld = checks{i,1}; lbl = checks{i,2};
        mn  = checks{i,3}(1); mx = checks{i,3}(2);
        val = fld.Value; err = false;

        if val < mn
            msgs{end+1} = sprintf('%s: valoare prea mica (%.2f < %.2f).', lbl, val, mn); %#ok<AGROW>
            err = true; show_alert = true;
        end
        if val > mx && mx < Inf
            msgs{end+1} = sprintf('%s: depaseste limita maxima (%.2f > %.2f).', lbl, val, mx); %#ok<AGROW>
            err = true; show_alert = true;
        end
        if err, fld.BackgroundColor = [1 0.7 0.7]; end
    end

    if ~isempty(msgs)
        ok = false;
        msg = ''; if show_alert, msg = strjoin(msgs, newline); end
        H.info.Text = 'Simularea nu a pornit — corectati campurile rosii.';
    else
        msg = '';
        H.info.Text = 'Se calculeaza...';
    end
end


%% 
%  IMPORT DATE RMN (NIfTI / BraTS)

function importMRI_Callback(fig)
    H = getappdata(fig,'H');
    originalPointer = fig.Pointer;
    fig.Pointer = 'watch'; drawnow;
    select_folder_dialog(fig, fullfile(pwd,'Data'), H);
    result = getappdata(fig,'importResult');
    if isempty(result) || ~result.ok
        fig.Pointer = originalPointer;
        return;
    end
    rmappdata(fig,'importResult');
    fig.Pointer = originalPointer; drawnow;
end


%% 
%  DIALOG SELECTARE FOLDER PACIENT

function select_folder_dialog(fig, dataDir, H)
    if ~exist(dataDir,'dir')
        uialert(fig,'Nu exista folderul Data/ in directorul curent!',...
                'Eroare','Icon','error');
        return;
    end

    allItems = dir(dataDir);
    folderNames = {}; folderPaths = {};
    for k = 1:length(allItems)
        nm = allItems(k).name;
        if allItems(k).isdir && ~strcmp(nm,'.') && ~strcmp(nm,'..')
            folderNames{end+1} = nm;                      
            folderPaths{end+1} = fullfile(dataDir, nm);   
        end
    end

    if isempty(folderNames)
        uialert(fig,'Nu s-au gasit foldere pacient in Data/','Info','Icon','info');
        return;
    end

    [folderNames, si] = sort(folderNames);
    folderPaths = folderPaths(si);

    dlg = uifigure('Name','Selectare Folder Pacient',...
                   'Position',[300 200 480 500],...
                   'Resize','off','WindowStyle','modal');
    dlg.Color = [0.95 0.95 0.97];

    uilabel(dlg,'Text','Selectati folderul pacientului:',...
            'Position',[20 450 440 30],'FontWeight','bold','FontSize',12);
    uilabel(dlg,'Text','Foldere disponibile (Data/):',...
            'Position',[20 415 250 25],'FontWeight','bold','FontSize',10);

    listbox = uilistbox(dlg,'Items',folderNames,...
                        'Position',[20 120 440 290],'Value',folderNames{1});
    selLabel = uilabel(dlg,...
        'Text',sprintf('Folder selectat: %s', folderNames{1}),...
        'Position',[20 80 440 25],'FontWeight','bold','FontSize',10,...
        'FontColor',[0.1 0.1 0.6]);

    listbox.ValueChangedFcn = @(src,~) set(selLabel,'Text',...
        sprintf('Folder selectat: %s', src.Value));

    confirmBtn = uibutton(dlg,'Text','CONFIRMA SELECTIA',...
        'Position',[120 25 240 40],'FontSize',13,'FontWeight','bold',...
        'BackgroundColor',[0.2 0.4 0.8],'FontColor',[1 1 1]);
    confirmBtn.ButtonPushedFcn = @(~,~) onConfirm();

    waitfor(dlg);

    function onConfirm()
        selName = listbox.Value;
        idx     = find(strcmp(folderNames, selName), 1);
        if isempty(idx)
            selLabel.Text = 'Selectati un folder din lista!';
            selLabel.FontColor = [0.8 0 0];
            return;
        end

        chosenPath = folderPaths{idx};
        segFile    = fullfile(chosenPath, 'seg.nii.gz');

        if ~exist(segFile,'file')
            uialert(fig,'Nu am gasit fisierul seg.nii.gz in folderul selectat!',...
                    'Eroare Import','Icon','error');
            return;
        end

        try
            info             = niftiinfo(segFile);
            segmentationMask = niftiread(info);
            vox_vol          = prod(info.PixelDimensions);

            % Volum solid BraTS: label 1 (necroza) + label 4 (tumora activa)
            % Menze et al., IEEE TMI 2015
            mask_solida  = (segmentationMask == 1) | (segmentationMask == 4);
            volume_mm3   = sum(mask_solida(:)) * vox_vol;

            H.V0Field.Value           = round(volume_mm3, 2);
            H.V0Field.BackgroundColor = [0.8 1 0.8];

            [~, pName]  = fileparts(chosenPath);
            H.info.Text = sprintf('Importat: %s — V0 = %.2f mm^3', pName, volume_mm3);
            drawnow;

            setappdata(fig,'importResult', struct('ok',true,'path',chosenPath));
        catch ME
            uialert(fig,['Eroare NIfTI: ' ME.message],'Eroare Import','Icon','error');
            setappdata(fig,'importResult', struct('ok',false,'path',''));
        end

        if isvalid(dlg), delete(dlg); end
    end
end