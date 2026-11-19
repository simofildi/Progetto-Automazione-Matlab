classdef Telefono < handle
%TELEFONO  Collega la fotocamera di un telefono (iPhone o Android) a MATLAB.
%
%   Il telefono apre una pagina web servita da questo PC (nessuna app da
%   installare), invia i fotogrammi via Wi-Fi e mostra il risultato che
%   MATLAB rimanda indietro.
%
%   tel = Telefono();                 % avvia e mostra la finestra con il QR code
%   img = tel.snapshot();                % ultimo fotogramma (RGB uint8), [] se non c'e'
%   [img, info] = tel.snapshot("Nuovo", true, "Timeout", 5);   % aspetta un fotogramma nuovo
%   tel.inviaRisultato(r);               % mostra il risultato sul telefono (vedi sotto)
%   tel.collegato                        % true se il telefono e' attivo
%   tel.mostra();                        % riapre la finestra del QR se l'avete chiusa
%   tel.chiudi();                        % ferma tutto il collegamento
%
%   Chiudere la finestra NON interrompe il collegamento: il telefono continua
%   a inviare e snapshot() continua a funzionare.
%
%   Formato del risultato (tutti i campi sono facoltativi):
%       r.titolo    = "Vedo 3 oggetti";
%       r.colore    = "verde";            % "verde" "rosso" "giallo" "grigio" "blu" o "#RRGGBB"
%       r.dettaglio = "2 mele, 1 pera";
%       r.voci      = struct('nome', {"2 mele","1 pera"}, 'ok', {[],[]});   % ok: true / false / []
%       r.box       = struct('x',0.1,'y',0.2,'w',0.3,'h',0.4, ...   % coordinate 0..1
%                            'etichetta',"mela 82%", 'colore',"giallo");
%
%   Il "ponte" e' un piccolo server Java che gira dentro MATLAB (ponte.jar).

    properties (SetAccess = private)
        Codice   string = ""     % codice di accoppiamento (anche nel QR)
        Indirizzo string = ""    % IP del PC scelto per il QR
        Url      string = ""     % link HTTPS (video continuo)
        UrlFoto  string = ""     % link HTTP (solo foto, nessun certificato)
    end

    properties (Dependent)
        collegato
    end

    properties (Access = private)
        cartella
        portaHttps
        portaHttp
        nomePc
        password = 'matlabcam'
        ultimoNumero = 0
        fig = []
        timerUi = []
        ui = struct()
        tAvvio
        avvisoCertificato = ""
    end

    methods
        function obj = Telefono(opz)
            arguments
                opz.PortaHttps (1,1) double = 8443
                opz.PortaHttp (1,1) double = 8080
                opz.Nome (1,1) string = ""
                opz.Finestra (1,1) logical = true
            end
            obj.cartella = fileparts(mfilename('fullpath'));
            obj.portaHttps = opz.PortaHttps;
            obj.portaHttp = opz.PortaHttp;
            obj.nomePc = opz.Nome;
            if obj.nomePc == ""
                obj.nomePc = "PC di " + string(getenv(ifelse(ispc, 'USERNAME', 'USER')));
            end

            vecchi = timerfindall('Name', 'Telefono-UI');
            if ~isempty(vecchi), stop(vecchi); delete(vecchi); end

            jar = fullfile(obj.cartella, 'ponte.jar');
            if ~any(strcmp(javaclasspath('-dynamic'), jar))
                javaaddpath(jar);
            end
            obj.avviaServer();
            if opz.Finestra
                obj.creaFinestra();
            end
            fprintf('[Telefono] Apri sul telefono: %s   (codice %s)\n', obj.Url, obj.Codice);
        end

        % --------------------------------------------------------------- API
        function [img, info] = snapshot(obj, opz)
        %SNAPSHOT  Ultimo fotogramma ricevuto dal telefono (RGB uint8, [] se assente).
            arguments
                obj
                opz.Nuovo (1,1) logical = false     % aspetta un fotogramma mai letto prima
                opz.Timeout (1,1) double = 3
            end
            t0 = tic;
            while opz.Nuovo && double(obj.J('numeroFrame')) <= obj.ultimoNumero && toc(t0) < opz.Timeout
                pause(0.01);
            end
            img = [];
            n = double(obj.J('numeroFrame'));
            try
                dati = obj.J('ultimoRgb');
                if ~isempty(dati)
                    d = double(obj.J('ultimaDimensione'));
                    img = reshape(typecast(int8(dati), 'uint8'), d(1), d(2), 3);
                end
            catch
                img = [];   % fotogramma non decodificabile o telefono appena scollegato
            end
            nuovo = n > obj.ultimoNumero;
            obj.ultimoNumero = n;
            if nargout > 1
                s = obj.stato();
                info = struct('numero', n, 'nuovo', nuovo, 'eta_ms', s.etaFrameMs, ...
                    'fps', s.fps, 'collegato', s.collegato);
            end
        end

        function inviaRisultato(obj, r)
        %INVIARISULTATO  Mostra un risultato sul telefono (struct o testo JSON).
            if isstring(r) || ischar(r)
                json = char(r);
            else
                if isstruct(r) && isscalar(r) && ~isfield(r, 'fotogramma')
                    r.fotogramma = obj.ultimoNumero;     % a quale foto si riferisce (modalita' Foto)
                end
                json = jsonencode(r);
            end
            obj.J('impostaRisultato', json);
        end

        function s = stato(obj)
        %STATO  Struct con: collegato, telefono, fps, frame, etaFrameMs, codice, https...
            s = jsondecode(char(obj.J('stato')));
        end

        function tf = get.collegato(obj)
            tf = logical(obj.J('telefonoCollegato'));
        end

        function aggiornaRete(obj)
        %AGGIORNARETE  Da usare dopo aver cambiato rete (es. hotspot del telefono).
            obj.avviaServer();
            obj.aggiornaQr();
        end

        function nuovoCodice(obj)
        %NUOVOCODICE  Scollega il telefono attuale e genera un nuovo codice/QR.
            obj.Codice = string(obj.J('nuovoCodice'));
            obj.impostaIndirizzo(obj.Indirizzo);
            obj.aggiornaQr();
        end

        function mostra(obj)
        %MOSTRA  Riapre la finestra con QR code e stato del collegamento.
            if isempty(obj.fig) || ~isvalid(obj.fig)
                obj.creaFinestra();
            else
                figure(obj.fig);
            end
        end

        function chiudi(obj)
            obj.delete();
        end

        function delete(obj)
            try
                if ~isempty(obj.timerUi) && isvalid(obj.timerUi)
                    stop(obj.timerUi); delete(obj.timerUi);
                end
            catch
            end
            try
                if ~isempty(obj.fig) && isvalid(obj.fig), delete(obj.fig); end
            catch
            end
            try
                obj.J('ferma');
            catch
            end
        end
    end

    % =================================================================== interni
    methods (Access = private)
        function varargout = J(~, metodo, varargin)
        % Chiama un metodo statico della classe Java it.scuola.ponte.Ponte.
            if nargout == 0
                javaMethod(metodo, 'it.scuola.ponte.Ponte', varargin{:});
            else
                [varargout{1:nargout}] = javaMethod(metodo, 'it.scuola.ponte.Ponte', varargin{:});
            end
        end

        function ips = indirizzi(obj)
            a = obj.J('indirizzi');
            ips = cell(size(a, 1), 1);
            for k = 1:numel(ips), ips{k} = char(a(k)); end
        end

        function avviaServer(obj)
            ips = obj.indirizzi();
            ks = obj.preparaCertificato(ips);
            web = fullfile(obj.cartella, 'web');
            try
                msg = char(obj.J('avvia', web, ks, obj.password, int32(obj.portaHttps), int32(obj.portaHttp), char(obj.nomePc)));
            catch e
                error('Telefono:porta', ['Impossibile avviare il ponte (porta %d o %d occupata?).\n%s\n' ...
                    'Prova: tel = Telefono("PortaHttps", 9443, "PortaHttp", 9080)'], ...
                    obj.portaHttps, obj.portaHttp, e.message);
            end
            if ~isempty(msg)
                warning('Telefono:https', '%s\nFunziona solo la modalita'' foto (link http).', msg);
            end
            obj.Codice = string(obj.J('codice'));
            if isempty(ips)
                ips = {'127.0.0.1'};
                warning('Telefono:rete', 'Nessuna rete trovata: collega il PC al Wi-Fi o all''hotspot del telefono.');
            end
            obj.impostaIndirizzo(scegliIndirizzo(ips));
            obj.tAvvio = tic;
        end

        function impostaIndirizzo(obj, ip)
            obj.Indirizzo = string(ip);
            obj.Url = string(obj.J('url', char(ip)));
            obj.UrlFoto = string(obj.J('urlFoto', char(ip)));
        end

        function ks = preparaCertificato(obj, ips)
        % Certificato autofirmato con gli IP del PC (richiesto da iPhone).
        % Rigenerato solo se cambiano gli IP o sta per scadere.
            base = fullfile(prefdir, 'matlabcam');
            if ~exist(base, 'dir'), mkdir(base); end
            firma = strjoin(sort(ips), ',');
            fileFirma = fullfile(base, 'ip.txt');
            for est = [".jks", ".p12"]
                ks = char(fullfile(base, "ponte" + est));
                if exist(ks, 'file') && exist(fileFirma, 'file') && strcmp(strtrim(fileread(fileFirma)), firma)
                    info = dir(ks);
                    if now - info.datenum < 300, return; end %#ok<TNOW1>
                end
            end
            obj.avvisoCertificato = "";
            ks = fullfile(base, 'ponte.jks');
            try                                   % 1) keytool della JVM di MATLAB
                obj.J('generaCertificato', ks, obj.password, ips);
            catch e1
                ks = fullfile(base, 'ponte.p12');
                if ~generaConOpenssl(ks, obj.password, ips)   % 2) openssl di sistema
                    ks = fullfile(obj.cartella, 'riserva.jks');  % 3) certificato di riserva
                    obj.avvisoCertificato = "Certificato di riserva: su iPhone usa il link http (modalita' foto).";
                    warning('Telefono:cert', 'Certificato non generato (%s). Uso quello di riserva.', e1.message);
                    return
                end
            end
            fid = fopen(fileFirma, 'w'); fprintf(fid, '%s', firma); fclose(fid);
        end

        % --------------------------------------------------------- finestra
        function creaFinestra(obj)
            obj.fig = uifigure('Name', 'Collega il telefono a MATLAB', 'Position', [100 100 760 470], ...
                'Color', [0.06 0.07 0.09], 'CloseRequestFcn', @(~, ~) obj.chiudiFinestra());
            g = uigridlayout(obj.fig, [1 2], 'ColumnWidth', {330, '1x'}, 'Padding', [18 18 18 18], ...
                'ColumnSpacing', 18, 'BackgroundColor', [0.06 0.07 0.09]);

            sx = uigridlayout(g, [3 1], 'RowHeight', {'1x', 30, 22}, 'Padding', [0 0 0 0], ...
                'BackgroundColor', [0.06 0.07 0.09]);
            obj.ui.qr = uiimage(sx, 'ScaleMethod', 'fit');
            obj.ui.codice = uilabel(sx, 'Text', '', 'FontSize', 26, 'FontWeight', 'bold', ...
                'FontName', 'Menlo', 'HorizontalAlignment', 'center', 'FontColor', [1 0.77 0.19]);
            uilabel(sx, 'Text', 'Inquadra il QR con la fotocamera del telefono', 'FontColor', [0.6 0.65 0.7], ...
                'HorizontalAlignment', 'center');

            dx = uigridlayout(g, [9 2], 'RowHeight', {34, 26, 26, 26, 26, 22, '1x', 32, 52}, ...
                'ColumnWidth', {120, '1x'}, 'Padding', [0 0 0 0], 'RowSpacing', 6, ...
                'BackgroundColor', [0.06 0.07 0.09]);
            obj.ui.lampada = uilamp(dx, 'Color', [0.45 0.45 0.45]);
            obj.ui.lampada.Layout.Row = 1; obj.ui.lampada.Layout.Column = 1;
            obj.ui.titolo = uilabel(dx, 'Text', 'In attesa del telefono…', 'FontSize', 20, ...
                'FontWeight', 'bold', 'FontColor', 'w');
            obj.ui.titolo.Layout.Row = 1; obj.ui.titolo.Layout.Column = 2;

            etich = ["Telefono", "Immagini", "MATLAB", "Rete", "Link"];
            campi = ["telefono", "immagini", "matlab", "rete", "link"];
            for k = 1:numel(etich)
                l = uilabel(dx, 'Text', etich(k), 'FontColor', [0.55 0.6 0.66]);
                l.Layout.Row = k + 1; l.Layout.Column = 1;
                if campi(k) == "rete"
                    obj.ui.rete = uidropdown(dx, 'Items', {'-'}, 'ValueChangedFcn', @(s, ~) obj.cambiaRete(s.Value));
                    obj.ui.rete.Layout.Row = k + 1; obj.ui.rete.Layout.Column = 2;
                else
                    obj.ui.(campi(k)) = uilabel(dx, 'Text', '-', 'FontColor', 'w');
                    obj.ui.(campi(k)).Layout.Row = k + 1; obj.ui.(campi(k)).Layout.Column = 2;
                end
            end
            obj.ui.anteprima = uiimage(dx, 'ScaleMethod', 'fit');
            obj.ui.anteprima.Layout.Row = 7; obj.ui.anteprima.Layout.Column = [1 2];
            obj.ui.consiglio = uilabel(dx, 'Text', '', 'FontColor', [1 0.77 0.19], 'WordWrap', 'on');
            obj.ui.consiglio.Layout.Row = 8; obj.ui.consiglio.Layout.Column = [1 2];

            b = uigridlayout(dx, [1 3], 'Padding', [0 0 0 0], 'BackgroundColor', [0.06 0.07 0.09]);
            b.Layout.Row = 9; b.Layout.Column = [1 2];
            uibutton(b, 'Text', 'Aggiorna rete', 'ButtonPushedFcn', @(~, ~) obj.aggiornaRete());
            uibutton(b, 'Text', 'Nuovo codice', 'ButtonPushedFcn', @(~, ~) obj.nuovoCodice());
            uibutton(b, 'Text', 'Link solo foto', 'ButtonPushedFcn', @(~, ~) obj.mostraLinkFoto());

            obj.aggiornaQr();
            obj.timerUi = timer('ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'BusyMode', 'drop', ...
                'TimerFcn', @(~, ~) obj.aggiornaFinestra(), 'Name', 'Telefono-UI');
            start(obj.timerUi);
        end

        function chiudiFinestra(obj)
        % Chiude solo la finestra: il ponte resta attivo (tel.chiudi() per fermarlo).
            try
                if ~isempty(obj.timerUi) && isvalid(obj.timerUi)
                    stop(obj.timerUi); delete(obj.timerUi);
                end
            catch
            end
            obj.timerUi = [];
            if ~isempty(obj.fig) && isvalid(obj.fig), delete(obj.fig); end
            obj.fig = [];
            fprintf('[Telefono] Finestra chiusa, collegamento ancora attivo. tel.mostra() la riapre, tel.chiudi() ferma tutto.\n');
        end

        function aggiornaQr(obj)
            if isempty(obj.fig) || ~isvalid(obj.fig), return; end
            obj.ui.qr.ImageSource = immagineQr(obj.J('qr', char(obj.Url)));
            obj.ui.codice.Text = char(obj.Codice);
            obj.ui.link.Text = char(obj.Url);
            ips = obj.indirizzi();
            if isempty(ips), ips = {char(obj.Indirizzo)}; end
            obj.ui.rete.Items = ips;
            if any(strcmp(ips, obj.Indirizzo)), obj.ui.rete.Value = char(obj.Indirizzo); end
        end

        function cambiaRete(obj, ip)
            obj.impostaIndirizzo(ip);
            obj.aggiornaQr();
        end

        function mostraLinkFoto(obj)
            uialert(obj.fig, sprintf(['Link senza certificato (solo foto, niente video):\n\n%s\n\n' ...
                'Utile se il telefono rifiuta il certificato HTTPS.'], obj.UrlFoto), ...
                'Modalità foto', 'Icon', 'info');
            obj.ui.qr.ImageSource = immagineQr(obj.J('qr', char(obj.UrlFoto)));
            obj.ui.link.Text = char(obj.UrlFoto);
        end

        function aggiornaFinestra(obj)
            try
                if isempty(obj.fig) || ~isvalid(obj.fig), return; end
                s = obj.stato();
                if s.collegato
                    obj.ui.lampada.Color = [0.12 0.72 0.42];
                    obj.ui.titolo.Text = 'Telefono collegato';
                    obj.ui.telefono.Text = s.telefono;
                    obj.ui.consiglio.Text = '';
                else
                    obj.ui.lampada.Color = [0.45 0.45 0.45];
                    obj.ui.titolo.Text = 'In attesa del telefono…';
                    obj.ui.telefono.Text = '-';
                    if toc(obj.tAvvio) > 40 && s.frame == 0
                        obj.ui.consiglio.Text = ['Il telefono non arriva? La rete potrebbe isolare i dispositivi: ' ...
                            'attiva l''hotspot del telefono, collega il PC e premi "Aggiorna rete".'];
                    end
                end
                if strlength(obj.avvisoCertificato) > 0, obj.ui.consiglio.Text = obj.avvisoCertificato; end
                obj.ui.immagini.Text = sprintf('%d ricevute · %.1f fps', s.frame, s.fps);
                if s.letture > 0
                    obj.ui.matlab.Text = sprintf('il tuo programma ha letto %d immagini', s.letture);
                else
                    obj.ui.matlab.Text = 'il tuo programma non legge ancora (usa snapshot)';
                end
                jpg = obj.J('anteprimaJpeg');
                if ~isempty(jpg) && s.etaFrameMs >= 0 && s.etaFrameMs < 2000
                    f = [tempname '.jpg'];
                    fid = fopen(f, 'w'); fwrite(fid, typecast(int8(jpg), 'uint8')); fclose(fid);
                    obj.ui.anteprima.ImageSource = imread(f);
                    delete(f);
                end
            catch
                % la finestra non deve mai bloccare MATLAB
            end
        end
    end
