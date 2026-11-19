classdef Riconoscitore < handle
%RICONOSCITORE  Riconosce oggetti in un'immagine con una rete YOLOE (Ultralytics).
%   La rete gira dentro MATLAB (Deep Learning Toolbox): non serve Python.
%
%   r = Riconoscitore();                          % modello "oggetti" (80 oggetti comuni)
%   r = Riconoscitore("frutta");                  % un modello della cartella modelli/
%   r = Riconoscitore("frutta", Etichette=["apple", "pear"]);   % solo alcune etichette
%   r.Soglia = 0.30;                              % (facoltativo) punteggio minimo 0..1
%   r.MaxOggetti = 5;                             % (facoltativo) al massimo 5 oggetti
%
%   ogg = r.rileva(img);               % tabella: Etichetta, Punteggio, Box [x y w h], Classe
%   r.Etichette                        % tutte le etichette che il modello conosce
%   r.trova("bottle")                  % cerca tra le etichette del modello
%   r.mostra(img, ogg)                 % disegna i riquadri in una figura
%   ris = r.perTelefono(ogg, img);     % risultato pronto per tel.inviaRisultato(ris)
%
%   I modelli sono le cartelle dentro "modelli" (li prepara il docente).
%   Riconoscitore.modelli() li elenca.

    properties
        Soglia (1,1) double = 0.25          % punteggio minimo per tenere un oggetto
        Classi string = strings(0, 1)       % se non vuoto: tieni solo queste etichette
        MaxOggetti (1,1) double = Inf       % al massimo quanti oggetti (i piu' sicuri)
        SovrapposizioneMax (1,1) double = 0.7   % due riquadri piu' sovrapposti di cosi' = stesso oggetto
    end

    properties (SetAccess = private)
        Modello string = ""                 % nome del modello in uso
        Etichette string = strings(0, 1)    % tutte le etichette che il modello conosce
        Motore string = "MATLAB"            % la rete gira con Deep Learning Toolbox
        Lato double = 640                   % lato dell'immagine che la rete vuole
    end

    properties (Access = private)
        Rete                                % dlnetwork
    end

    methods
        function obj = Riconoscitore(modello, opz)
            arguments
                modello (1,1) string = "oggetti"
                opz.Etichette string = strings(0, 1)   % es. ["apple", "pear"] o "apple, pear"
            end
            if isempty(ver('nnet'))
                error('Riconoscitore:toolbox', ['Serve Deep Learning Toolbox: ' ...
                    'installatelo da Home > Add-Ons > Get Add-Ons (e'' nella licenza della scuola).']);
            end
            if strtrim(modello) == "", modello = "oggetti"; end
            [obj.Rete, obj.Etichette, obj.Lato] = caricaModello(strtrim(modello));
            [~, obj.Modello] = fileparts(strtrim(modello));

            etichette = strtrim(split(strjoin(opz.Etichette, ","), ","));
            etichette = etichette(etichette ~= "");
            if ~isempty(etichette)
                manca = etichette(~ismember(lower(etichette), lower(obj.Etichette)));
                if ~isempty(manca)
                    warning('Riconoscitore:etichette', ['Il modello "%s" non conosce: %s.\n' ...
                        'Etichette disponibili: %s.\nPer cose nuove chiedete un modello al docente.'], ...
                        obj.Modello, strjoin(manca, ', '), strjoin(obj.Etichette, ', '));
                end
                obj.Classi = etichette;
            end
            fprintf('[Riconoscitore] Modello "%s": %d etichette.\n', obj.Modello, numel(obj.Etichette));
        end

        function ogg = rileva(obj, img)
        %RILEVA  Oggetti trovati nell'immagine (tabella, dal punteggio piu' alto).
            if size(img, 3) == 1, img = repmat(img, 1, 1, 3); end
            img = im2uint8(img);
            [h, w, ~] = size(img);
            S = obj.Lato;
            scala = min(S / h, S / w);
            nh = floor(h * scala); nw = floor(w * scala);
            dx = floor((S - nw) / 2); dy = floor((S - nh) / 2);
            tela = uint8(114 * ones(S, S, 3));
            % niente antialias: la rete e' addestrata con il ridimensionamento semplice
            tela(dy + (1:nh), dx + (1:nw), :) = imresize(img, [nh nw], 'bilinear', 'Antialiasing', false);

            Y = extractdata(predict(obj.Rete, dlarray(single(tela) / 255, 'SSCB')));
            Y = double(reshape(Y, 4 + numel(obj.Etichette), []));   % righe: cx cy w h, punteggi
            punteggi = Y(5:end, :);
            if ~isempty(obj.Classi)                                  % solo le etichette scelte
                punteggi(~ismember(lower(obj.Etichette), lower(obj.Classi)), :) = 0;
            end
            [p, classe] = max(punteggi, [], 1);
            tieni = find(p >= obj.Soglia);
            [~, ordine] = sort(p(tieni), 'descend');
            tieni = tieni(ordine(1:min(end, 300)));
            b = Y(1:4, tieni).';
            box = [b(:, 1) - b(:, 3) / 2, b(:, 2) - b(:, 4) / 2, b(:, 1) + b(:, 3) / 2, b(:, 2) + b(:, 4) / 2];
            k = sopprimiDoppioni(box, classe(tieni).', obj.SovrapposizioneMax);
            box = box(k, :); p = p(tieni(k)).'; classe = classe(tieni(k)).';

            x1 = min(max((box(:, 1) - dx) / scala, 0), w);
            y1 = min(max((box(:, 2) - dy) / scala, 0), h);
            x2 = min(max((box(:, 3) - dx) / scala, 0), w);
            y2 = min(max((box(:, 4) - dy) / scala, 0), h);
            ogg = table(obj.Etichette(classe), p, [x1, y1, x2 - x1, y2 - y1], classe, ...
                'VariableNames', {'Etichetta', 'Punteggio', 'Box', 'Classe'});
            ogg = ogg(1:min(height(ogg), obj.MaxOggetti), :);
            setappdata(0, 'Riconoscitore_attivo', obj);      % perTelefono dice al telefono cosa si cerca
        end

        function t = cosaCerco(obj)
        %COSACERCO  Testo breve con modello, etichette e numero massimo (es. per il telefono).
            if isempty(obj.Classi)
                cosa = "tutto";
            else
                cosa = strjoin(obj.Classi, ", ");
            end
            t = obj.Modello + " · " + cosa;
            if isfinite(obj.MaxOggetti), t = t + " · max " + obj.MaxOggetti; end
        end

        function trovate = trova(obj, testo)
        %TROVA  Etichette del modello che contengono il testo (es. r.trova("bottle")).
            trovate = obj.Etichette(contains(obj.Etichette, testo, 'IgnoreCase', true));
            if nargout == 0
                fprintf('%d etichette con "%s": %s\n', numel(trovate), testo, strjoin(trovate, ', '));
                clear trovate
            end
        end

        function mostra(~, img, ogg, ax)
        %MOSTRA  Disegna l'immagine con i riquadri degli oggetti.
            if nargin < 4, ax = gca; end
            foto = findobj(ax, 'Type', 'image', 'Tag', 'Riconoscitore_foto');
            if isempty(foto) || ~isequal(size(foto(1).CData), size(img))
                foto = imshow(img, 'Parent', ax);            % la prima volta
                foto.Tag = 'Riconoscitore_foto';
            else
                foto(1).CData = img;                         % poi aggiorna solo i pixel (piu' veloce)
            end
            delete(findobj(ax, 'Tag', 'Riconoscitore_box'));
            colori = lines(7);
            for i = 1:height(ogg)
                c = colori(mod(i - 1, 7) + 1, :);
                rectangle(ax, 'Position', ogg.Box(i, :), 'EdgeColor', c, 'LineWidth', 2, ...
                    'Tag', 'Riconoscitore_box');
                text(ax, ogg.Box(i, 1), ogg.Box(i, 2), sprintf(' %s %.0f%% ', ogg.Etichetta(i), ...
                    100 * ogg.Punteggio(i)), 'Color', 'w', 'BackgroundColor', c, ...
                    'FontSize', 8, 'VerticalAlignment', 'bottom', 'Interpreter', 'none', ...
                    'Tag', 'Riconoscitore_box');
            end
        end
    end

    methods (Static)
        function nomi = modelli()
        %MODELLI  Elenca i modelli disponibili nella cartella modelli del kit.
            d = dir(fullfile(cartellaModelli(), '*', 'rete.mat'));
            nomi = string({d.folder});
            [~, nomi] = fileparts(nomi);
            nomi = nomi(:);
            if nargout == 0
                for n = nomi.'
                    e = strip(splitlines(string(fileread(fullfile(cartellaModelli(), n, 'etichette.txt')))));
                    e = e(e ~= "");
                    fprintf('  %-12s %s\n', n, strjoin(e(1:min(end, 12)), ', ') + ...
                        string(repmat(', ...', 1, numel(e) > 12)));
                end
                clear nomi
            end
        end

        function e = etichetteDi(nome)
        %ETICHETTEDI  Le etichette di un modello, senza caricarlo: Riconoscitore.etichetteDi("frutta")
            e = strip(splitlines(string(fileread(fullfile(cartellaModelli(), nome, 'etichette.txt')))));
            e = e(e ~= "");
        end

        function cartella = prepara(nome, fileOnnx, etichette, destinazione, copiaOnnx)
        %PREPARA  (docente) Trasforma un file .onnx di Ultralytics in un modello del kit.
        %   Serve "Deep Learning Toolbox Converter for ONNX Model Format".
        %   Crea la cartella destinazione/nome con rete.mat, rete.onnx, etichette.txt
        %   e i livelli generati da MATLAB (+rete_nome). rete.onnx serve ai PC con un
        %   MATLAB piu' vecchio: li' il modello viene ricreato da rete.onnx.
            arguments
                nome (1,1) string
                fileOnnx (1,1) string
                etichette string
                destinazione (1,1) string = cartellaModelli()
                copiaOnnx (1,1) logical = true
            end
            if isempty(which('importNetworkFromONNX'))
                error('Riconoscitore:onnx', ['Manca "Deep Learning Toolbox Converter for ONNX Model Format": ' ...
                    'installatelo da Home > Add-Ons > Get Add-Ons (e'' gratuito).']);
            end
            fileOnnx = assoluto(fileOnnx);
            etichette = etichette(:);
            cartella = fullfile(destinazione, nome);
            spazio = "rete_" + matlab.lang.makeValidName(nome);
            temp = string(tempname) + ".onnx";
            copyfile(fileOnnx, temp);                  % il .onnx potrebbe stare proprio nella cartella da rifare
            pulisci = onCleanup(@() delete(temp));
            if isfolder(cartella), rmdir(cartella, 's'); end
            mkdir(cartella);
            vecchia = cd(cartella);
            ripristina = onCleanup(@() cd(vecchia));
            avvisi = warning('off', 'all');
            ripristinaAvvisi = onCleanup(@() warning(avvisi));
            try
                net = importNetworkFromONNX(temp, Namespace = spazio, GenerateCoderFiles = false);
            catch
                try
                    net = importNetworkFromONNX(temp, Namespace = spazio);     % MATLAB senza GenerateCoderFiles
                catch
                    net = importNetworkFromONNX(temp, PackageName = spazio);   % R2023b: "PackageName"
                end
            end
            clear ripristinaAvvisi
            prova = extractdata(predict(net, dlarray(zeros(640, 640, 3, 'single'), 'SSCB')));
            if mod(numel(prova), 4 + numel(etichette)) ~= 0 || numel(prova) / (4 + numel(etichette)) < 100
                error('Riconoscitore:forma', ['La rete ha %d uscite, ma ci sono %d etichette.\n' ...
                    'Esportate da Ultralytics con nms=False.'], numel(prova), numel(etichette));
            end
            lato = 640;
            creatoCon = "R" + string(version('-release'));     % versione di MATLAB che ha salvato rete.mat
            save(fullfile(cartella, 'rete.mat'), 'net', 'etichette', 'lato', 'creatoCon');
            writelines(etichette, fullfile(cartella, 'etichette.txt'));
            if copiaOnnx, copyfile(temp, fullfile(cartella, 'rete.onnx')); end
            Riconoscitore.svuotaMemoria();
        end

        function svuotaMemoria()
        %SVUOTAMEMORIA  Dimentica i modelli gia' caricati (dopo averli cambiati).
            memoriaModelli(true);
        end

        function ris = perTelefono(ogg, img)
        %PERTELEFONO  Risultato standard per il telefono: titolo, elenco, riquadri.
        %   Si usa anche senza oggetto: Riconoscitore.perTelefono(ogg, img).
        %   img e' l'immagine analizzata (oppure le sue dimensioni [altezza larghezza]).
            if isvector(img) && numel(img) == 2
                h = img(1); w = img(2);
            else
                [h, w, ~] = size(img);
            end
            n = height(ogg);
            if n == 0
                ris.titolo = "Non vedo niente";
            elseif n == 1
                ris.titolo = "Vedo 1 oggetto";
            else
                ris.titolo = sprintf("Vedo %d oggetti", n);
            end
            ris.colore = "grigio";
            if isappdata(0, 'Riconoscitore_attivo')               % cosa sta cercando MATLAB
                r = getappdata(0, 'Riconoscitore_attivo');
                if isa(r, 'Riconoscitore') && isvalid(r), ris.cerco = r.cosaCerco(); end
            end
            [nomi, ~, k] = unique(ogg.Etichetta, 'stable');
            conteggi = accumarray(k, 1);
            ris.voci = struct('nome', cellstr(compose("%d %s", conteggi, nomi)).', 'ok', {[]});
            ris.dettaglio = "";
            colori = ["blu", "giallo", "verde", "arancio", "#c85aff", "rosso"];
            ris.box = struct('x', {}, 'y', {}, 'w', {}, 'h', {}, 'etichetta', {}, 'colore', {});
            for i = 1:n
                b = ogg.Box(i, :);
                ris.box(end + 1) = struct('x', b(1) / w, 'y', b(2) / h, 'w', b(3) / w, 'h', b(4) / h, ...
                    'etichetta', sprintf('%s %.0f%%', ogg.Etichetta(i), 100 * ogg.Punteggio(i)), ...
                    'colore', colori(mod(k(i) - 1, numel(colori)) + 1));
            end
        end
    end
end

% =========================================================================
function c = cartellaModelli()
% La cartella "modelli" del kit: la cerca salendo dalla cartella di questo file.
d = fileparts(mfilename('fullpath'));
for k = 1:4
    if isfolder(fullfile(d, 'modelli')), c = string(fullfile(d, 'modelli')); return; end
    d = fileparts(d);
end
c = string(fullfile(fileparts(mfilename('fullpath')), 'modelli'));
end

function f = assoluto(f)
if ~isfile(f), error('Riconoscitore:file', 'File non trovato: %s', f); end
d = dir(f);
f = string(fullfile(d.folder, d.name));
end

function [net, etichette, lato] = caricaModello(nome)
% Carica (una volta sola per sessione) la cartella modelli/<nome>.
if isfolder(nome) && contains(nome, ["/", "\"])               % percorso di una cartella
    cartella = nome;
else
    cartella = fullfile(cartellaModelli(), nome);
end
[~, nomeCartella] = fileparts(cartella);
file = fullfile(cartella, 'rete.mat');
m = memoriaModelli();
chiave = char(file);                              % percorso completo: copie diverse del kit non si confondono
if isKey(m, chiave) && isfile(file)
    v = m(chiave); net = v.net; etichette = v.etichette; lato = v.lato;
    return
end
if ~isfile(file)
    onnx = fullfile(cartellaModelli(), nome + ".onnx");         % un .onnx sciolto: lo prepara ora
    txt = fullfile(cartellaModelli(), nome + ".txt");
    if isfile(onnx) && isfile(txt) && ~isempty(which('importNetworkFromONNX'))
        fprintf('[Riconoscitore] Preparo il modello "%s" (solo la prima volta)...\n', nome);
        e = strip(splitlines(string(fileread(txt)))); e = e(e ~= "");
        Riconoscitore.prepara(nome, onnx, e);
    else
        disponibili = Riconoscitore.modelli();
        error('Riconoscitore:modello', 'Modello "%s" non trovato. Disponibili: %s', ...
            nome, strjoin(disponibili, ', '));
    end
end

if ~matUsabile(file)
    % rete.mat e' stato salvato da un MATLAB piu' nuovo: si ricrea il modello da rete.onnx,
    % una volta sola, in una cartella di questo PC (prefdir, diversa per ogni versione di MATLAB)
    onnx = fullfile(cartella, 'rete.onnx');
    if ~isfile(onnx)
        error('Riconoscitore:versione', ['Il modello "%s" e'' stato preparato con un MATLAB piu'' recente ' ...
            'del vostro (%s). Aggiornate MATLAB oppure chiedete al docente il modello con il file rete.onnx.'], ...
            nomeCartella, "R" + version('-release'));
    end
    cache = fullfile(prefdir, 'KitTelefono_modelli');
    file = fullfile(cache, nomeCartella, 'rete.mat');
    dOnnx = dir(onnx); dMat = dir(file);
    if isempty(dMat) || dMat.datenum < dOnnx.datenum
        if isempty(which('importNetworkFromONNX'))
            error('Riconoscitore:onnx', ['Il vostro MATLAB (%s) e'' piu'' vecchio di quello che ha preparato ' ...
                'i modelli. Installate "Deep Learning Toolbox Converter for ONNX Model Format" da ' ...
                'Home > Add-Ons > Get Add-Ons (e'' gratuito) e riprovate.'], "R" + version('-release'));
        end
        fprintf(['[Riconoscitore] Preparo il modello "%s" per il vostro MATLAB ' ...
            '(solo la prima volta, circa 20 secondi)...\n'], nomeCartella);
        e = strip(splitlines(string(fileread(fullfile(cartella, 'etichette.txt'))))); e = e(e ~= "");
        Riconoscitore.prepara(nomeCartella, onnx, e, cache, false);
    end
    cartella = fullfile(cache, nomeCartella);
end
addpath(cartella);                                % i livelli generati (+rete_...)
v = load(file, 'net', 'etichette', 'lato');
net = v.net; etichette = string(v.etichette(:)); lato = v.lato;
m(chiave) = struct('net', net, 'etichette', etichette, 'lato', lato); %#ok<NASGU> (handle)
end

function ok = matUsabile(file)
% rete.mat si puo' aprire solo con la stessa versione di MATLAB che l'ha salvato, o una piu' nuova.
if getenv('KIT_TELEFONO_USA_ONNX') == "1", ok = false; return; end      % solo per le prove
creatoCon = "R2026b";                             % i primi modelli del kit, salvati senza questa informazione
w = whos('-file', file);
if any(strcmp({w.name}, 'creatoCon'))
    c = load(file, 'creatoCon'); creatoCon = c.creatoCon;
end
ok = ~isMATLABReleaseOlderThan(creatoCon);
end

function m = memoriaModelli(svuota)
persistent mappa
if isempty(mappa) || (nargin && svuota)
    mappa = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
m = mappa;
end

function tieni = sopprimiDoppioni(box, classe, soglia)
% Tra riquadri della stessa classe molto sovrapposti tiene quello col punteggio piu' alto
% (i riquadri arrivano gia' ordinati dal punteggio piu' alto).
n = size(box, 1);
b = box + classe * 10000;                         % classi diverse non si toccano mai
area = (b(:, 3) - b(:, 1)) .* (b(:, 4) - b(:, 2));
tolto = false(n, 1);
tieni = false(n, 1);
for i = 1:n
    if tolto(i), continue; end
    tieni(i) = true;
    j = i + 1:n;
    larg = max(0, min(b(i, 3), b(j, 3)) - max(b(i, 1), b(j, 1)));
    alt = max(0, min(b(i, 4), b(j, 4)) - max(b(i, 2), b(j, 2)));
    inter = larg .* alt;
    tolto(j) = tolto(j) | inter ./ (area(i) + area(j) - inter) > soglia;
end
tieni = find(tieni);
end
