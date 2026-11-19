function riconoscitore_scegli(blocco)
%RICONOSCITORE_SCEGLI  Finestra del blocco "Riconoscitore": scegliete il modello e,
%   da un elenco con le caselle, gli oggetti da riconoscere. Non serve modificarla.
%   Si apre con il pulsante "Scegli dall'elenco" nelle impostazioni del blocco.

modelli = Riconoscitore.modelli();
if isempty(modelli)
    errordlg('Nella cartella modelli non c''e'' nessun modello.', 'Riconoscitore');
    return
end
modello = string(get_param(blocco, 'Modello'));
if ~ismember(modello, modelli), modello = modelli(1); end
scelte = strtrim(split(string(get_param(blocco, 'Etichette')), ","));
scelte = scelte(scelte ~= "");
maxPrima = str2double(get_param(blocco, 'MaxOggetti'));
if isnan(maxPrima), maxPrima = 10; end

f = uifigure('Name', 'Riconoscitore - cosa riconoscere', 'Position', [100 100 440 600], ...
    'WindowStyle', 'modal', 'Resize', 'off');
movegui(f, 'center');
g = uigridlayout(f, [9 2], 'RowHeight', {20, 30, 12, 20, 30, '1x', 30, 12, 36}, ...
    'ColumnWidth', {'1x', '1x'}, 'Padding', [18 16 18 16], 'RowSpacing', 6);

t = uilabel(g, 'Text', 'Modello (la rete da usare)', 'FontWeight', 'bold'); t.Layout.Column = [1 2];
dd = uidropdown(g, 'Items', modelli, 'Value', modello); dd.Layout.Column = [1 2];
uilabel(g, 'Text', ''); uilabel(g, 'Text', '');
t = uilabel(g, 'Text', 'Cosa riconoscere (nessuna spunta = tutto)', 'FontWeight', 'bold'); t.Layout.Column = [1 2];
cerca = uieditfield(g, 'Placeholder', 'Cerca... (es. bottle)');
tutti = uibutton(g, 'Text', 'Togli tutte le spunte');
albero = uitree(g, 'checkbox'); albero.Layout.Column = [1 2];
uilabel(g, 'Text', 'Numero massimo di oggetti', 'FontWeight', 'bold');
sp = uispinner(g, 'Limits', [1 100], 'RoundFractionalValues', 'on', 'Value', min(max(maxPrima, 1), 100));
uilabel(g, 'Text', ''); uilabel(g, 'Text', '');
annulla = uibutton(g, 'Text', 'Annulla');
ok = uibutton(g, 'Text', 'OK', 'FontWeight', 'bold', 'BackgroundColor', [0 0.48 1], 'FontColor', [1 1 1]);

stato.etichette = strings(0, 1);
stato.spuntate = scelte;
riempi();

dd.ValueChangedFcn = @(~, ~) cambiaModello();
cerca.ValueChangingFcn = @(~, e) riempi(e.Value);
albero.CheckedNodesChangedFcn = @(~, ~) ricordaSpunte();
tutti.ButtonPushedFcn = @(~, ~) togliTutte();
annulla.ButtonPushedFcn = @(~, ~) delete(f);
ok.ButtonPushedFcn = @(~, ~) applica();

    function cambiaModello()
        stato.spuntate = strings(0, 1);
        cerca.Value = '';
        riempi();
    end

    function riempi(filtro)
        if nargin < 1, filtro = cerca.Value; end
        stato.etichette = Riconoscitore.etichetteDi(dd.Value);
        delete(albero.Children);
        vedi = stato.etichette;
        if strlength(string(filtro)) > 0
            vedi = vedi(contains(vedi, string(filtro), 'IgnoreCase', true));
        end
        nodi = matlab.ui.container.TreeNode.empty;
        for k = 1:numel(vedi)
            nodi(end + 1) = uitreenode(albero, 'Text', vedi(k), 'NodeData', vedi(k)); %#ok<AGROW>
        end
        daSpuntare = nodi(ismember(lower(vedi), lower(stato.spuntate)));
        if isempty(daSpuntare)
            albero.CheckedNodes = [];
        else
            albero.CheckedNodes = daSpuntare;
        end
    end

    function ricordaSpunte()
        visibili = nomiDi(albero.Children);
        spuntate = nomiDi(albero.CheckedNodes);
        stato.spuntate = [stato.spuntate(~ismember(stato.spuntate, visibili)); spuntate(:)];
    end

    function togliTutte()
        stato.spuntate = strings(0, 1);
        albero.CheckedNodes = [];
    end

    function applica()
        sel = stato.etichette(ismember(lower(stato.etichette), lower(stato.spuntate)));   % nell'ordine del modello
        if numel(sel) == numel(stato.etichette), sel = strings(0, 1); end                  % tutte = tutto
        inCorso = ~strcmp(get_param(bdroot(blocco), 'SimulationStatus'), 'stopped');
        try
            set_param(blocco, 'Modello', char(dd.Value), 'Etichette', char(strjoin(sel, ', ')));
            if sp.Value ~= maxPrima
                if inCorso
                    uialert(f, ['Il numero massimo di oggetti si cambia a simulazione ferma. ' ...
                        'Il resto e'' gia'' applicato.'], 'Riconoscitore', 'Icon', 'info', ...
                        'CloseFcn', @(~, ~) delete(f));
                    return
                end
                set_param(blocco, 'MaxOggetti', num2str(sp.Value));
            end
            delete(f);
        catch e
            uialert(f, e.message, 'Riconoscitore');
        end
    end
end

function n = nomiDi(nodi)
n = strings(0, 1);
for k = 1:numel(nodi), n(end + 1, 1) = string(nodi(k).NodeData); end %#ok<AGROW>
end
