function varargout = parametri_blocco(id, valori)
%PARAMETRI_BLOCCO  Conserva i parametri di testo dei blocchi della libreria blocchi_telefono.
%   I blocchi MATLAB Function accettano solo parametri numerici: la maschera del
%   blocco salva qui i testi (modello, classi, messaggi...) e passa un numero.
%   Non serve modificarla.
%
%   id = parametri_blocco(gcbh, struttura)   salva (usato dalla maschera)
%   s  = parametri_blocco(id)                legge (usato dalle funzioni del blocco)

if isappdata(0, 'TelefonoLib_parametri')
    mappa = getappdata(0, 'TelefonoLib_parametri');
else
    mappa = containers.Map('KeyType', 'double', 'ValueType', 'any');
    setappdata(0, 'TelefonoLib_parametri', mappa);
end
id = double(id);
if nargin == 2
    mappa(id) = valori;
    varargout{1} = id;
else
    if ~isKey(mappa, id)
        error('blocchi_telefono:parametri', 'Parametri del blocco non trovati: rieseguite la simulazione.');
    end
    varargout{1} = mappa(id);
end
end
