%% PROVA_MATLAB  Telefono -> riconoscimento -> telefono, in MATLAB.
% E' il punto di partenza del vostro progetto: copiatelo nella cartella
% il_mio_progetto, dategli un nome vostro e modificatelo li'.
% Per fermare: chiudete la figura.

radice = fileparts(mfilename('fullpath'));
if ~isfile(fullfile(radice, 'INIZIA_QUI.m')), radice = fileparts(radice); end   % copia in il_mio_progetto
addpath(genpath(radice));

if ~exist('tel', 'var') || ~isa(tel, 'Telefono') || ~isvalid(tel)
    tel = Telefono();                        % 1. collegamento: compare il QR code
end
r = Riconoscitore("oggetti");                % 2. riconoscimento: scegliete il modello
r.Soglia = 0.30;
% r.Classi = ["person", "bottle", "cup"];    %    (facoltativo) solo questi oggetti

f = figure('Name', 'Prova MATLAB', 'Color', 'w');
ax = axes(f);
while isvalid(f)
    [img, info] = tel.snapshot('Nuovo', true, 'Timeout', 1);    % 3. prendi la foto
    if isempty(img) || ~info.nuovo, continue; end

    ogg = r.rileva(img);                     % 4. cosa c'e' nella foto?

    % ---------------- QUI LA VOSTRA LOGICA ----------------
    % ogg e' una tabella: ogg.Etichetta, ogg.Punteggio, ogg.Box, ogg.Classe
    ris = r.perTelefono(ogg, img);           % risultato standard: "Vedo 3 oggetti"
    % ------------------------------------------------------

    tel.inviaRisultato(ris);                 % 5. mostralo sul telefono
    if isvalid(f)
        r.mostra(img, ogg, ax);
        title(ax, sprintf('%s · %.1f foto/s', ris.titolo, info.fps));
        drawnow limitrate
    end
end