end

% ======================================================================= funzioni locali
function ip = scegliIndirizzo(ips)
% Preferisce gli indirizzi di reti private tipiche (Wi-Fi di casa, hotspot, universita').
pref = {'^192\.168\.', '^172\.20\.10\.', '^10\.', '^172\.(1[6-9]|2\d|3[01])\.'};
for k = 1:numel(pref)
    i = find(~cellfun(@isempty, regexp(ips, pref{k}, 'once')), 1);
    if ~isempty(i), ip = ips{i}; return; end
end
ip = ips{1};
end

function rgb = immagineQr(m)
m = logical(m(:));
n = round(sqrt(numel(m)));
q = reshape(m, n, n).';                    % Java: riga per riga
q = padarray_semplice(q, 4);               % zona di rispetto bianca
img = uint8(255 * ~kron(q, ones(10)));
rgb = repmat(img, 1, 1, 3);
end

function b = padarray_semplice(a, p)
b = false(size(a) + 2 * p);
b(p + 1:end - p, p + 1:end - p) = a;
end

function ok = generaConOpenssl(p12, password, ips)
ok = false;
if ispc, return; end
[st, ~] = system('which openssl');
if st ~= 0, return; end
san = "DNS:localhost,IP:127.0.0.1";
for k = 1:numel(ips), san = san + ",IP:" + ips{k}; end
d = tempname; mkdir(d);
k = fullfile(d, 'k.pem'); c = fullfile(d, 'c.pem');
cmd1 = sprintf(['openssl req -x509 -newkey rsa:2048 -sha256 -days 397 -nodes -keyout "%s" -out "%s" ' ...
    '-subj "/CN=Ponte MATLAB Cam" -addext "subjectAltName=%s" -addext "extendedKeyUsage=serverAuth" ' ...
    '-addext "basicConstraints=CA:FALSE"'], k, c, san);
cmd2 = sprintf(['openssl pkcs12 -export -inkey "%s" -in "%s" -out "%s" -passout pass:%s -name ponte ' ...
    '-keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1'], k, c, p12, password);
[s1, ~] = system(cmd1);
[s2, ~] = system(cmd2);
ok = s1 == 0 && s2 == 0 && exist(p12, 'file');
end

function v = ifelse(c, a, b)
if c, v = a; else, v = b; end
end
