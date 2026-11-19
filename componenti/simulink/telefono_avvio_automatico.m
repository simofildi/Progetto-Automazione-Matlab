function telefono_avvio_automatico(blocco)
%TELEFONO_AVVIO_AUTOMATICO  Usata dal blocco "Fotocamera telefono" quando si apre il modello.
%   Avvia subito il collegamento (compare il QR code) e fa partire la simulazione
%   da sola appena il telefono comincia a mandare le foto: non serve premere Run.
%   Si spegne togliendo la spunta "Avvio automatico" nel blocco. Non serve modificarla.
%
%   - parte una volta per collegamento: se fermate la simulazione con Stop, ripartira'
%     solo quando il telefono si scollega e si ricollega (o premendo Run);
%   - si spegne da sola quando il modello viene chiuso.

mdl = bdroot(blocco);
if strcmp(get_param(mdl, 'BlockDiagramType'), 'library'), return; end
if ~strcmp(get_param(blocco, 'AvvioAutomatico'), 'on'), return; end

nome = ['Telefono-Avvio-' mdl];
vecchi = timerfindall('Name', nome);
if ~isempty(vecchi), stop(vecchi); delete(vecchi); end

telefono_condiviso();                                  % server + finestra con il QR code
t = timer('Name', nome, 'ExecutionMode', 'fixedSpacing', 'Period', 0.5, 'BusyMode', 'drop', ...
    'TimerFcn', @(t, ~) controlla(t, mdl));
t.UserData = false;                                    % gia' avviata per questo collegamento?
start(t);
fprintf('[Telefono] %s: la simulazione partira'' da sola quando il telefono inviera'' le foto.\n', mdl);
end

function controlla(t, mdl)
try
    if ~bdIsLoaded(mdl)                                % modello chiuso: il timer si spegne
        stop(t); delete(t); return
    end
    tel = evalin('base', 'tel');
    if ~isa(tel, 'Telefono') || ~isvalid(tel), return; end
    s = tel.stato();
    if ~s.collegato
        t.UserData = false;                            % al prossimo collegamento riparte
        return
    end
    arrivaFoto = s.etaFrameMs >= 0 && s.etaFrameMs < 3000;
    if arrivaFoto && ~t.UserData && strcmp(get_param(mdl, 'SimulationStatus'), 'stopped')
        t.UserData = true;
        fprintf('[Telefono] Il telefono invia le foto: avvio %s.\n', mdl);
        set_param(mdl, 'SimulationCommand', 'start');
    end
catch
    % un errore qui non deve mai bloccare MATLAB
end
end
