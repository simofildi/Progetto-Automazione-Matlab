function telefono_schermo(oggetti, livello, idParametri)
%TELEFONO_SCHERMO  Usata dal blocco "Schermo telefono". Non serve modificarla.
%   oggetti  : N x 6 [x y larghezza altezza punteggio classe] (righe di zeri = vuote)
%   livello  : 0 = mostra solo cosa si vede; 1, 2, 3... = mostra il messaggio n. livello
%   I messaggi e i colori (separati da |) sono parametri del blocco.

persistent ultimoInvio
if ~isempty(ultimoInvio) && toc(ultimoInvio) < 0.08, return; end    % max ~12 al secondo
ultimoInvio = tic;

dim = [480 640];
if isappdata(0, 'Telefono_dimensioni'), dim = getappdata(0, 'Telefono_dimensioni'); end
etichette = strings(0, 1);
if isappdata(0, 'Riconoscitore_attivo')
    r = getappdata(0, 'Riconoscitore_attivo');
    if isvalid(r), etichette = r.Etichette; end
end

oggetti = oggetti(oggetti(:, 5) > 0, :);
classe = oggetti(:, 6);
nomi = "classe " + string(classe);
ok = classe >= 1 & classe <= numel(etichette);
nomi(ok) = etichette(classe(ok));
ogg = table(nomi, oggetti(:, 5), oggetti(:, 1:4), classe, ...
    'VariableNames', {'Etichetta', 'Punteggio', 'Box', 'Classe'});

ris = Riconoscitore.perTelefono(ogg, dim);
if livello >= 1
    par = parametri_blocco(idParametri);
    m = strtrim(split(string(par.Messaggi), "|"));
    c = strtrim(split(string(par.Colori), "|"));
    k = min(round(livello), numel(m));
    ris.dettaglio = ris.titolo;
    ris.titolo = m(k);
    ris.colore = c(min(k, numel(c)));
end
try
    tel = evalin('base', 'tel');
    tel.inviaRisultato(ris);
catch
end
end
