%% INIZIA_QUI  Controlla che il PC sia pronto. Premete Run.
% Controlla MATLAB, i toolbox, la rete YOLOE e la rete Wi-Fi,
% e vi dice cosa manca e come rimediare.

radice = fileparts(mfilename('fullpath'));
addpath(genpath(radice));
fprintf('\n===== Controllo del PC =====\n\n');
problemi = 0;

if isMATLABReleaseOlderThan("R2023b")
    fprintf('[!!] MATLAB %s: serve R2023b o piu'' recente.\n', version('-release'));
    problemi = problemi + 1;
else
    fprintf('[ok] MATLAB %s\n', version('-release'));
end

toolbox = {'simulink', 'Simulink'; 'images', 'Image Processing Toolbox'; 'nnet', 'Deep Learning Toolbox'};
for k = 1:size(toolbox, 1)
    if isempty(ver(toolbox{k, 1}))
        fprintf('[!!] Manca %s: installatelo da Home > Add-Ons.\n', toolbox{k, 2});
        problemi = problemi + 1;
    else
        fprintf('[ok] %s\n', toolbox{k, 2});
    end
end

if usejava('jvm')
    fprintf('[ok] Java attivo (serve al collegamento con il telefono)\n');
else
    fprintf(['[!!] Java non trovato (serve al collegamento con il telefono). Installate il pacchetto gratuito\n' ...
             '     "MATLAB Support for OpenJDK" (cercatelo su File Exchange, numero 180823), poi riavviate MATLAB.\n']);
    problemi = problemi + 1;
end

try
    t0 = tic;
    r = Riconoscitore("oggetti");
    ogg = r.rileva(zeros(480, 640, 3, 'uint8'));
    fprintf('[ok] Riconoscimento pronto (%.1f s). Modelli: %s\n', toc(t0), strjoin(Riconoscitore.modelli(), ', '));
catch e
    fprintf('[!!] Il riconoscimento non parte:\n%s\n', e.message);
    problemi = problemi + 1;
end

try
    jar = fullfile(radice, 'componenti', 'telefono', 'ponte.jar');
    if ~any(strcmp(javaclasspath('-dynamic'), jar)), javaaddpath(jar); end
    ips = javaMethod('indirizzi', 'it.scuola.ponte.Ponte');
    if numel(ips) == 0
        fprintf('[!!] Il PC non e'' collegato a nessuna rete: collegatevi al Wi-Fi.\n');
        problemi = problemi + 1;
    else
        fprintf('[ok] Rete: indirizzo del PC %s\n', char(ips(1)));
    end
catch e
    fprintf('[!!] Componente telefono non caricato: %s\n', e.message);
    problemi = problemi + 1;
end

fprintf('\n');
if problemi == 0
    fprintf('TUTTO PRONTO!  Prossimo passo: aprite PROVA_MATLAB.m (oppure PROVA_SIMULINK.slx) e premete Run.\n\n');
else
    fprintf('%d problema/i da risolvere: vedete i punti [!!] e la guida, Passo 0.\n\n', problemi);
end
