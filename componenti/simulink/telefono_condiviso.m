function tel = telefono_condiviso()
%TELEFONO_CONDIVISO  Il collegamento al telefono usato dai blocchi Simulink.
%   Usa la variabile "tel" del workspace se esiste, altrimenti la crea
%   (e compare la finestra con il QR code). Non serve modificarla.

tel = [];
try
    tel = evalin('base', 'tel');
catch
end
if isempty(tel) || ~isa(tel, 'Telefono') || ~isvalid(tel)
    tel = Telefono();
    assignin('base', 'tel', tel);
end
end
